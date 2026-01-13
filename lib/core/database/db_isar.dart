import 'dart:async';
import 'package:isar/isar.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
// Conditional import for dart:io classes
import 'dart:io' if (dart.library.html) 'package:chuchu/core/account/platform_stub.dart';
import 'package:path_provider/path_provider.dart';

import '../account/model/relayDB_isar.dart';
import '../account/model/userDB_isar.dart';
import '../account/model/zapRecordsDB_isar.dart';
import '../account/model/zapsDB_isar.dart';
import '../config/configDB_isar.dart';
import '../feed/model/noteDB_isar.dart';
import '../feed/model/notificationDB_isar.dart';
import '../messages/model/messageDB_isar.dart';
import '../network/eventDB_isar.dart';
import '../relayGroups/model/groupDB_isar.dart';
import '../relayGroups/model/joinRequestDB_isar.dart';
import '../relayGroups/model/moderationDB_isar.dart';
import '../relayGroups/model/relayGroupDB_isar.dart';
import '../wallet/model/wallet_info.dart';
import '../wallet/model/wallet_transaction.dart';
import '../wallet/model/wallet_invoice.dart';
import '../feed/model/feedDraftDB_isar.dart';
import 'indexed_db_storage.dart';
import 'database_interface.dart';

class DBISAR {
  static final DBISAR sharedInstance = DBISAR._internal();
  DBISAR._internal();
  factory DBISAR() => sharedInstance;

  Isar? _isar;
  IndexedDBStorage? _indexedDB;
  
  /// Get Isar instance (mobile only)
  Isar get isar {
    if (kIsWeb) {
      throw UnsupportedError('isar property is not available on web. Use web-specific methods instead.');
    }
    if (_isar == null) {
      throw StateError('Database is not open. Call open() first.');
    }
    return _isar!;
  }
  
  /// Get IndexedDB instance (web only)
  IndexedDBStorage? get indexedDB => _indexedDB;

  final Map<Type, List<dynamic>> _buffers = {};

  Timer? _timer;

  // Helper function to save objects with auto-increment id handling
  // Note: Isar's put() only auto-assigns id when it's null, not when it's 0
  // So we need to manually assign id for objects with id == 0
  void _saveToCollection<T>(List<T> objects, IsarCollection<int, T> collection) {
    for (var obj in objects) {
      final dynamic objDynamic = obj;
      if (objDynamic.id == 0) {
        objDynamic.id = collection.autoIncrement();
      }
    }
    collection.putAll(objects);
  }

  List<IsarGeneratedSchema> schemas = [
    MessageDBISARSchema,
    UserDBISARSchema,
    RelayDBISARSchema,
    ZapRecordsDBISARSchema,
    ZapsDBISARSchema,
    GroupDBISARSchema,
    JoinRequestDBISARSchema,
    ModerationDBISARSchema,
    RelayGroupDBISARSchema,
    NoteDBISARSchema,
    NotificationDBISARSchema,
    ConfigDBISARSchema,
    EventDBISARSchema,
    WalletInfoSchema,
    WalletTransactionSchema,
    WalletInvoiceSchema,
    FeedDraftDBISARSchema,
  ];

  Future open(String pubkey) async {
    if (pubkey.isEmpty) {
      throw ArgumentError('pubkey cannot be empty');
    }
    
    if (kIsWeb) {
      // Web platform uses IndexedDB
      debugPrint('[DB-Web] 🔵 Opening IndexedDB database on web platform, pubkey: $pubkey');
      _indexedDB = IndexedDBStorage();
      await _indexedDB!.open(pubkey);
        debugPrint('[DB-Web] ✅ IndexedDB database opened successfully');
        // Process buffered data after database is opened
      if (_buffers.isNotEmpty) {
        debugPrint('[DB-Web] 🔵 Processing ${_buffers.length} buffered data types after database open');
        await _putAll();
      }
    } else {
      bool isOS = Platform.isIOS || Platform.isMacOS;
      // Type cast needed because of conditional import
      dynamic dir = isOS ? await getLibraryDirectory() : await getApplicationDocumentsDirectory();
      Directory directory = dir as Directory;
      var dbPath = directory.path;
      
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      
      debugPrint('🔵 [DBISAR] Opening Isar database on mobile platform, pubkey: $pubkey');
      try {
        _isar = await Isar.open(
          schemas: schemas,
          directory: dbPath,
          name: pubkey,
        );
      } on IsarError catch (e) {
        // Handle schema mismatch errors by deleting old database and recreating
        if (e.toString().contains('Schema error') || 
            e.toString().contains('Could not deserialize existing schema')) {
          debugPrint('⚠️ [DBISAR] Schema error detected, deleting old database and recreating: $e');
          await _deleteDatabaseFiles(directory, pubkey);
          // Retry opening the database after deletion
          _isar = await Isar.open(
            schemas: schemas,
            directory: dbPath,
            name: pubkey,
          );
        } else {
          // Re-throw other errors
          rethrow;
        }
      }
    }
  }
  
  // ==================== Web-specific query methods ====================
  
  /// Get all users (web only)
  Future<List<UserDBISAR>> findAllUsers() async {
    if (!kIsWeb) {
      throw UnsupportedError('findAllUsers() is only available on web platform');
    }
    if (_indexedDB == null) {
      throw StateError('Database is not open. Call open() first.');
    }
    final collection = _indexedDB!.getCollection<UserDBISAR>('userDBISARs');
    final query = collection.where();
    return await query.findAll();
  }
  
  /// Find user by pubKey (web only)
  Future<UserDBISAR?> findUserByPubKey(String pubKey) async {
    if (!kIsWeb) {
      throw UnsupportedError('findUserByPubKey() is only available on web platform');
    }
    if (_indexedDB == null) {
      throw StateError('Database is not open. Call open() first.');
    }
    final collection = _indexedDB!.getCollection<UserDBISAR>('userDBISARs');
    final query = collection.where();
    query.equalTo('pubKey', pubKey);
    return await query.findFirst();
  }
  
  /// Get all relays (web only)
  Future<List<RelayDBISAR>> findAllRelays() async {
    if (!kIsWeb) {
      throw UnsupportedError('findAllRelays() is only available on web platform');
    }
    if (_indexedDB == null) {
      throw StateError('Database is not open. Call open() first.');
    }
    final collection = _indexedDB!.getCollection<RelayDBISAR>('relayDBISARs');
    final query = collection.where();
    return await query.findAll();
  }
  
  /// Get all groups (web only)
  Future<List<GroupDBISAR>> findAllGroups() async {
    if (!kIsWeb) {
      throw UnsupportedError('findAllGroups() is only available on web platform');
    }
    if (_indexedDB == null) {
      throw StateError('Database is not open. Call open() first.');
    }
    final collection = _indexedDB!.getCollection<GroupDBISAR>('groupDBISARs');
    final query = collection.where();
    return await query.findAll();
  }
  
  /// Get all relay groups (web only)
  Future<List<RelayGroupDBISAR>> findAllRelayGroups() async {
    if (!kIsWeb) {
      throw UnsupportedError('findAllRelayGroups() is only available on web platform');
    }
    if (_indexedDB == null) {
      throw StateError('Database is not open. Call open() first.');
    }
    final collection = _indexedDB!.getCollection<RelayGroupDBISAR>('relayGroupDBISARs');
    final query = collection.where();
    return await query.findAll();
  }
  
  /// Get all notes (web only)
  Future<List<NoteDBISAR>> findAllNotes() async {
    if (!kIsWeb) {
      throw UnsupportedError('findAllNotes() is only available on web platform');
    }
    if (_indexedDB == null) {
      throw StateError('Database is not open. Call open() first.');
    }
    final collection = _indexedDB!.getCollection<NoteDBISAR>('noteDBISARs');
    final query = collection.where();
    return await query.findAll();
  }
  
  /// Get all events (web only)
  Future<List<EventDBISAR>> findAllEvents() async {
    if (!kIsWeb) {
      throw UnsupportedError('findAllEvents() is only available on web platform');
    }
    if (_indexedDB == null) {
      throw StateError('Database is not open. Call open() first.');
    }
    final collection = _indexedDB!.getCollection<EventDBISAR>('eventDBISARs');
    final query = collection.where();
    return await query.findAll();
  }
  
  /// Get all wallet infos (web only)
  Future<List<WalletInfo>> findAllWalletInfos() async {
    if (!kIsWeb) {
      throw UnsupportedError('findAllWalletInfos() is only available on web platform');
    }
    if (_indexedDB == null) {
      throw StateError('Database is not open. Call open() first.');
    }
    final collection = _indexedDB!.getCollection<WalletInfo>('walletInfos');
    final query = collection.where();
    return await query.findAll();
  }
  
  /// Get all wallet invoices (web only)
  Future<List<WalletInvoice>> findAllWalletInvoices() async {
    if (!kIsWeb) {
      throw UnsupportedError('findAllWalletInvoices() is only available on web platform');
    }
    if (_indexedDB == null) {
      throw StateError('Database is not open. Call open() first.');
    }
    final collection = _indexedDB!.getCollection<WalletInvoice>('walletInvoices');
    final query = collection.where();
    return await query.findAll();
  }
  
  /// Find wallet invoice by invoiceId (web only)
  Future<WalletInvoice?> findWalletInvoiceByInvoiceId(String invoiceId) async {
    if (!kIsWeb) {
      throw UnsupportedError('findWalletInvoiceByInvoiceId() is only available on web platform');
    }
    if (_indexedDB == null) {
      throw StateError('Database is not open. Call open() first.');
    }
    final collection = _indexedDB!.getCollection<WalletInvoice>('walletInvoices');
    final query = collection.where();
    query.equalTo('invoiceId', invoiceId);
    return await query.findFirst();
  }
  
  /// Get all wallet transactions (web only)
  Future<List<WalletTransaction>> findAllWalletTransactions() async {
    if (!kIsWeb) {
      throw UnsupportedError('findAllWalletTransactions() is only available on web platform');
    }
    if (_indexedDB == null) {
      throw StateError('Database is not open. Call open() first.');
    }
    final collection = _indexedDB!.getCollection<WalletTransaction>('walletTransactions');
    final query = collection.where();
    return await query.findAll();
  }
  
  /// Find messages by groupId (web only)
  Future<List<MessageDBISAR>> findMessagesByGroupId(String groupId, {int? limit}) async {
    if (!kIsWeb) {
      throw UnsupportedError('findMessagesByGroupId() is only available on web platform');
    }
    if (_indexedDB == null) {
      throw StateError('Database is not open. Call open() first.');
    }
    final collection = _indexedDB!.getCollection<MessageDBISAR>('messageDBISARs');
    final query = collection.where();
    query.equalTo('groupId', groupId);
    return await query.findAll(limit: limit);
  }
  
  /// Find notes by conditions (web only)
  Future<List<NoteDBISAR>> findNotes({
    String? pubKey,
    List<int>? kinds,
    int? limit,
  }) async {
    if (!kIsWeb) {
      throw UnsupportedError('findNotes() is only available on web platform');
    }
    if (_indexedDB == null) {
      throw StateError('Database is not open. Call open() first.');
    }
    final collection = _indexedDB!.getCollection<NoteDBISAR>('noteDBISARs');
    final query = collection.where();
    if (pubKey != null) {
      query.equalTo('pubKey', pubKey);
    }
    // Note: kinds filtering needs to be implemented at application layer, as IndexedDB query builder doesn't support complex conditions
    return await query.findAll(limit: limit);
  }
  
  /// Find relay group by groupId (web only)
  Future<RelayGroupDBISAR?> findRelayGroupByGroupId(String groupId) async {
    if (!kIsWeb) {
      throw UnsupportedError('findRelayGroupByGroupId() is only available on web platform');
    }
    if (_indexedDB == null) {
      throw StateError('Database is not open. Call open() first.');
    }
    final collection = _indexedDB!.getCollection<RelayGroupDBISAR>('relayGroupDBISARs');
    final query = collection.where();
    query.equalTo('groupId', groupId);
    return await query.findFirst();
  }
  
  /// Delete events (web only)
  Future<void> deleteEvents(List<int> eventIds) async {
    if (!kIsWeb) {
      throw UnsupportedError('deleteEvents() is only available on web platform');
    }
    if (_indexedDB == null) {
      throw StateError('Database is not open. Call open() first.');
    }
    final collection = _indexedDB!.getCollection<EventDBISAR>('eventDBISARs');
    await collection.deleteAll(eventIds);
  }
  
  /// Write transaction (web only)
  Future<void> writeWeb(Future<void> Function(DatabaseInterface db) callback) async {
    if (!kIsWeb) {
      throw UnsupportedError('writeWeb() is only available on web platform');
    }
    if (_indexedDB == null) {
      throw StateError('Database is not open. Call open() first.');
    }
    await _indexedDB!.write(callback);
  }
  
  /// Search relay groups by relay list (web only)
  /// Note: Web implementation is simpler, it gets all RelayGroups and filters in memory
  Future<List<RelayGroupDBISAR>> searchRelayGroupsByRelays(List<String> relays) async {
    if (!kIsWeb) {
      throw UnsupportedError('searchRelayGroupsByRelays() is only available on web platform');
    }
    if (_indexedDB == null) {
      throw StateError('Database is not open. Call open() first.');
    }
    final collection = _indexedDB!.getCollection<RelayGroupDBISAR>('relayGroupDBISARs');
    final query = collection.where();
    final allGroups = await query.findAll();
    // Filter in memory: check if each group's relay field equals any specified relay
    return allGroups.where((group) {
      return relays.contains(group.relay);
    }).toList();
  }
  
  /// Search notes by hashTags (web only)
  /// Note: Web implementation is simpler, it gets all Notes and filters in memory
  Future<List<NoteDBISAR>> searchNotesByHashTags(List<String> hashTags, {int? limit}) async {
    if (!kIsWeb) {
      throw UnsupportedError('searchNotesByHashTags() is only available on web platform');
    }
    if (_indexedDB == null) {
      throw StateError('Database is not open. Call open() first.');
    }
    final collection = _indexedDB!.getCollection<NoteDBISAR>('noteDBISARs');
    final query = collection.where();
    final allNotes = await query.findAll();
    // Filter in memory: check if each note's hashTags list contains any specified hashTag
    final filteredNotes = allNotes.where((note) {
      final noteHashTags = note.hashTags ?? [];
      return hashTags.any((hashTag) => noteHashTags.contains(hashTag));
    }).toList();
    
    if (limit != null && limit > 0) {
      return filteredNotes.take(limit).toList();
    }
    return filteredNotes;
  }
  
  /// Delete relay group by groupId (web only)
  Future<void> deleteRelayGroupByGroupId(String groupId) async {
    if (!kIsWeb) {
      throw UnsupportedError('deleteRelayGroupByGroupId() is only available on web platform');
    }
    if (_indexedDB == null) {
      throw StateError('Database is not open. Call open() first.');
    }
    final collection = _indexedDB!.getCollection<RelayGroupDBISAR>('relayGroupDBISARs');
    final query = collection.where();
    query.equalTo('groupId', groupId);
    final groups = await query.findAll();
    if (groups.isNotEmpty) {
      final ids = groups.map((g) => g.id).where((id) => id != 0).toList();
      if (ids.isNotEmpty) {
        await collection.deleteAll(ids);
      }
    }
  }
  
  /// Find event by eventId (web only)
  Future<EventDBISAR?> findEventByEventId(String eventId) async {
    if (!kIsWeb) {
      throw UnsupportedError('findEventByEventId() is only available on web platform');
    }
    if (_indexedDB == null) {
      throw StateError('Database is not open. Call open() first.');
    }
    final collection = _indexedDB!.getCollection<EventDBISAR>('eventDBISARs');
    final query = collection.where();
    query.equalTo('eventId', eventId);
    return await query.findFirst();
  }

  Map<Type, List<dynamic>> getBuffers() {
    return Map.from(_buffers);
  }

  Future<void> saveObjectsToDB<T>(List<T> objects) async {
    for (var object in objects) {
      await saveToDB(object);
    }
  }

  Future<void> saveToDB<T>(T object) async {
    final type = T;
    if (!_buffers.containsKey(type)) {
      _buffers[type] = <T>[];
    }
    _buffers[type]!.add(object);

    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 200), () async {
      await _putAll();
    });
  }

  Future<void> _putAll() async {
    _timer?.cancel();
    _timer = null;

    if (_buffers.isEmpty) return;

    final Map<Type, List<dynamic>> typeMap = Map.from(_buffers);
    _buffers.clear();

    if (kIsWeb) {
      // Web platform uses IndexedDB
      if (_indexedDB == null || !_indexedDB!.isOpen) {
        debugPrint('[DB-Web] ⚠️ IndexedDB is not open, skipping save operation. _indexedDB: $_indexedDB, isOpen: ${_indexedDB?.isOpen}');
        // Put data back to buffer, wait for database to open before saving
        for (var type in typeMap.keys) {
          if (!_buffers.containsKey(type)) {
            _buffers[type] = [];
          }
          _buffers[type]!.addAll(typeMap[type]!);
        }
        return;
      }
      for (var type in typeMap.keys) {
        await _saveToIndexedDB(typeMap[type]!, type);
      }
    } else {
      // Mobile platform uses Isar
      await _isar!.write((isar) {
        for (var type in typeMap.keys) {
          _saveTOISARSync(typeMap[type]!, type, isar);
        }
      });
    }
  }
  
  /// Save objects to IndexedDB (web only)
  Future<void> _saveToIndexedDB(List<dynamic> objects, Type type) async {
    if (_indexedDB == null) {
      debugPrint('[DB-Web] ⚠️ _saveToIndexedDB: _indexedDB is null');
      return;
    }
    
    String collectionName;
    switch (type) {
      case UserDBISAR:
        collectionName = 'userDBISARs';
        break;
      case RelayDBISAR:
        collectionName = 'relayDBISARs';
        break;
      case NoteDBISAR:
        collectionName = 'noteDBISARs';
        debugPrint('[DB-Web] 🔵 Saving ${objects.length} NoteDBISAR objects to IndexedDB');
        break;
      case MessageDBISAR:
        collectionName = 'messageDBISARs';
        break;
      case GroupDBISAR:
        collectionName = 'groupDBISARs';
        break;
      case EventDBISAR:
        collectionName = 'eventDBISARs';
        break;
      case RelayGroupDBISAR:
        collectionName = 'relayGroupDBISARs';
        break;
      case ZapRecordsDBISAR:
        collectionName = 'zapRecordsDBISARs';
        break;
      case ZapsDBISAR:
        collectionName = 'zapsDBISARs';
        break;
      case JoinRequestDBISAR:
        collectionName = 'joinRequestDBISARs';
        break;
      case ModerationDBISAR:
        collectionName = 'moderationDBISARs';
        break;
      case NotificationDBISAR:
        collectionName = 'notificationDBISARs';
        break;
      case ConfigDBISAR:
        collectionName = 'configDBISARs';
        break;
      case WalletInfo:
        collectionName = 'walletInfos';
        break;
      case WalletTransaction:
        collectionName = 'walletTransactions';
        break;
      case WalletInvoice:
        collectionName = 'walletInvoices';
        break;
      case FeedDraftDBISAR:
        collectionName = 'feedDraftDBISARs';
        break;
      default:
        debugPrint('[DB-Web] ⚠️ Unknown type for IndexedDB: $type');
        return;
    }
    
    final collection = _indexedDB!.getCollection<dynamic>(collectionName);
    debugPrint('[DB-Web] 🔵 Putting ${objects.length} objects to collection: $collectionName');
    try {
      await collection.putAll(objects);
      debugPrint('[DB-Web] ✅ Successfully saved ${objects.length} objects to $collectionName');
    } catch (e, stackTrace) {
      debugPrint('[DB-Web] ❌ Failed to save ${objects.length} objects to $collectionName: $e');
      debugPrint('[DB-Web] ❌ Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Synchronous version for web platform
  void _saveTOISARSync(List<dynamic> objects, Type type, Isar isar) {
    // All operations must be synchronous within the write transaction on web
    // Type-based dispatch - when adding a new model, just add a new case here
    switch (type) {
      case MessageDBISAR:
        _saveToCollection(objects.cast<MessageDBISAR>().toList(), isar.messageDBISARs);
        break;
      case UserDBISAR:
        _saveToCollection(objects.cast<UserDBISAR>().toList(), isar.userDBISARs);
        break;
      case RelayDBISAR:
        _saveToCollection(objects.cast<RelayDBISAR>().toList(), isar.relayDBISARs);
        break;
      case ZapRecordsDBISAR:
        _saveToCollection(objects.cast<ZapRecordsDBISAR>().toList(), isar.zapRecordsDBISARs);
        break;
      case ZapsDBISAR:
        _saveToCollection(objects.cast<ZapsDBISAR>().toList(), isar.zapsDBISARs);
        break;
      case GroupDBISAR:
        _saveToCollection(objects.cast<GroupDBISAR>().toList(), isar.groupDBISARs);
        break;
      case JoinRequestDBISAR:
        _saveToCollection(objects.cast<JoinRequestDBISAR>().toList(), isar.joinRequestDBISARs);
        break;
      case ModerationDBISAR:
        _saveToCollection(objects.cast<ModerationDBISAR>().toList(), isar.moderationDBISARs);
        break;
      case RelayGroupDBISAR:
        _saveToCollection(objects.cast<RelayGroupDBISAR>().toList(), isar.relayGroupDBISARs);
        break;
      case NoteDBISAR:
        _saveToCollection(objects.cast<NoteDBISAR>().toList(), isar.noteDBISARs);
        break;
      case NotificationDBISAR:
        _saveToCollection(objects.cast<NotificationDBISAR>().toList(), isar.notificationDBISARs);
        break;
      case ConfigDBISAR:
        _saveToCollection(objects.cast<ConfigDBISAR>().toList(), isar.configDBISARs);
        break;
      case EventDBISAR:
        _saveToCollection(objects.cast<EventDBISAR>().toList(), isar.eventDBISARs);
        break;
      case WalletInfo:
        _saveToCollection(objects.cast<WalletInfo>().toList(), isar.walletInfos);
        break;
      case WalletTransaction:
        _saveToCollection(objects.cast<WalletTransaction>().toList(), isar.walletTransactions);
        break;
      case WalletInvoice:
        _saveToCollection(objects.cast<WalletInvoice>().toList(), isar.walletInvoices);
        break;
      case FeedDraftDBISAR:
        _saveToCollection(objects.cast<FeedDraftDBISAR>().toList(), isar.feedDraftDBISARs);
        break;
      default:
        // Fallback: try to use putAll directly (for types without id field or custom handling)
        // This should not happen for our current models, but provides a safety net
        break;
    }
  }

  /// Delete all database files for a given pubkey
  Future<void> _deleteDatabaseFiles(Directory directory, String pubkey) async {
    try {
      // Isar database files: {name}.isar and {name}.isar.lock
      final dbFile = File('${directory.path}/$pubkey.isar');
      final lockFile = File('${directory.path}/$pubkey.isar.lock');
      
      if (await dbFile.exists()) {
        await dbFile.delete();
        print(() => 'Deleted database file: ${dbFile.path}');
      }
      
      if (await lockFile.exists()) {
        await lockFile.delete();
        print(() => 'Deleted lock file: ${lockFile.path}');
      }
    } catch (e) {
      print(() => 'Error deleting database files: $e');
    }
  }

  Future<void> closeDatabase() async {
    _buffers.clear();
    _timer?.cancel();
    _timer = null;
    if (kIsWeb) {
      if (_indexedDB != null && _indexedDB!.isOpen) {
        await _indexedDB!.close();
      }
    } else {
      if (_isar != null && _isar!.isOpen) {
        await _isar!.close();
      }
    }
  }
}
