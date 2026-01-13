import 'dart:async';
import 'package:flutter/foundation.dart';
import '../account/account.dart';
import '../database/db_isar.dart';
import 'package:isar/isar.dart' hide Filter;
import 'package:bolt11_decoder/bolt11_decoder.dart';
import 'package:decimal/decimal.dart';

import '../utils/log_utils.dart';
import 'model/wallet_transaction.dart';
import 'model/wallet_info.dart';
import 'model/wallet_invoice.dart';
import 'lnbits_api_service.dart';
import '../network/connect.dart';
import '../relayGroups/relayGroup.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:nostr_core_dart/src/nips/nip_047.dart';
import 'package:nostr_core_dart/src/nips/nip_044.dart';
import 'package:nostr_core_dart/src/nips/nip_078.dart';
import 'dart:convert';

/// NIP-47 Wallet Manager
/// Handles Lightning Network payments through Nostr Wallet Connect
class Wallet {
  /// Singleton instance
  Wallet._internal();
  factory Wallet() => sharedInstance;
  static final Wallet sharedInstance = Wallet._internal();

  /// Current wallet balance
  WalletInfo? _walletInfo;
  WalletInfo? get walletInfo => _walletInfo;

  /// LNbits API service
  final LnbitsApiService lnbitsApi = LnbitsApiService();

  /// Pending NIP-47 requests waiting for responses
  final Map<String, Completer<Map<String, dynamic>?>> _pendingRequests = {};

  /// Active polling timers for subscription invoices
  final Map<String, Timer> _pollingTimers = {};

  /// Callback for payment status updates
  Function(String paymentHash, bool isPaid, Map<String, dynamic>? details)? onPaymentStatusChanged;

  /// Transaction history
  List<WalletTransaction> _transactions = [];
  List<WalletTransaction> get transactions => List.unmodifiable(_transactions);

  /// Get all transactions including invoices converted to transactions
  /// - Returns actual transactions from LNbits API
  /// - Also includes pending/paid invoices as transactions (to show pending state)
  /// - Filters out transactions with empty transactionId
  /// - Avoids duplicates when invoice is paid and becomes a real transaction
  Future<List<WalletTransaction>> getAllTransactions() async {
    final all = <WalletTransaction>[];
    
    // Filter out transactions with empty transactionId
    final validTransactions = _transactions.where((tx) => 
      tx.transactionId.isNotEmpty
    ).toList();
    all.addAll(validTransactions);
    
    // Add all invoices as transactions (pending and paid)
    try {
      final invoices = await _loadInvoicesFromDB();
      
      for (final invoice in invoices) {
        // Skip if this invoice already has a corresponding transaction
        // (to avoid duplicates when invoice is paid and becomes a real transaction)
        final hasTransaction = all.any((tx) => 
          tx.transactionId == invoice.invoiceId || 
          tx.paymentHash == invoice.paymentHash
        );
        
        if (hasTransaction) continue;
        
        // Determine transaction status
        TransactionStatus status;
        if (invoice.status == InvoiceStatus.paid) {
          status = TransactionStatus.confirmed;
        } else if (invoice.status == InvoiceStatus.expired) {
          status = TransactionStatus.expired;
        } else if (invoice.expiresAt < (DateTime.now().millisecondsSinceEpoch ~/ 1000)) {
          status = TransactionStatus.expired;
        } else {
          status = TransactionStatus.pending;
        }
        
        final transaction = WalletTransaction(
          transactionId: invoice.invoiceId,
          amount: invoice.amount,
          description: invoice.description,
          status: status,
          type: TransactionType.incoming, // Invoice is for receiving
          createdAt: invoice.createdAt,
          walletId: invoice.walletId,
          invoice: invoice.bolt11,
          paymentHash: invoice.paymentHash,
          confirmedAt: invoice.paidAt,
        );
        all.add(transaction);
      }
    } catch (e) {
      LogUtils.e(() => 'Failed to load invoices: $e');
    }
    
    // Sort by creation time (newest first)
    all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    return all;
  }

  /// Timer for checking pending invoices
  Timer? _invoiceCheckTimer;

  /// BTC to USD exchange rate cache
  double? _btcToUsdRate;
  DateTime? _rateLastUpdated;

  /// Pending transactions
  final List<WalletTransaction> _pendingTransactions = [];
  List<WalletTransaction> get pendingTransactions => List.unmodifiable(_pendingTransactions);

  /// Wallet connection status
  bool get isConnected => _walletInfo != null;

  /// Check if wallet connection is in progress
  bool get isConnecting => _connectionCompleter != null;

  /// Callbacks
  VoidCallback? onBalanceChanged;
  VoidCallback? onTransactionAdded;

  Completer<bool>? _connectionCompleter;

  /// Initialize wallet
  Future<void> init() async {
    await connectToWallet();
  }

  /// Create new wallet
  Future<WalletInfo> createNewWallet(String pubkey, String privkey) async {
    try {
      LogUtils.d(() => 'Creating new wallet for pubkey: ${pubkey.substring(0, 8)}...');
      
      // Create wallet with random name
      final accountResponse = await lnbitsApi.createWallet();
      final walletId = accountResponse['id'] as String;
      final adminKey = accountResponse['admin'] as String;
      final invoiceKey = accountResponse['invoice'] as String;
      final readKey = accountResponse['read'] as String;
      final walletName = accountResponse['name'] as String;
      
      // Create wallet info object
      final walletInfoObj = WalletInfo(
        walletId: walletId,
        pubkey: pubkey,
        lnbitsUrl: lnbitsApi.baseUrl,
        adminKey: adminKey,
        invoiceKey: invoiceKey,
        readKey: readKey,
        lnbitsUserId: walletId, // For LNbits, the wallet ID serves as user ID
        lnbitsUsername: walletName,
        totalBalance: 0, // New wallet starts with 0 balance
        confirmedBalance: 0,
        unconfirmedBalance: 0,
        reservedBalance: 0,
        lastUpdated: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      
      // Save to database
      await _saveWalletInfoToDB(walletInfoObj);
      
      LogUtils.i(() => 'Successfully created wallet: $walletId');
      return walletInfoObj;
    } catch (e) {
      LogUtils.e(() => 'Failed to create new wallet: $e');
      rethrow;
    }
  }

  /// Connect to LNbits wallet using current pubkey
  Future<bool> connectToWallet() async {
    if (_walletInfo != null) {
      LogUtils.d(() => 'Wallet already connected: ${_walletInfo?.walletId ?? "unknown"}');
      return true;
    }

    if (_connectionCompleter != null) {
      LogUtils.d(() => 'Wallet connection already in progress, waiting...');
      return await _connectionCompleter!.future;
    }

    // Create new completer for this connection attempt
    _connectionCompleter = Completer<bool>();

    try {
      LogUtils.d(() => 'Starting wallet connection process');
      // Get current pubkey and privkey from account
      final pubkey = Account.sharedInstance.currentPubkey;
      final privkey = Account.sharedInstance.currentPrivkey;
      LogUtils.d(() => 'Current pubkey: $pubkey, privkey length: ${privkey.length}');
      if (pubkey.isEmpty || privkey.isEmpty) {
        LogUtils.e(() => 'No current pubkey or privkey available');
        _connectionCompleter!.complete(false);
        _connectionCompleter = null;
        return false;
      }
      
      // Load wallet info from database
      LogUtils.d(() => 'Loading wallet info from database');
      WalletInfo? walletInfo = await _loadWalletInfo();
      if (walletInfo == null) {
        LogUtils.d(() => 'No existing wallet found, trying to load from relay');
        // Try to load wallet info from relay first
        walletInfo = await _loadWalletInfoFromRelay(pubkey, privkey);
        if (walletInfo == null) {
          LogUtils.d(() => 'No wallet found on relay, creating new wallet');
          walletInfo = await createNewWallet(pubkey, privkey);
          // Save wallet info to relay after creating
          await _saveWalletInfoToRelay(walletInfo, pubkey, privkey);
        } else {
          LogUtils.d(() => 'Found wallet on relay: ${walletInfo?.walletId ?? "unknown"}');
          // Save to local database for future use
          await _saveWalletInfoToDB(walletInfo);
        }
      } else {
        LogUtils.d(() => 'Found existing wallet: ${walletInfo?.walletId ?? "unknown"}');
      }

      // Set wallet info
      _walletInfo = walletInfo;

      // Get initial balance
      await refreshBalance();
      // Get recent transactions
      await refreshTransactions();
      
      // Start invoice checking timer
      _startInvoiceCheckTimer();
      
      LogUtils.i(() => 'Successfully connected to wallet: ${walletInfo?.walletId ?? "unknown"}');
      
      final result = true;
      _connectionCompleter!.complete(result);
      _connectionCompleter = null;
      return result;
    } catch (e) {
      LogUtils.e(() => 'Failed to connect to wallet: $e');
      final result = false;
      if (!_connectionCompleter!.isCompleted) {
        _connectionCompleter!.complete(result);
      }
      _connectionCompleter = null;
      return result;
    }
  }

  /// Disconnect from wallet
  void disconnect() {
    // Stop invoice checking timer
    _stopInvoiceCheckTimer();
    
    _walletInfo = null;
    // Clear any pending connection completer
    _connectionCompleter = null;
  }

  /// Logout and clear all wallet data
  void logout() {
    LogUtils.d(() => 'Starting wallet logout process...');
    
    // Use dispose method to clean up resources (timers, callbacks, pending requests)
    dispose();
    
    // Clear wallet info
    _walletInfo = null;
    
    // Clear transaction data
    _transactions.clear();
    _pendingTransactions.clear();
    
    // Clear cached exchange rate
    _btcToUsdRate = null;
    _rateLastUpdated = null;
    
    // Clear payment status callback (not handled by dispose)
    onPaymentStatusChanged = null;
    
    // Clear connection completer
    _connectionCompleter = null;
    
    LogUtils.i(() => 'Wallet logout completed successfully');
  }

  /// Refresh wallet balance
  Future<void> refreshBalance() async {
    if (_walletInfo == null) return;
    
    try {
      final balance = await _getBalance();
      if (balance != null && _walletInfo != null) {
        _walletInfo!.updateBalance(totalBalance: balance);
        await _saveWalletInfoToDB(_walletInfo!);
        onBalanceChanged?.call();
      }
    } catch (e) {
      LogUtils.e(() => 'Failed to refresh balance: $e');
    }
  }

  /// Send payment
  Future<WalletTransaction?> sendPayment(String invoice, {String? description}) async {
    if (_walletInfo == null || _walletInfo!.adminKey.isEmpty) return null;
    
    try {
      final lnbitsApi = LnbitsApiService(lnbitsUrl: _walletInfo!.lnbitsUrl);
      final response = await lnbitsApi.payInvoice(
        adminKey: _walletInfo!.adminKey,
        bolt11: invoice,
      );
      
      // LNbits returns amount in msats as negative value for outgoing payments
      final amountMsats = response['amount'] as int;
      final amountSats = (amountMsats.abs() ~/ 1000); // Convert msats to sats and make positive
      
      final transaction = WalletTransaction(
        transactionId: response['payment_hash'] as String,
        type: TransactionType.outgoing,
        status: TransactionStatus.confirmed,
        amount: amountSats, // Use positive amount in sats
        fee: response['fee'] as int? ?? 0,
        description: description ?? '',
        invoice: invoice,
        paymentHash: response['payment_hash'] as String,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        walletId: _walletInfo!.walletId,
        preimage: response['preimage'] as String?,
      );
      
      _addTransaction(transaction);
      await refreshBalance();
      return transaction;
    } catch (e) {
      LogUtils.e(() => 'Failed to send payment: $e');
      return null;
    }
  }

  /// Create invoice for receiving payment
  Future<WalletInvoice?> createInvoice(int amountSats, {String? description}) async {
    if (_walletInfo == null || _walletInfo!.invoiceKey.isEmpty) return null;
    
    try {
      LogUtils.d(() => 'Creating invoice for ${amountSats} sats${description != null ? ' with description: $description' : ''}');
      
      final lnbitsApi = LnbitsApiService(lnbitsUrl: _walletInfo!.lnbitsUrl);
      final response = await lnbitsApi.createInvoice(
        apiKey: _walletInfo!.invoiceKey,
        amount: amountSats,
        memo: description,
      );
      
      final invoice = WalletInvoice(
        invoiceId: response['payment_hash'] as String,
        bolt11: response['bolt11'] as String,
        paymentHash: response['payment_hash'] as String,
        amount: (response['amount'] as int) ~/ 1000, // Convert msats to sats
        description: description ?? '', // Use original description, not API response
        status: InvoiceStatus.pending,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        expiresAt: DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
        walletId: _walletInfo!.walletId,
      );

      LogUtils.d(() => 'Created invoice: ${invoice.toJson()}');
      
      // Save invoice to database
      await _saveInvoiceToDB(invoice);
      
      // Don't refresh transactions here - invoice is pending, not paid yet
      // Transactions will be created automatically when invoice is paid
      // Only refresh invoice statuses to check for any pending payments
      await checkPendingInvoices();
      
      LogUtils.i(() => 'Successfully created invoice: ${invoice.invoiceId}');
      return invoice;
    } catch (e) {
      LogUtils.e(() => 'Failed to create invoice: $e');
      // Re-throw the exception so the caller can handle it
      rethrow;
    }
  }

  /// Refresh transaction history with smart sync strategy
  /// Step 1: Load and display local transactions immediately
  /// Step 2: Fetch from remote API in background
  /// Step 3: Update local transactions if transactionId matches
  Future<void> refreshTransactions() async {
    if (_walletInfo == null || _walletInfo!.invoiceKey.isEmpty) return;
    
    try {
      // Step 1: Load existing transactions from database first and display immediately
      final existingTransactions = await _loadTransactionsFromDB();
      if (existingTransactions.isNotEmpty) {
        _transactions = existingTransactions;
        LogUtils.d(() => 'Loaded ${existingTransactions.length} existing transactions from DB');
        onTransactionAdded?.call(); // Trigger UI update to show local data immediately
      }
      
      // Step 2: Fetch latest transactions from API in background
      final lnbitsApi = LnbitsApiService(lnbitsUrl: _walletInfo!.lnbitsUrl);
      final payments = await lnbitsApi.getPayments(
        apiKey: _walletInfo!.invoiceKey,
        limit: 10,
      );
      
      final apiTransactions = payments.map((payment) => WalletTransaction.fromJson(payment))
          .where((tx) => tx.transactionId.isNotEmpty) // Filter out empty transactionId
          .toList();
      
      // Step 3: Merge transactions - update local if transactionId matches
      final mergedTransactions = _mergeTransactions(existingTransactions, apiTransactions);
      
      // Update local list with merged data
      _transactions = mergedTransactions;
      
      // Step 4: Save/update transactions in database (only save valid transactions from API)
      await _saveTransactionsToDB(apiTransactions);
      
      LogUtils.d(() => 'Refreshed transactions: ${apiTransactions.length} from API, ${mergedTransactions.length} total');
      onTransactionAdded?.call(); // Trigger UI update with merged data
    } catch (e) {
      LogUtils.e(() => 'Failed to refresh transactions: $e');
      // If API fails, still use local data (already loaded in Step 1)
      if (_transactions.isEmpty) {
        final existingTransactions = await _loadTransactionsFromDB();
        if (existingTransactions.isNotEmpty) {
          _transactions = existingTransactions;
          onTransactionAdded?.call();
        }
      }
    }
  }

  /// Merge existing transactions with new ones from API
  List<WalletTransaction> _mergeTransactions(
    List<WalletTransaction> existing,
    List<WalletTransaction> newTransactions,
  ) {
    final Map<String, WalletTransaction> transactionMap = {};
    
    // Add existing transactions
    for (final transaction in existing) {
      transactionMap[transaction.transactionId] = transaction;
    }
    
    // Add/update with new transactions (API data takes precedence)
    for (final transaction in newTransactions) {
      transactionMap[transaction.transactionId] = transaction;
    }
    
    // Sort by creation time (newest first)
    final merged = transactionMap.values.toList();
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    return merged;
  }

  /// Add transaction to local list
  void _addTransaction(WalletTransaction transaction) {
    _transactions.insert(0, transaction);
    if (transaction.status == TransactionStatus.pending) {
      _pendingTransactions.add(transaction);
    }
    
    // Save to database
    _saveTransactionToDB(transaction);
    
    onTransactionAdded?.call();
  }

  /// Save transaction to database
  Future<void> _saveTransactionToDB(WalletTransaction transaction) async {
    try {
      await DBISAR.sharedInstance.saveToDB(transaction);
      LogUtils.d(() => 'Transaction saved to database: ${transaction.transactionId}');
    } catch (e) {
      LogUtils.e(() => 'Failed to save transaction to DB: $e');
    }
  }


  /// Get wallet balance from LNbits API
  Future<int?> _getBalance() async {
    if (_walletInfo == null || _walletInfo!.invoiceKey.isEmpty) {
      return null;
    }
    
    try {
      final lnbitsApi = LnbitsApiService(lnbitsUrl: _walletInfo!.lnbitsUrl);
      final walletInfo = await lnbitsApi.getWalletInfo(apiKey: _walletInfo!.invoiceKey);
      
      // LNbits returns balance in msats, convert to sats
      final balanceMsats = walletInfo['balance'] as int?;
      if (balanceMsats != null) {
        final balanceSats = balanceMsats ~/ 1000; // Convert msats to sats
        LogUtils.d(() => 'Balance: ${balanceMsats} msats = ${balanceSats} sats');
        return balanceSats;
      }
      return null;
    } catch (e) {
      LogUtils.e(() => 'Failed to get balance: $e');
      return null;
    }
  }
  /// Save transactions to database
  Future<void> _saveTransactionsToDB(List<WalletTransaction> transactions) async {
    try {
      // Save transactions to local database
      for (final transaction in transactions) {
        await DBISAR.sharedInstance.saveToDB(transaction);
      }
      LogUtils.d(() => 'Saved ${transactions.length} transactions to database');
    } catch (e) {
      LogUtils.e(() => 'Failed to save transactions to DB: $e');
    }
  }

  /// Load transactions from database
  Future<List<WalletTransaction>> _loadTransactionsFromDB() async {
    try {
      List<WalletTransaction> transactions;
      if (kIsWeb) {
        // Web platform uses dedicated methods
        transactions = await DBISAR.sharedInstance.findAllWalletTransactions();
      } else {
        // Mobile platform uses Isar
        final isar = DBISAR.sharedInstance.isar;
        transactions = await isar.walletTransactions.where().findAll();
      }
      LogUtils.d(() => 'Loaded ${transactions.length} transactions from database');
      return transactions;
    } catch (e) {
      LogUtils.e(() => 'Failed to load transactions from DB: $e');
      return [];
    }
  }

  /// Load wallet info from database
  Future<WalletInfo?> _loadWalletInfo() async {
    try {
      // Load wallet info from local database
      List<WalletInfo> walletInfos;
      if (kIsWeb) {
        walletInfos = await DBISAR.sharedInstance.findAllWalletInfos();
      } else {
        final isar = DBISAR.sharedInstance.isar;
        walletInfos = await isar.walletInfos.where().findAll();
      }
      
      if (walletInfos.isNotEmpty) {
        final walletInfo = walletInfos.first;
        LogUtils.d(() => 'Found existing wallet in database: ${walletInfo.walletId}');
        return walletInfo;
      }
      
      LogUtils.d(() => 'No wallet found in database');
      return null;
    } catch (e) {
      LogUtils.e(() => 'Failed to load wallet info: $e');
      return null;
    }
  }



  /// Save wallet info to database
  Future<void> _saveWalletInfoToDB(WalletInfo walletInfo) async {
    try {
      // Save wallet info to local database
      await DBISAR.sharedInstance.saveToDB(walletInfo);
      LogUtils.i(() => 'Wallet info saved to database: ${walletInfo.walletId}');
    } catch (e) {
      LogUtils.e(() => 'Failed to save wallet info to DB: $e');
      rethrow;
    }
  }

  /// Save invoice to database
  Future<void> _saveInvoiceToDB(WalletInvoice invoice) async {
    try {
      // Save invoice to local database
      await DBISAR.sharedInstance.saveToDB(invoice);
      LogUtils.d(() => 'Invoice saved to database: ${invoice.invoiceId}');
    } catch (e) {
      LogUtils.e(() => 'Failed to save invoice to DB: $e');
      rethrow;
    }
  }

  /// Load invoices from database
  Future<List<WalletInvoice>> _loadInvoicesFromDB() async {
    try {
      List<WalletInvoice> invoices;
      if (kIsWeb) {
        invoices = await DBISAR.sharedInstance.findAllWalletInvoices();
      } else {
        final isar = DBISAR.sharedInstance.isar;
        invoices = await isar.walletInvoices.where().findAll();
      }
      LogUtils.d(() => 'Loaded ${invoices.length} invoices from database');
      return invoices;
    } catch (e) {
      LogUtils.e(() => 'Failed to load invoices from DB: $e');
      return [];
    }
  }

  /// Get all invoices
  Future<List<WalletInvoice>> getInvoices() async {
    return await _loadInvoicesFromDB();
  }

  /// Update invoice status
  Future<void> updateInvoiceStatus(String invoiceId, InvoiceStatus status) async {
    try {
      WalletInvoice? invoice;
      if (kIsWeb) {
        invoice = await DBISAR.sharedInstance.findWalletInvoiceByInvoiceId(invoiceId);
      } else {
        final isar = DBISAR.sharedInstance.isar;
        invoice = await isar.walletInvoices.where().invoiceIdEqualTo(invoiceId).findFirst();
      }
      if (invoice != null) {
        invoice.status = status;
        await DBISAR.sharedInstance.saveToDB(invoice);
        LogUtils.d(() => 'Updated invoice status: $invoiceId -> $status');
        
        // Trigger UI update when invoice status changes
        onTransactionAdded?.call();
      }
    } catch (e) {
      LogUtils.e(() => 'Failed to update invoice status: $e');
    }
  }

  /// Check pending invoices for payment status
  Future<void> checkPendingInvoices() async {
    LogUtils.d(() => 'checkPendingInvoices called at ${DateTime.now()}');
    if (_walletInfo == null || _walletInfo!.invoiceKey.isEmpty) {
      LogUtils.d(() => 'Skipping checkPendingInvoices: walletInfo is null or invoiceKey is empty');
      return;
    }
    
    try {
      LogUtils.d(() => 'Checking pending invoices for payment status...');
      
      // First refresh balance to get latest value
      await refreshBalance();
      
      // Get all pending invoices from database
      List<WalletInvoice> allInvoices;
      if (kIsWeb) {
        allInvoices = await DBISAR.sharedInstance.findAllWalletInvoices();
      } else {
        final isar = DBISAR.sharedInstance.isar;
        allInvoices = await isar.walletInvoices.where().findAll();
      }
      final pendingInvoices = allInvoices.where((invoice) => invoice.status == InvoiceStatus.pending).toList();
      
      if (pendingInvoices.isEmpty) {
        LogUtils.d(() => 'No pending invoices to check');
        return;
      }
      
      LogUtils.d(() => 'Found ${pendingInvoices.length} pending invoices to check');
      
      final lnbitsApi = LnbitsApiService(lnbitsUrl: _walletInfo!.lnbitsUrl);
      int updatedCount = 0;
      
      // Check each pending invoice
      for (final invoice in pendingInvoices) {
        try {
          // Check if invoice is expired
          final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          if (invoice.expiresAt < now) {
            await updateInvoiceStatus(invoice.invoiceId, InvoiceStatus.expired);
            LogUtils.d(() => 'Invoice expired: ${invoice.invoiceId}');
            updatedCount++;
            continue;
          }
          
          // Check payment status via API
          try {
            final paymentInfo = await lnbitsApi.getPayment(
              apiKey: _walletInfo!.invoiceKey,
              paymentHash: invoice.paymentHash,
            );
            
            if (paymentInfo['paid'] == true) {
              await updateInvoiceStatus(invoice.invoiceId, InvoiceStatus.paid);
              LogUtils.d(() => 'Invoice paid: ${invoice.invoiceId}');
              updatedCount++;
              
              // Refresh balance after successful payment
              await refreshBalance();
              
              // Refresh transactions to show the new paid transaction
              await refreshTransactions();
            }
          } catch (e) {
            LogUtils.d(() => 'getPayment failed for ${invoice.invoiceId}, checking balance change: $e');
          }
        } catch (e) {
          LogUtils.e(() => 'Error checking invoice ${invoice.invoiceId}: $e');
        }
      }
      
      LogUtils.i(() => 'Invoice status check completed. Updated $updatedCount invoices.');
    } catch (e) {
      LogUtils.e(() => 'Failed to check pending invoices: $e');
    }
  }

  /// Get pending invoices
  Future<List<WalletInvoice>> getPendingInvoices() async {
    try {
      List<WalletInvoice> allInvoices;
      if (kIsWeb) {
        allInvoices = await DBISAR.sharedInstance.findAllWalletInvoices();
      } else {
        final isar = DBISAR.sharedInstance.isar;
        allInvoices = await isar.walletInvoices.where().findAll();
      }
      final pendingInvoices = allInvoices.where((invoice) => invoice.status == InvoiceStatus.pending).toList();
      // Sort by creation time (newest first)
      pendingInvoices.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return pendingInvoices;
    } catch (e) {
      LogUtils.e(() => 'Failed to get pending invoices: $e');
      return [];
    }
  }

  /// Manually refresh invoice statuses (for UI refresh button)
  Future<void> refreshInvoiceStatuses() async {
    LogUtils.d(() => 'Manual invoice status refresh requested');
    await checkPendingInvoices();
  }



  /// Lookup invoice by payment hash or bolt11
  Future<WalletInvoice?> lookupInvoice(String invoice) async {
    if (_walletInfo == null || _walletInfo!.invoiceKey.isEmpty) return null;
    
    try {
      final lnbitsApi = LnbitsApiService(lnbitsUrl: _walletInfo!.lnbitsUrl);
      
      // Try to get payment info from LNbits API
      final response = await lnbitsApi.getPayment(
        apiKey: _walletInfo!.invoiceKey,
        paymentHash: invoice,
      );
      
      if (response.isNotEmpty) {
        // Update local invoice status if found
        await updateInvoiceStatus(invoice, InvoiceStatus.paid);
        LogUtils.d(() => 'Invoice found and marked as paid: $invoice');
      }
      
      return null; // For now, return null as we need to implement proper mapping
    } catch (e) {
      LogUtils.e(() => 'Failed to lookup invoice: $e');
      return null;
    }
  }

  /// Create subscription invoice using NIP-47
  Future<Map<String, dynamic>?> makeSubscriptionInvoice({
    required String groupId,
    required int month,
    required String relayPubkey,
  }) async {
    if (_walletInfo == null) {
      LogUtils.e(() => 'Wallet not connected');
      return null;
    }

    try {
      LogUtils.d(() => 'Creating subscription invoice for group: $groupId, month: $month');
      
      // Get current account's private key
      final privkey = Account.sharedInstance.currentPrivkey;
      if (privkey.isEmpty) {
        LogUtils.e(() => 'No private key available');
        return null;
      }

      // Create NIP-47 request event
      final event = await Nip47.makeSubscriptionInvoice(
        groupId,
        month,
        relayPubkey,
        privkey,
      );

      LogUtils.d(() => 'Created NIP-47 subscription invoice event: ${event.id}');
      
      // Create completer for this request
      final completer = Completer<Map<String, dynamic>?>();
      _pendingRequests[event.id] = completer;
      
      // Send event to group relay
      final sendSuccess = await _sendEventToGroupRelay(event, groupId);
      if (!sendSuccess) {
        LogUtils.e(() => 'Failed to send subscription invoice event to group relay');
        _pendingRequests.remove(event.id);
        if (!completer.isCompleted) {
          completer.complete({
            'error': true,
            'message': 'Failed to send event to relay',
          });
        }
        return completer.future;
      }
      
      // Set timeout for response (30 seconds)
      Timer(const Duration(seconds: 30), () {
        if (_pendingRequests.containsKey(event.id)) {
          _pendingRequests.remove(event.id);
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        }
      });
      
      // Wait for response
      final response = await completer.future;
      
      // If successful, start polling for payment status
      if (response != null && 
          !response.containsKey('error') && 
          response.containsKey('payment_hash')) {
        final paymentHash = response['payment_hash'] as String;
        _startPollingPaymentStatus(paymentHash, relayPubkey);
      }
      
      return response;
      
    } catch (e) {
      LogUtils.e(() => 'Failed to create subscription invoice: $e');
      return null;
    }
  }

  /// Lookup subscription invoice using NIP-47
  Future<Map<String, dynamic>?> lookupSubscriptionInvoice({
    required String paymentHash,
    required String relayPubkey,
  }) async {
    if (_walletInfo == null) {
      LogUtils.e(() => 'Wallet not connected');
      return null;
    }

    try {
      LogUtils.d(() => 'Looking up subscription invoice: $paymentHash');
      
      // Get current account's private key
      final privkey = Account.sharedInstance.currentPrivkey;
      if (privkey.isEmpty) {
        LogUtils.e(() => 'No private key available');
        return null;
      }

      // Create NIP-47 request event
      final event = await Nip47.lookupSubscriptionInvoice(
        paymentHash,
        relayPubkey,
        privkey,
      );

      LogUtils.d(() => 'Created NIP-47 lookup subscription invoice event: ${event.id}');
      
      // Create completer for this request
      final completer = Completer<Map<String, dynamic>?>();
      _pendingRequests[event.id] = completer;
      
      // Send event to group relay
      final sendSuccess = await _sendEventToGroupRelay(event, '');
      if (!sendSuccess) {
        LogUtils.e(() => 'Failed to send lookup subscription invoice event to group relay');
        _pendingRequests.remove(event.id);
        if (!completer.isCompleted) {
          completer.complete({
            'error': true,
            'message': 'Failed to send event to relay',
          });
        }
        return completer.future;
      }
      
      // Set timeout for response (30 seconds)
      Timer(const Duration(seconds: 30), () {
        if (_pendingRequests.containsKey(event.id)) {
          _pendingRequests.remove(event.id);
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        }
      });
      
      // Wait for response
      final response = await completer.future;
      return response;
      
    } catch (e) {
      LogUtils.e(() => 'Failed to create lookup subscription invoice: $e');
      return null;
    }
  }

  /// Save invoice to database
  Future<void> saveInvoiceToDB(WalletInvoice invoice) async {
    try {
      // Save invoice to local database
    } catch (e) {
      LogUtils.e(() => 'Error saving invoice to DB: $e');
    }
  }

  /// Load invoices from database
  Future<List<WalletInvoice>> loadInvoicesFromDB() async {
    try {
      // Load invoices from local database
      return [];
    } catch (e) {
      LogUtils.e(() => 'Error loading invoices from DB: $e');
      return [];
    }
  }

  /// Update transaction in database
  Future<void> updateTransactionInDB(WalletTransaction transaction) async {
    try {
      // Update transaction in local database
    } catch (e) {
      LogUtils.e(() => 'Error updating transaction in DB: $e');
    }
  }

  /// Delete transaction from database
  Future<void> deleteTransactionFromDB(String transactionId) async {
    try {
      // Delete transaction from local database
    } catch (e) {
      LogUtils.e(() => 'Error deleting transaction from DB: $e');
    }
  }

  /// Clear all wallet data from database
  Future<void> clearWalletDataFromDB() async {
    try {
      LogUtils.d(() => 'Clearing all wallet data from database...');
      
      final isar = DBISAR.sharedInstance.isar;
      
      // Clear wallet info
      await isar.write((isar) async {
        isar.walletInfos.clear();
        LogUtils.d(() => 'Cleared wallet info from database');
      });
      
      // Clear transactions
      await isar.write((isar) async {
        isar.walletTransactions.clear();
        LogUtils.d(() => 'Cleared transactions from database');
      });
      
      // Clear invoices
      await isar.write((isar) async {
        isar.walletInvoices.clear();
        LogUtils.d(() => 'Cleared invoices from database');
      });
      
      LogUtils.i(() => 'All wallet data cleared from database successfully');
    } catch (e) {
      LogUtils.e(() => 'Error clearing wallet data from DB: $e');
      rethrow;
    }
  }

  /// Get transaction by ID
  Future<WalletTransaction?> getTransactionById(String transactionId) async {
    try {
      final isar = DBISAR.sharedInstance.isar;
      final transaction = await isar.walletTransactions.where().transactionIdEqualTo(transactionId).findFirst();
      return transaction;
    } catch (e) {
      LogUtils.e(() => 'Error getting transaction by ID: $e');
      return null;
    }
  }

  /// Get invoice by ID
  Future<WalletInvoice?> getInvoiceById(String invoiceId) async {
    try {
      final isar = DBISAR.sharedInstance.isar;
      final invoice = await isar.walletInvoices.where().invoiceIdEqualTo(invoiceId).findFirst();
      return invoice;
    } catch (e) {
      LogUtils.e(() => 'Error getting invoice by ID: $e');
      return null;
    }
  }

  /// Get transactions by date range
  Future<List<WalletTransaction>> getTransactionsByDateRange(
    int startTime,
    int endTime,
  ) async {
    try {
      final isar = DBISAR.sharedInstance.isar;
      final allTransactions = await isar.walletTransactions.where().findAll();
      final filteredTransactions = allTransactions.where((transaction) {
        return transaction.createdAt >= startTime && transaction.createdAt <= endTime;
      }).toList();
      
      // Sort by creation time (newest first)
      filteredTransactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return filteredTransactions;
    } catch (e) {
      LogUtils.e(() => 'Error getting transactions by date range: $e');
      return [];
    }
  }

  /// Get pending transactions
  Future<List<WalletTransaction>> getPendingTransactions() async {
    try {
      return await getTransactionsByStatus(TransactionStatus.pending);
    } catch (e) {
      LogUtils.e(() => 'Error getting pending transactions: $e');
      return [];
    }
  }

  /// Get transactions by type
  Future<List<WalletTransaction>> getTransactionsByType(TransactionType type) async {
    try {
      final isar = DBISAR.sharedInstance.isar;
      final allTransactions = await isar.walletTransactions.where().findAll();
      final filteredTransactions = allTransactions.where((transaction) {
        return transaction.type == type;
      }).toList();
      
      // Sort by creation time (newest first)
      filteredTransactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return filteredTransactions;
    } catch (e) {
      LogUtils.e(() => 'Error getting transactions by type: $e');
      return [];
    }
  }

  /// Get transactions by status
  Future<List<WalletTransaction>> getTransactionsByStatus(TransactionStatus status) async {
    try {
      List<WalletTransaction> allTransactions;
      if (kIsWeb) {
        allTransactions = await DBISAR.sharedInstance.findAllWalletTransactions();
      } else {
        final isar = DBISAR.sharedInstance.isar;
        allTransactions = await isar.walletTransactions.where().findAll();
      }
      final filteredTransactions = allTransactions.where((transaction) {
        return transaction.status == status;
      }).toList();
      
      // Sort by creation time (newest first)
      filteredTransactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return filteredTransactions;
    } catch (e) {
      LogUtils.e(() => 'Error getting transactions by status: $e');
      return [];
    }
  }

  /// Get transactions by amount range
  Future<List<WalletTransaction>> getTransactionsByAmountRange(
    int minAmount,
    int maxAmount,
  ) async {
    try {
      List<WalletTransaction> allTransactions;
      if (kIsWeb) {
        allTransactions = await DBISAR.sharedInstance.findAllWalletTransactions();
      } else {
        final isar = DBISAR.sharedInstance.isar;
        allTransactions = await isar.walletTransactions.where().findAll();
      }
      final filteredTransactions = allTransactions.where((transaction) {
        return transaction.amount >= minAmount && transaction.amount <= maxAmount;
      }).toList();
      
      // Sort by creation time (newest first)
      filteredTransactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return filteredTransactions;
    } catch (e) {
      LogUtils.e(() => 'Error getting transactions by amount range: $e');
      return [];
    }
  }

  /// Start invoice checking timer
  void _startInvoiceCheckTimer() {
    _stopInvoiceCheckTimer(); // Stop any existing timer
    
    LogUtils.d(() => 'Starting invoice checking timer...');
    
    // Check every 30 seconds for pending invoices
    _invoiceCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      LogUtils.d(() => 'Timer tick: calling checkPendingInvoices');
      checkPendingInvoices();
    });
    
    LogUtils.d(() => 'Started invoice checking timer (30s interval)');
  }

  /// Stop invoice checking timer
  void _stopInvoiceCheckTimer() {
    _invoiceCheckTimer?.cancel();
    _invoiceCheckTimer = null;
    LogUtils.d(() => 'Stopped invoice checking timer');
  }

  /// Get BTC to USD exchange rate (with caching)
  Future<double> getBtcToUsdRate() async {
    // Check if we have a cached rate that's less than 5 minutes old
    if (_btcToUsdRate != null && 
        _rateLastUpdated != null && 
        DateTime.now().difference(_rateLastUpdated!).inMinutes < 5) {
      return _btcToUsdRate!;
    }

    try {
      final rate = await lnbitsApi.getBtcToUsdRate();
      _btcToUsdRate = rate;
      _rateLastUpdated = DateTime.now();
      return rate;
    } catch (e) {
      LogUtils.e(() => 'Failed to get BTC rate: $e');
      // Return cached rate if available, otherwise fallback
      return _btcToUsdRate ?? 50000.0;
    }
  }

  /// Convert sats to USD
  Future<double> satsToUsd(int sats) async {
    final btcRate = await getBtcToUsdRate();
    final btcAmount = sats / 100000000.0; // Convert sats to BTC
    return btcAmount * btcRate;
  }

  /// Parse BOLT11 invoice to extract amount and description
  Future<Map<String, dynamic>?> parseInvoice(String bolt11) async {
    try {
      LogUtils.d(() => 'Parsing invoice: ${bolt11.substring(0, 20)}...');
      
      // Use local BOLT11 decoder instead of API call
      final decoded = _decodeBolt11Invoice(bolt11);
      
      if (decoded != null) {
        LogUtils.d(() => 'Invoice parsed successfully: amount=${decoded['amount']}, description=${decoded['description']}');
        return decoded;
      } else {
        LogUtils.e(() => 'Failed to parse invoice');
        return null;
      }
    } catch (e) {
      LogUtils.e(() => 'Error parsing invoice: $e');
      return null;
    }
  }

  /// Decode BOLT11 invoice locally using bolt11_decoder
  Map<String, dynamic>? _decodeBolt11Invoice(String invoice) {
    try {
      final Bolt11PaymentRequest req = Bolt11PaymentRequest(invoice);
      
      // Extract information from tagged fields
      String description = '';
      String paymentHash = '';
      int expiry = 0;
      
      for (final tag in req.tags) {
        switch (tag.type) {
          case 'description':
            description = tag.data as String;
            break;
          case 'payment_hash':
            paymentHash = tag.data as String;
            break;
          case 'expiry':
            expiry = tag.data as int;
            break;
        }
      }
      
      // Convert amount from BTC to sats
      final amountInSats = (req.amount * Decimal.fromInt(100000000)).round().toBigInt().toInt();
      
      return {
        'amount': amountInSats,
        'description': description,
        'timestamp': req.timestamp.toInt(),
        'payment_hash': paymentHash,
        'expiry': expiry,
      };
    } catch (e) {
      LogUtils.e(() => 'Error decoding BOLT11 invoice: $e');
      return null;
    }
  }

  /// Handle NIP-47 response events (kind 23197)
  Future<void> handleNIP47Response(Event event, String relay) async {
    try {
      LogUtils.d(() => 'Received NIP-47 response: ${event.id} from $relay');
      
      // Extract request ID from 'e' tag
      String? requestId;
      for (var tag in event.tags) {
        if (tag.length >= 2 && tag[0] == 'e') {
          requestId = tag[1];
          break;
        }
      }
      
      if (requestId == null) {
        LogUtils.w(() => 'No request ID found in NIP-47 response');
        return;
      }
      
      // Check if we have a pending request for this ID
      final completer = _pendingRequests[requestId];
      if (completer == null) {
        LogUtils.w(() => 'No pending request found for ID: $requestId');
        return;
      }
      
      // Get current account's private key
      final privkey = Account.sharedInstance.currentPrivkey;
      if (privkey.isEmpty) {
        LogUtils.e(() => 'No private key available for NIP-47 response');
        completer.complete(null);
        return;
      }
      
      // Get current account's public key
      final pubkey = Account.sharedInstance.currentPubkey;
      if (pubkey.isEmpty) {
        LogUtils.e(() => 'No public key available for NIP-47 response');
        completer.complete(null);
        return;
      }
      
      // Parse NIP-47 response
      // For NIP-47 responses: sender is event.pubkey (relay), receiver is user pubkey
      final nwcResponse = await Nip47.response(
        event,
        event.pubkey, // sender (relay pubkey from event)
        pubkey, // receiver (our pubkey)
        privkey,
      );
      
      if (nwcResponse != null) {
        if (!nwcResponse.isSuccess) {
          LogUtils.e(() => 'NIP-47 response error: ${nwcResponse.errorMessage}');
          // Complete with error
          completer.complete({
            'error': true,
            'code': nwcResponse.errorCode,
            'message': nwcResponse.errorMessage,
          });
        } else {
          LogUtils.d(() => 'NIP-47 response success: ${nwcResponse.result}');
          // Complete with success result
          completer.complete(nwcResponse.result);
        }
      } else {
        LogUtils.w(() => 'Failed to parse NIP-47 response');
        completer.complete(null);
      }
      
      // Remove from pending requests
      _pendingRequests.remove(requestId);
      
    } catch (e) {
      LogUtils.e(() => 'Error handling NIP-47 response: $e');
      // Complete with error
      final requestId = _extractRequestId(event);
      if (requestId != null) {
        final completer = _pendingRequests[requestId];
        if (completer != null && !completer.isCompleted) {
          completer.complete({
            'error': true,
            'message': e.toString(),
          });
          _pendingRequests.remove(requestId);
        }
      }
    }
  }
  
  /// Extract request ID from event tags
  String? _extractRequestId(Event event) {
    for (var tag in event.tags) {
      if (tag.length >= 2 && tag[0] == 'e') {
        return tag[1];
      }
    }
    return null;
  }
  
  
  

  /// Start polling payment status for a subscription invoice
  void _startPollingPaymentStatus(String paymentHash, String relayPubkey) {
    // Stop existing polling if any
    _stopPollingPaymentStatus(paymentHash);
    
    LogUtils.d(() => 'Starting payment status polling for: $paymentHash');
    
    // Start polling every 15 seconds
    final timer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      try {
        final status = await lookupSubscriptionInvoice(
          paymentHash: paymentHash,
          relayPubkey: relayPubkey,
        );
        
        if (status != null && !status.containsKey('error')) {
          final isPaid = status['paid'] as bool? ?? false;
          
          // Notify about status change
          onPaymentStatusChanged?.call(paymentHash, isPaid, status);
          
          // If paid, stop polling
          if (isPaid) {
            LogUtils.d(() => 'Payment completed for: $paymentHash');
            _stopPollingPaymentStatus(paymentHash);
          }
        }
      } catch (e) {
        LogUtils.e(() => 'Error polling payment status for $paymentHash: $e');
      }
    });
    
    _pollingTimers[paymentHash] = timer;
  }
  
  /// Stop polling payment status for a specific invoice
  void _stopPollingPaymentStatus(String paymentHash) {
    final timer = _pollingTimers[paymentHash];
    if (timer != null) {
      timer.cancel();
      _pollingTimers.remove(paymentHash);
      LogUtils.d(() => 'Stopped payment status polling for: $paymentHash');
    }
  }
  
  /// Stop all payment status polling
  void stopAllPaymentPolling() {
    for (var timer in _pollingTimers.values) {
      timer.cancel();
    }
    _pollingTimers.clear();
    LogUtils.d(() => 'Stopped all payment status polling');
  }
  
  /// Manually check payment status (can be called by upper layer)
  Future<Map<String, dynamic>?> checkPaymentStatus({
    required String paymentHash,
    required String relayPubkey,
  }) async {
    return await lookupSubscriptionInvoice(
      paymentHash: paymentHash,
      relayPubkey: relayPubkey,
    );
  }

  /// Send event to group relay
  Future<bool> _sendEventToGroupRelay(Event event, String groupId) async {
    try {
      // Get group relay URL from RelayGroup
      final groupRelays = RelayGroup.sharedInstance.groupRelays;
      if (groupRelays.isEmpty) {
        LogUtils.e(() => 'No group relays available');
        return false;
      }

      // Use only the first relay
      final relayUrl = groupRelays.first;
      final completer = Completer<bool>();

      try {
        Connect.sharedInstance.sendEvent(
          event,
          toRelays: [relayUrl],
          sendCallBack: (ok, relay) {
            if (ok.status) {
              LogUtils.d(() => 'Event sent successfully to $relay');
              if (!completer.isCompleted) {
                completer.complete(true);
              }
            } else {
              LogUtils.e(() => 'Failed to send event to $relay: ${ok.message}');
              if (!completer.isCompleted) {
                completer.complete(false);
              }
            }
          },
        );
      } catch (e) {
        LogUtils.e(() => 'Error sending event to $relayUrl: $e');
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      }

      // Wait for send to complete with timeout
      return await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          LogUtils.e(() => 'Timeout waiting for event send completion');
          return false;
        },
      );
    } catch (e) {
      LogUtils.e(() => 'Error sending event to group relay: $e');
      return false;
    }
  }

  /// Load wallet info from relay using NIP-78 event with d=chuchu-wallet
  Future<WalletInfo?> _loadWalletInfoFromRelay(String pubkey, String privkey) async {
    try {
      LogUtils.d(() => 'Loading wallet info from relay for pubkey: $pubkey');
      
      // Create filter to query kind 30078 events with d=chuchu-wallet
      Filter filter = Filter(
        kinds: [30078],
        authors: [pubkey],
        d: ['chuchu-wallet'],
        limit: 1,
      );
      
      Completer<WalletInfo?> completer = Completer<WalletInfo?>();
      List<Event> events = [];
      
      // Query relay for wallet info
      Connect.sharedInstance.addSubscription(
        [filter],
        eventCallBack: (event, relay) async {
          LogUtils.d(() => 'Received wallet event from relay: ${event.id}');
          events.add(event);
        },
        eoseCallBack: (requestId, ok, relay, unRelays) async {
          if (unRelays.isEmpty) {
            if (events.isNotEmpty) {
              try {
                // Get the latest event
                Event latestEvent = events.first;
                
                // Decode NIP-78 app data
                AppData appData = Nip78.decodeAppData(latestEvent);
                
                // Decrypt content using NIP-44
                String decryptedContent = await Nip44.decryptContent(
                  appData.content,
                  pubkey, // peer pubkey (same as our pubkey for self-encryption)
                  pubkey, // my pubkey
                  privkey,
                );
                
                LogUtils.d(() => 'Decrypted wallet content: ${decryptedContent.substring(0, 50)}...');
                
                // Parse JSON to WalletInfo
                Map<String, dynamic> walletJson = jsonDecode(decryptedContent);
                WalletInfo walletInfo = WalletInfo.fromJson(walletJson);
                
                LogUtils.d(() => 'Successfully loaded wallet from relay: ${walletInfo.walletId}');
                if (!completer.isCompleted) {
                  completer.complete(walletInfo);
                }
              } catch (e) {
                LogUtils.e(() => 'Error processing wallet event from relay: $e');
                if (!completer.isCompleted) {
                  completer.complete(null);
                }
              }
            } else {
              LogUtils.d(() => 'No wallet events found on relay');
              if (!completer.isCompleted) {
                completer.complete(null);
              }
            }
          }
        },
      );
      
      // Wait for query to complete
      return await completer.future;
    } catch (e) {
      LogUtils.e(() => 'Error loading wallet info from relay: $e');
      return null;
    }
  }

  /// Save wallet info to relay using NIP-78 event with d=chuchu-wallet
  Future<bool> _saveWalletInfoToRelay(WalletInfo walletInfo, String pubkey, String privkey) async {
    try {
      LogUtils.d(() => 'Saving wallet info to relay: ${walletInfo.walletId}');
      
      // Convert wallet info to JSON string
      String walletJsonString = jsonEncode(walletInfo.toJson());
      
      // Encrypt content using NIP-44 (self-encryption)
      String encryptedContent = await Nip44.encryptContent(
        walletJsonString,
        pubkey, // peer pubkey (same as our pubkey for self-encryption)
        pubkey, // my pubkey
        privkey,
      );
      
      LogUtils.d(() => 'Encrypted wallet content for relay storage');
      
      // Create NIP-78 event
      Event walletEvent = Nip78.encodeAppData(
        pubkey: pubkey,
        content: encryptedContent,
        d: 'chuchu-wallet',
      );
      
      // Sign the event
      Event signedEvent = await Event.from(
        kind: walletEvent.kind,
        pubkey: walletEvent.pubkey,
        createdAt: walletEvent.createdAt,
        tags: walletEvent.tags,
        content: walletEvent.content,
        privkey: privkey,
      );
      
      LogUtils.d(() => 'Created signed wallet event: ${signedEvent.id}');
      
      // Send to relay
      Completer<bool> completer = Completer<bool>();
      
      Connect.sharedInstance.sendEvent(
        signedEvent,
        sendCallBack: (ok, relay) {
          if (ok.status) {
            LogUtils.d(() => 'Wallet info saved to relay successfully: $relay');
            if (!completer.isCompleted) {
              completer.complete(true);
            }
          } else {
            LogUtils.e(() => 'Failed to save wallet info to relay $relay: ${ok.message}');
            if (!completer.isCompleted) {
              completer.complete(false);
            }
          }
        },
      );
      
      // Wait for send to complete
      return await completer.future;
    } catch (e) {
      LogUtils.e(() => 'Error saving wallet info to relay: $e');
      return false;
    }
  }

  /// Cleanup resources
  void dispose() {
    _stopInvoiceCheckTimer();
    onBalanceChanged = null;
    onTransactionAdded = null;
    
    // Complete all pending requests with null
    for (var completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    }
    _pendingRequests.clear();
    
    // Complete connection completer if exists
    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      _connectionCompleter!.complete(false);
    }
    _connectionCompleter = null;
    
    // Stop all polling timers
    stopAllPaymentPolling();
  }


}
