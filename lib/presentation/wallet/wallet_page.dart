import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:bolt11_decoder/bolt11_decoder.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common_image.dart';
import '../../core/widgets/common_toast.dart';
import '../../core/wallet/wallet.dart';
import '../../core/wallet/model/wallet_transaction.dart';
import '../../core/utils/ui_refresh_mixin.dart';
import 'transaction_detail_page.dart';
import 'transactions_page.dart';
import '../../core/wallet/model/wallet_info.dart';
import 'scan_qr_page.dart';

class WalletPage extends StatefulWidget {
  @override
  _WalletPageState createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> with ChuChuUIRefreshMixin {
  final Wallet _wallet = Wallet.sharedInstance;
  bool _isLoading = false;
  String _statusMessage = '';
  double? _usdValue;
  List<WalletTransaction> _allTransactions = [];

  @override
  void initState() {
    super.initState();
    _setupCallbacks();
  }

  @override
  void dispose() {
    _wallet.dispose();
    super.dispose();
  }

  void _setupCallbacks() {
    _wallet.onBalanceChanged = () {
      _updateUsdValue();
      _updateTransactions();
      if (mounted) {
        setState(() {});
      }
    };
    _wallet.onTransactionAdded = () {
      _updateTransactions();
      if (mounted) {
        setState(() {});
      }
    };

    _initializeWallet();
  }

  Future<void> _updateTransactions() async {
    try {
      _allTransactions = await _wallet.getAllTransactions();
    } catch (e) {
      print('Failed to update transactions: $e');
    }
  }

  Future<void> _updateUsdValue() async {
    if (_wallet.walletInfo != null) {
      try {
        final usdValue = await _wallet.satsToUsd(
          _wallet.walletInfo!.totalBalance,
        );
        if (mounted) {
          setState(() {
            _usdValue = usdValue;
          });
        }
      } catch (e) {
        print('Failed to get USD value: $e');
      }
    }
  }

  Future<void> _initializeWallet() async {
    try {
      await _wallet.init();
      await _updateUsdValue();
      await _updateTransactions();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Failed to initialize wallet: $e');
    }
  }

  @override
  Widget buildBody(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: kTitleColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Wallet',
          style: TextStyle(
            color: kTitleColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        foregroundColor: kTitleColor,
        actions: [
          IconButton(
            icon: CommonImage(
              iconName: 'refresh_icon.png',
              size: 24,
              color: kTitleColor,
            ),
            onPressed: _isLoading ? null : _refreshData,
          ),
        ],
      ),
      body:
          _isLoading
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(_statusMessage),
                  ],
                ),
              )
              : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildBalanceCard(),
                    _buildQuickActions(),
                    SizedBox(height: 16),
                    _buildRecentTransactions(),
                  ],
                ),
              ),
    );
  }

  Widget _buildBalanceCard() {
    WalletInfo? balance = _wallet.walletInfo;
    final theme = Theme.of(context);
    if (balance == null) {
      return AspectRatio(
        aspectRatio: 1203 / 651,
        child: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/wallet_card_bg.png'),
              fit: BoxFit.cover,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Loading balance ', style: TextStyle(color: Colors.white70)),
              SizedBox(width: 8),
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }
    String formatBalance(int balance) {
      return balance.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
    }

    return AspectRatio(
      aspectRatio: 1203 / 651,
      child: Container(
        padding: EdgeInsets.only(top: 40),
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/wallet_card_bg.png'),
            fit: BoxFit.cover,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'TOTAL BALANCE',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.outline,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  formatBalance(balance.totalBalance),
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
                SizedBox(width: 8),
                Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Text(
                    'sats',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: kYellow,
                    ),
                  ),
                ),
              ],
            ),
            if (_usdValue != null) ...[
              SizedBox(height: 8),
              Text(
                '≈ \$${_usdValue!.toStringAsFixed(2)} USD',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              'Send',
              'send_icon.png',
              Colors.white,
              theme.colorScheme.primary,
              theme.colorScheme.onSurface,
              () => _showSendDialog(),
            ),
          ),
          if (!kIsWeb) ...[
            SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                'Scan',
                'scan_icon.png',
                null,
                Colors.white,
                theme.colorScheme.onSurface,
                () => _showScanDialog(),
                useGradient: true,
              ),
            ),
          ],
          SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              'Receive',
              'receive_icon.png',
              Colors.white,
              theme.colorScheme.tertiary,
              theme.colorScheme.onSurface,
              () => _showReceiveDialog(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    String iconName,
    Color? backgroundColor,
    Color? iconColor,
    Color textColor,
    VoidCallback onTap, {
    bool useGradient = false,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: useGradient ? null : backgroundColor,
              gradient: useGradient ? getBrandGradientDiagonal() : null,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.tertiary.withOpacity(0.2),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: CommonImage(
                iconName: iconName,
                size: 32,
                color: iconColor,
              ),
            ),
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions() {
    final theme = Theme.of(context);
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'History',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: kTitleColor,
                ),
              ),
              Spacer(),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => TransactionsPage()),
                  );
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'See All',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B46C1),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          if (_allTransactions.isEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CommonImage(iconName: 'wallet_history_icon.png', width: 150),
                  SizedBox(height: 24),
                  Text(
                    'No transactions yet',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Your transaction history will appear here once you start using your wallet.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children:
                    _allTransactions.take(5).toList().asMap().entries.map((
                      entry,
                    ) {
                      final index = entry.key;
                      final tx = entry.value;
                      final transactionsList =
                          _allTransactions.take(5).toList();
                      final isLast = index == transactionsList.length - 1;
                      return Column(
                        children: [
                          _buildTransactionItem(tx),
                          if (!isLast)
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: theme.colorScheme.outline.withAlpha(10),
                              indent: 80,
                            ),
                        ],
                      );
                    }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(WalletTransaction tx) {
    bool isInvoiceExpired = false;
    if (tx.isIncoming && tx.invoice != null && tx.invoice!.isNotEmpty) {
      try {
        final Bolt11PaymentRequest req = Bolt11PaymentRequest(tx.invoice!);
        final invoiceTimestamp = req.timestamp.toInt();
        int expiry = 0;
        
        for (final tag in req.tags) {
          if (tag.type == 'expiry') {
            expiry = tag.data as int;
            break;
          }
        }
        
        final invoiceExpiry = expiry > 0 ? expiry : 3600;
        final actualExpiresAt = invoiceTimestamp + invoiceExpiry;
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        isInvoiceExpired = actualExpiresAt < now;
      } catch (e) {
        isInvoiceExpired = false;
      }
    }
    
    final displayStatus = isInvoiceExpired ? TransactionStatus.expired : tx.status;
    
    String formatTimeAgo(int timestamp) {
      final now = DateTime.now();
      final txTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
      final diff = now.difference(txTime);

      if (diff.inDays >= 2) {
        return '${diff.inDays} days ago';
      } else if (diff.inDays >= 1) {
        return 'Yesterday';
      } else if (diff.inHours >= 1) {
        return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
      } else if (diff.inMinutes >= 1) {
        return '${diff.inMinutes} min${diff.inMinutes > 1 ? 's' : ''} ago';
      } else {
        return 'Just now';
      }
    }

    String formatAmount(int amount) {
      return amount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
    }

    IconData getTransactionIcon() {
      final desc = tx.description?.toLowerCase() ?? '';
      if (desc.contains('zap')) {
        return Icons.bolt_rounded;
      } else if (desc.contains('coffee') || desc.contains('star')) {
        return Icons.local_cafe_rounded;
      } else if (desc.contains('subscription') || desc.contains('pro')) {
        return Icons.shopping_cart_rounded;
      }
      return tx.isIncoming
          ? Icons.arrow_downward_rounded
          : Icons.arrow_upward_rounded;
    }

    Color getIconColor() {
      final desc = tx.description?.toLowerCase() ?? '';
      if (desc.contains('zap')) {
        return Colors.amber[700]!;
      } else if (desc.contains('coffee') || desc.contains('star')) {
        return Colors.grey[700]!;
      } else if (desc.contains('subscription') || desc.contains('pro')) {
        return Color(0xFFE91E63);
      }
      return tx.isIncoming ? Colors.green[600]! : Colors.grey[700]!;
    }

    Color getIconBackgroundColor() {
      final desc = tx.description?.toLowerCase() ?? '';
      if (desc.contains('zap')) {
        return Colors.amber[100]!;
      } else if (desc.contains('coffee') || desc.contains('star')) {
        return Colors.grey[200]!;
      } else if (desc.contains('subscription') || desc.contains('pro')) {
        return Color(0xFFFCE4EC);
      }
      return tx.isIncoming ? Colors.green[100]! : Colors.grey[200]!;
    }

    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showTransactionDetail(tx),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: getIconBackgroundColor(),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  getTransactionIcon(),
                  color: getIconColor(),
                  size: 24,
                ),
              ),
              SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.description?.isNotEmpty == true
                          ? tx.description!
                          : 'Transaction',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: kTitleColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      formatTimeAgo(tx.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.outline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${tx.isIncoming ? '+' : '-'}${formatAmount(tx.amount)} sats',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tx.isIncoming ? Colors.green[600] : kTitleColor,
                    ),
                  ),
                  SizedBox(height: 2),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(displayStatus).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isInvoiceExpired ? 'Expired' : _getStatusText(displayStatus),
                      style: TextStyle(
                        fontSize: 12,
                        color: _getStatusColor(displayStatus),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.confirmed:
        return Colors.green[700]!;
      case TransactionStatus.pending:
        return Colors.orange[700]!;
      case TransactionStatus.failed:
        return Colors.red[700]!;
      case TransactionStatus.expired:
        return Colors.deepOrange[700]!;
    }
  }

  String _getStatusText(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.confirmed:
        return 'Confirmed';
      case TransactionStatus.pending:
        return 'Pending';
      case TransactionStatus.failed:
        return 'Failed';
      case TransactionStatus.expired:
        return 'Expired';
    }
  }

  void _showTransactionDetail(WalletTransaction transaction) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionDetailPage(transaction: transaction),
      ),
    );
  }

  Future<void> _refreshData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Refreshing data...';
    });

    try {
      await _wallet.refreshBalance();
      await _wallet.refreshTransactions();
      await _wallet.refreshInvoiceStatuses();
      await _updateTransactions();

      if (mounted) {
        setState(() {
          _statusMessage = 'Data refresh completed';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Refresh failed: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSendDialog() {
    final invoiceController = TextEditingController();
    final theme = Theme.of(context);
    _showBlurDialog(
      barrierLabel: 'Send Payment Dialog',
      child: Dialog(
        insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
        child: SingleChildScrollView(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Colors.grey[50]!],
              ),
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                FocusScope.of(context).requestFocus(FocusNode());
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      CommonImage(
                        iconName: 'send_icon.png',
                        size: 24,
                        color: theme.colorScheme.primary,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Send Payment',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          color: kTitleColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),

                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.05),
                          spreadRadius: 1,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: invoiceController,
                      autofocus: false,
                      decoration: InputDecoration(
                        labelText: 'Lightning Invoice (BOLT11)',
                        hintText: 'lnbc1...',
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(left: 12, right: 4),
                          child: CommonImage(
                            iconName: 'record_icon.png',
                            width: 20,
                            height: 20,
                            fit: BoxFit.contain,
                          ),
                        ),
                        prefixIconConstraints: BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                          maxWidth: 36,
                          maxHeight: 36,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: kBgLight,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        labelStyle: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.outline,
                        ),
                        hintStyle: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      maxLines: 4,
                      minLines: 2,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: kTitleColor,
                      ),
                    ),
                  ),

                  SizedBox(height: 12),

                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Enter Lightning invoice to send payment',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.outline,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                  SizedBox(height: 24),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 50,
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: Color(0xFFE2E8F0),
                                width: 1,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          height: 50,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap:
                                  () => _parseInvoiceAndConfirm(
                                    invoiceController.text,
                                  ),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: getBrandGradientHorizontal(),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Next',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _parseInvoiceAndConfirm(String invoice) async {
    if (invoice.isEmpty) {
      CommonToast.instance.show(context, 'Please enter a valid Lightning invoice', toastType: ToastType.failed);
      return;
    }

    Navigator.of(context, rootNavigator: true).pop();

    _showBlurDialog(
      barrierDismissible: false,
      barrierLabel: 'Parsing Invoice Dialog',
      child: AlertDialog(
        title: Text('Parsing Invoice'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Parsing invoice details...'),
          ],
        ),
      ),
    );

    try {
      final invoiceData = await _wallet.parseInvoice(invoice);

      Navigator.of(context, rootNavigator: true).pop();

      if (invoiceData != null) {
        if (invoiceData['expired'] == true) {
          CommonToast.instance.show(context, 'Invoice has expired', toastType: ToastType.failed);
        } else {
          _showConfirmPaymentDialog(invoice, invoiceData);
        }
      } else {
        CommonToast.instance.show(context, 'Failed to parse invoice', toastType: ToastType.failed);
      }
    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();

      CommonToast.instance.show(context, 'Error parsing invoice: $e', toastType: ToastType.failed);
    }
  }

  void _showConfirmPaymentDialog(
    String invoice,
    Map<String, dynamic> invoiceData,
  ) {
    final amount = invoiceData['amount'] as int;
    final description = invoiceData['description'] as String? ?? '';
    final theme = Theme.of(context);
    _showBlurDialog(
      barrierLabel: 'Confirm Payment Dialog',
      child: Dialog(
        insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
        child: SingleChildScrollView(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Colors.grey[50]!],
              ),
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                FocusScope.of(context).requestFocus(FocusNode());
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.payment_rounded,
                        size: 24,
                        color: Colors.orange[600],
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Confirm Payment',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          color: kTitleColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),

                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: kBgLight,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Color(0xFFF1F5F9),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              CommonImage(
                                iconName: 'lightning_icon.png',
                                size: 20,
                                color: kYellow,
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Amount',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      '$amount sats',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: kTitleColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'LIGHTNING',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF008236),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (description.isNotEmpty) ...[
                          SizedBox(height: 12),
                          Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: kBgLight,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Color(0xFFF1F5F9),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                CommonImage(
                                  iconName: 'record_icon.png',
                                  size: 20,
                                  color: Color(0xFF2B7FFF),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Description',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color:
                                              theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        description,
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: kTitleColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  SizedBox(height: 12),

                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Review payment details before sending',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.outline,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                  SizedBox(height: 24),

                  // Action buttons
                  Row(
                    children: [
                      Container(
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Color(0xFFE2E8F0),
                              width: 1,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () => _sendPayment(invoice, description),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange[600],
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.send_rounded, size: 18),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Send Payment',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendPayment(String invoice, String description) async {
    Navigator.of(context, rootNavigator: true).pop();

    _showBlurDialog(
      barrierDismissible: false,
      barrierLabel: 'Sending Payment Dialog',
      child: AlertDialog(
        title: Text('Sending Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Processing payment...'),
          ],
        ),
      ),
    );

    try {
      final transaction = await _wallet.sendPayment(
        invoice,
        description: description,
      );

      Navigator.of(context, rootNavigator: true).pop();

      if (transaction != null) {
        CommonToast.instance.show(context, 'Payment sent successfully!', toastType: ToastType.success);
        if (mounted) {
          setState(() {});
        }
      } else {
        CommonToast.instance.show(context, 'Payment failed', toastType: ToastType.failed);
      }
    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();

      CommonToast.instance.show(context, 'Payment error: $e', toastType: ToastType.failed);
    }
  }

  void _showReceiveDialog() {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    final theme = Theme.of(context);
    _showBlurDialog(
      barrierLabel: 'Create Invoice Dialog',
      child: Dialog(
        insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
        child: SingleChildScrollView(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Colors.grey[50]!],
              ),
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                FocusScope.of(context).requestFocus(FocusNode());
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with icon
                  Row(
                    children: [
                      CommonImage(iconName: 'qr_code_icon.png', size: 24),
                      SizedBox(width: 12),
                      Text(
                        'Create Invoice',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          color: kTitleColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),

                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: kBgLight,
                    ),
                    child: TextField(
                      controller: amountController,
                      autofocus: false,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Amount (sats)',
                        hintText: '1000',
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(left: 12, right: 4),
                          child: CommonImage(
                            iconName: 'lightning_icon.png',
                            width: 20,
                            height: 20,
                            color: kYellow,
                            fit: BoxFit.contain,
                          ),
                        ),
                        prefixIconConstraints: BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                          maxWidth: 36,
                          maxHeight: 36,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: kBgLight,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        labelStyle: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.outline,
                        ),
                        hintStyle: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: kTitleColor,
                      ),
                    ),
                  ),

                  SizedBox(height: 16),

                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: kBgLight,
                    ),
                    child: TextField(
                      controller: descriptionController,
                      autofocus: false,
                      decoration: InputDecoration(
                        labelText: 'Description (Optional)',
                        hintText: 'Payment for...',
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(left: 12, right: 4),
                          child: CommonImage(
                            iconName: 'record_icon.png',
                            width: 20,
                            height: 20,
                            color: theme.colorScheme.outline,
                            fit: BoxFit.contain,
                          ),
                        ),
                        prefixIconConstraints: BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                          maxWidth: 36,
                          maxHeight: 36,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: kBgLight,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        labelStyle: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.outline,
                        ),
                        hintStyle: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      maxLines: 2,
                      minLines: 1,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: kTitleColor,
                      ),
                    ),
                  ),

                  SizedBox(height: 12),

                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Create a Lightning invoice to receive payment',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.outline,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                  SizedBox(height: 24),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 50,
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: Color(0xFFE2E8F0),
                                width: 1,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          height: 50,
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap:
                                  () => _createInvoice(
                                    amountController.text,
                                    descriptionController.text,
                                  ),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: getBrandGradientHorizontal(),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.add_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Create',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createInvoice(String amountText, String description) async {
    final amount = int.tryParse(amountText);
    if (amount == null || amount <= 0) {
      CommonToast.instance.show(context, 'Please enter a valid amount', toastType: ToastType.failed);
      return;
    }

    Navigator.of(context, rootNavigator: true).pop();

    _showBlurDialog(
      barrierDismissible: false,
      barrierLabel: 'Creating Invoice Dialog',
      child: AlertDialog(
        title: Text(
          'Creating Invoice',
          style: GoogleFonts.inter(
            color: kTitleColor,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Generating invoice...',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.outline,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final invoice = await _wallet.createInvoice(
        amount,
        description: description.isEmpty ? null : description,
      );

      Navigator.of(context, rootNavigator: true).pop();

      if (invoice != null) {
        _showInvoiceDialog(invoice);
      } else {
        CommonToast.instance.show(context, 'Failed to create invoice', toastType: ToastType.failed);
      }
    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();

      final errorString = e.toString().toLowerCase();
      if (errorString.contains('rate-limited') || errorString.contains('slow down')) {
        CommonToast.instance.show(context, 'Rate limit reached. Please try again later.', toastType: ToastType.failed);
      } else {
        CommonToast.instance.show(context, 'Invoice creation error: $e', toastType: ToastType.failed);
      }
    }
  }

  void _showInvoiceDialog(invoice) {
    final theme = Theme.of(context);
    _showBlurDialog(
      barrierLabel: 'Invoice Created Dialog',
      child: AlertDialog(
        insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Text(
          'Invoice Created',
          style: GoogleFonts.inter(
            fontSize: 20,
            color: kTitleColor,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary.withOpacity(0.08),
                      Theme.of(context).colorScheme.secondary.withOpacity(0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(10),
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: CommonImage(
                        iconName: 'lightning_icon.png',
                        color: kYellow,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Amount',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.outline,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '${invoice.amount} sats',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: kTitleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (invoice.description.isNotEmpty) ...[
                SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: kBgLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Color(0xFFF1F5F9), width: 1),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(10),
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: CommonImage(
                          iconName: 'record_icon.png',
                          size: 20,
                          color: theme.colorScheme.outline,
                        ),
                      ),

                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Description',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.outline,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              invoice.description,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: kTitleColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: 20),
              Text(
                'BOLT11 Invoice',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: kTitleColor,
                ),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color(0xFFF1F5F9), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      invoice.bolt11,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: 8),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.grey[600]),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Share or copy this invoice to receive Lightning payments.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Color(0xFFF1F5F9), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    SizedBox(
                      width: 220,
                      height: 220,
                      child: QrImageView(
                        data: invoice.bolt11,
                        version: QrVersions.auto,
                        backgroundColor: Colors.white,
                        errorStateBuilder: (context, error) {
                          return Container(
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red[400],
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'QR unavailable',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Scan this QR code with any Lightning wallet',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            child: Text(
              'Close',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              _copyToClipboard(invoice.bolt11);
            },
            child: Text(
              'Copy',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<T?> _showBlurDialog<T>({
    required Widget child,
    bool barrierDismissible = true,
    String barrierLabel = 'Dialog',
  }) {
    return showGeneralDialog<T>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: barrierDismissible,
      barrierLabel: barrierLabel,
      barrierColor: Colors.transparent,
      pageBuilder: (context, anim1, anim2) {
        return Stack(
          children: [
            Positioned.fill(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(color: Colors.black.withOpacity(0.2)),
                ),
              ),
            ),
            Center(
              child: SafeArea(
                child: Material(
                  type: MaterialType.card,
                  color: Colors.transparent,
                  elevation: 24,
                  child: child,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _copyToClipboard(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      CommonToast.instance.show(context, 'Copied to clipboard', toastType: ToastType.success);
    } catch (e) {
      CommonToast.instance.show(context, 'Failed to copy to clipboard', toastType: ToastType.failed);
    }
  }

  void _showScanDialog() async {
    final String? scannedInvoice = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => ScanQRPage()),
    );

    if (scannedInvoice != null && scannedInvoice.isNotEmpty) {
      await _parseInvoiceAndConfirm(scannedInvoice);
    }
  }
}
