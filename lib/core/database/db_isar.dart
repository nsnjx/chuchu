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
// Conditional import: indexed_db_storage.dart only works on web (uses dart:html)
import 'indexed_db_storage.dart' if (dart.library.io) 'indexed_db_storage_stub.dart';
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
    
    // Close existing database before opening a new one
    // This ensures clean state when switching users
    await closeDatabase();
    
    if (kIsWeb) {
      // Web platform uses IndexedDB
      _indexedDB = IndexedDBStorage();
      await _indexedDB!.open(pubkey);
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
  /// Returns the latest record if multiple records exist with the same pubKey
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
    // Get all matching records and return the latest one (by id, since newer records have higher id)
    final allUsers = await query.findAll();
    if (allUsers.isEmpty) return null;
    
    // Sort by id descending (newer records have higher id) or by lastUpdatedTime if available
    allUsers.sort((a, b) {
      // First try to sort by lastUpdatedTime (if both have it)
      if (a.lastUpdatedTime > 0 && b.lastUpdatedTime > 0) {
        return b.lastUpdatedTime.compareTo(a.lastUpdatedTime);
      }
      // Otherwise sort by id (newer records have higher id)
      return b.id.compareTo(a.id);
    });
    
    return allUsers.first;
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

  /// Generic deduplication helper for web IndexedDB (web only)
  /// Deduplicates objects by unique field, keeps the latest one, and reuses IDs
  Future<void> _deduplicateAndSave<T>(
    List<dynamic> objects,
    String collectionName,
    String uniqueFieldName,
    String Function(T) getUniqueValue,
    int Function(T) getTimestamp,
  ) async {
    final typedObjects = objects.cast<T>();
    final Map<String, T> uniqueObjects = {};
    
    // Deduplicate by unique field (keep only the latest one)
    for (var obj in typedObjects) {
      final uniqueValue = getUniqueValue(obj);
      if (!uniqueObjects.containsKey(uniqueValue)) {
        uniqueObjects[uniqueValue] = obj;
      } else {
        final existing = uniqueObjects[uniqueValue]!;
        final dynamic objDynamic = obj;
        final dynamic existingDynamic = existing;
        if (getTimestamp(obj) > getTimestamp(existing) ||
            (getTimestamp(obj) == getTimestamp(existing) && objDynamic.id > existingDynamic.id)) {
          uniqueObjects[uniqueValue] = obj;
        }
      }
    }
    
    // Delete existing records and reuse IDs
    final collection = _indexedDB!.getCollection<T>(collectionName);
    final objectsToSave = <T>[];
    
    for (var obj in uniqueObjects.values) {
      final uniqueValue = getUniqueValue(obj);
      final idsToDelete = await _getRawIdsForUniqueField(collectionName, uniqueFieldName, uniqueValue);
      
      if (idsToDelete.isNotEmpty) {
        await collection.deleteAll(idsToDelete);
        final dynamic objDynamic = obj;
        objDynamic.id = idsToDelete.reduce((a, b) => a > b ? a : b);
      }
      
      objectsToSave.add(obj);
    }
    
    objects.clear();
    objects.addAll(objectsToSave);
  }

  /// Get raw IDs from IndexedDB for records matching a unique field value (web only)
  /// Directly queries the raw database to get real IDs, bypassing deserialization
  Future<List<int>> _getRawIdsForUniqueField(String collectionName, String fieldName, String fieldValue) async {
    if (!kIsWeb || _indexedDB == null) {
      return [];
    }
    
    try {
      final db = _indexedDB!.rawDb;
      if (db == null) {
        return [];
      }
      
      final transaction = db.transaction(collectionName, 'readonly');
      final store = transaction.objectStore(collectionName);
      final request = store.getAll(null);
      final allRawObjects = await _requestToFuture<List>(request);
      
      final idsToDelete = <int>[];
      for (var rawObj in allRawObjects) {
        try {
          Map<String, dynamic> map;
          if (rawObj is Map<String, dynamic>) {
            map = rawObj;
          } else if (rawObj is Map) {
            map = Map<String, dynamic>.from(rawObj);
          } else {
            continue;
          }
          
          final rawFieldValue = map[fieldName] as String?;
          final rawId = map['id'];
          
          int? idInt;
          if (rawId is int) {
            idInt = rawId;
          } else if (rawId is String) {
            idInt = int.tryParse(rawId);
          } else if (rawId != null) {
            idInt = int.tryParse(rawId.toString());
          }
          
          if (rawFieldValue == fieldValue && idInt != null && idInt != 0) {
            idsToDelete.add(idInt);
          }
        } catch (e) {
          // Skip invalid records
          continue;
        }
      }
      
      return idsToDelete;
    } catch (e) {
      debugPrint('[DB-Web] ❌ Error getting raw IDs for $fieldName=$fieldValue in $collectionName: $e');
      return [];
    }
  }
  
  /// Helper to convert IndexedDB request to Future (same as in indexed_db_storage.dart)
  Future<T> _requestToFuture<T>(dynamic request) async {
    if (request is Future) {
      return await request as Future<T>;
    }
    
    final completer = Completer<T>();
    try {
      (request as dynamic).onSuccess.listen((dynamic e) {
        final result = (e.target as dynamic).result;
        if (!completer.isCompleted) {
          completer.complete(result as T);
        }
      }, onError: (dynamic e) {
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      });
    } catch (e) {
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    }
    
    return completer.future;
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

  /// Flush all buffered writes immediately (e.g. so Web IndexedDB persists before other code can overwrite in-memory state).
  Future<void> flushBuffers() async {
    _timer?.cancel();
    await _putAll();
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
      return;
    }
    
    String collectionName;
    switch (type) {
      case UserDBISAR:
        collectionName = 'userDBISARs';
        
        // Deduplicate by pubKey (keep only the latest one for each pubKey)
        final userObjects = objects.cast<UserDBISAR>();
        final Map<String, UserDBISAR> uniqueUsers = {};
        
        for (var user in userObjects) {
          final pubKey = user.pubKey;
          if (!uniqueUsers.containsKey(pubKey)) {
            uniqueUsers[pubKey] = user;
          } else {
            final existing = uniqueUsers[pubKey]!;
            if (user.lastUpdatedTime > existing.lastUpdatedTime ||
                (user.lastUpdatedTime == existing.lastUpdatedTime && user.id > existing.id)) {
              uniqueUsers[pubKey] = user;
            }
          }
        }
        
        // Delete existing records and reuse IDs to prevent duplicates
        final collection = _indexedDB!.getCollection<UserDBISAR>(collectionName);
        final usersToSave = <UserDBISAR>[];
        
        for (var user in uniqueUsers.values) {
          final idsToDelete = await _getRawIdsForUniqueField('userDBISARs', 'pubKey', user.pubKey);
          
          if (idsToDelete.isNotEmpty) {
            await collection.deleteAll(idsToDelete);
            user.id = idsToDelete.reduce((a, b) => a > b ? a : b);
          }
          
          usersToSave.add(user);
        }
        
        objects.clear();
        objects.addAll(usersToSave);
        break;
      case RelayDBISAR:
        collectionName = 'relayDBISARs';
        await _deduplicateAndSave<RelayDBISAR>(
          objects,
          collectionName,
          'url',
          (r) => r.url,
          (r) => r.id, // No timestamp field, use id
        );
        break;
      case NoteDBISAR:
        collectionName = 'noteDBISARs';
        
        // Deduplicate by noteId (keep only the latest one for each noteId)
        final noteObjects = objects.cast<NoteDBISAR>();
        final Map<String, NoteDBISAR> uniqueNotes = {};
        
        for (var note in noteObjects) {
          final noteId = note.noteId;
          if (!uniqueNotes.containsKey(noteId)) {
            uniqueNotes[noteId] = note;
          } else {
            final existing = uniqueNotes[noteId]!;
            // Use createAt and id to determine which is newer
            if (note.createAt > existing.createAt ||
                (note.createAt == existing.createAt && note.id > existing.id)) {
              uniqueNotes[noteId] = note;
            }
          }
        }
        
        // Delete existing records and reuse IDs to prevent duplicates
        final collection = _indexedDB!.getCollection<NoteDBISAR>(collectionName);
        final notesToSave = <NoteDBISAR>[];
        
        for (var note in uniqueNotes.values) {
          final idsToDelete = await _getRawIdsForUniqueField('noteDBISARs', 'noteId', note.noteId);
          
          if (idsToDelete.isNotEmpty) {
            await collection.deleteAll(idsToDelete);
            note.id = idsToDelete.reduce((a, b) => a > b ? a : b);
          }
          
          notesToSave.add(note);
        }
        
        objects.clear();
        objects.addAll(notesToSave);
        break;
      case MessageDBISAR:
        collectionName = 'messageDBISARs';
        await _deduplicateAndSave<MessageDBISAR>(
          objects,
          collectionName,
          'messageId',
          (m) => m.messageId,
          (m) => m.createTime,
        );
        break;
      case GroupDBISAR:
        collectionName = 'groupDBISARs';
        await _deduplicateAndSave<GroupDBISAR>(
          objects,
          collectionName,
          'groupId',
          (g) => g.groupId,
          (g) => g.updateTime,
        );
        break;
      case EventDBISAR:
        collectionName = 'eventDBISARs';
        await _deduplicateAndSave<EventDBISAR>(
          objects,
          collectionName,
          'eventId',
          (e) => e.eventId,
          (e) => e.id, // No timestamp field, use id
        );
        break;
      case RelayGroupDBISAR:
        collectionName = 'relayGroupDBISARs';
        
        // Deduplicate by groupId (keep only the latest one for each groupId)
        final groupObjects = objects.cast<RelayGroupDBISAR>();
        final Map<String, RelayGroupDBISAR> uniqueGroups = {};
        
        for (var group in groupObjects) {
          final groupId = group.groupId;
          if (!uniqueGroups.containsKey(groupId)) {
            uniqueGroups[groupId] = group;
          } else {
            final existing = uniqueGroups[groupId]!;
            if (group.lastUpdatedTime > existing.lastUpdatedTime ||
                (group.lastUpdatedTime == existing.lastUpdatedTime && group.id > existing.id)) {
              uniqueGroups[groupId] = group;
            }
          }
        }
        
        // Delete existing records and reuse IDs to prevent duplicates
        final collection = _indexedDB!.getCollection<RelayGroupDBISAR>(collectionName);
        final groupsToSave = <RelayGroupDBISAR>[];
        
        for (var group in uniqueGroups.values) {
          final idsToDelete = await _getRawIdsForUniqueField('relayGroupDBISARs', 'groupId', group.groupId);
          
          if (idsToDelete.isNotEmpty) {
            await collection.deleteAll(idsToDelete);
            group.id = idsToDelete.reduce((a, b) => a > b ? a : b);
          }
          
          groupsToSave.add(group);
        }
        
        objects.clear();
        objects.addAll(groupsToSave);
        break;
      case ZapRecordsDBISAR:
        collectionName = 'zapRecordsDBISARs';
        await _deduplicateAndSave<ZapRecordsDBISAR>(
          objects,
          collectionName,
          'bolt11',
          (z) => z.bolt11,
          (z) => z.paidAt,
        );
        break;
      case ZapsDBISAR:
        collectionName = 'zapsDBISARs';
        // ZapsDBISAR has two unique fields: lnAddr and lnURL
        // Deduplicate by lnAddr (primary unique field)
        final zapObjects = objects.cast<ZapsDBISAR>();
        final Map<String, ZapsDBISAR> uniqueZaps = {};
        
        for (var zap in zapObjects) {
          final lnAddr = zap.lnAddr;
          if (!uniqueZaps.containsKey(lnAddr)) {
            uniqueZaps[lnAddr] = zap;
          } else {
            final existing = uniqueZaps[lnAddr]!;
            if (zap.id > existing.id) {
              uniqueZaps[lnAddr] = zap;
            }
          }
        }
        
        final collection = _indexedDB!.getCollection<ZapsDBISAR>(collectionName);
        final zapsToSave = <ZapsDBISAR>[];
        
        for (var zap in uniqueZaps.values) {
          final idsToDelete = await _getRawIdsForUniqueField('zapsDBISARs', 'lnAddr', zap.lnAddr);
          
          if (idsToDelete.isNotEmpty) {
            await collection.deleteAll(idsToDelete);
            zap.id = idsToDelete.reduce((a, b) => a > b ? a : b);
          }
          
          zapsToSave.add(zap);
        }
        
        objects.clear();
        objects.addAll(zapsToSave);
        break;
      case JoinRequestDBISAR:
        collectionName = 'joinRequestDBISARs';
        await _deduplicateAndSave<JoinRequestDBISAR>(
          objects,
          collectionName,
          'requestId',
          (j) => j.requestId,
          (j) => j.createdAt,
        );
        break;
      case ModerationDBISAR:
        collectionName = 'moderationDBISARs';
        await _deduplicateAndSave<ModerationDBISAR>(
          objects,
          collectionName,
          'moderationId',
          (m) => m.moderationId,
          (m) => m.createdAt,
        );
        break;
      case NotificationDBISAR:
        collectionName = 'notificationDBISARs';
        await _deduplicateAndSave<NotificationDBISAR>(
          objects,
          collectionName,
          'notificationId',
          (n) => n.notificationId,
          (n) => n.createAt,
        );
        break;
      case ConfigDBISAR:
        collectionName = 'configDBISARs';
        await _deduplicateAndSave<ConfigDBISAR>(
          objects,
          collectionName,
          'd',
          (c) => c.d,
          (c) => c.time,
        );
        break;
      case WalletInfo:
        collectionName = 'walletInfos';
        await _deduplicateAndSave<WalletInfo>(
          objects,
          collectionName,
          'walletId',
          (w) => w.walletId,
          (w) => w.lastUpdated,
        );
        break;
      case WalletTransaction:
        collectionName = 'walletTransactions';
        await _deduplicateAndSave<WalletTransaction>(
          objects,
          collectionName,
          'transactionId',
          (t) => t.transactionId,
          (t) => t.createdAt,
        );
        break;
      case WalletInvoice:
        collectionName = 'walletInvoices';
        await _deduplicateAndSave<WalletInvoice>(
          objects,
          collectionName,
          'invoiceId',
          (i) => i.invoiceId,
          (i) => i.createdAt,
        );
        break;
      case FeedDraftDBISAR:
        collectionName = 'feedDraftDBISARs';
        await _deduplicateAndSave<FeedDraftDBISAR>(
          objects,
          collectionName,
          'author',
          (f) => f.author,
          (f) => f.updatedAt,
        );
        break;
      default:
        debugPrint('[DB-Web] ⚠️ Unknown type for IndexedDB: $type');
        return;
    }
    
    final collection = _indexedDB!.getCollection<dynamic>(collectionName);
    try {
      await collection.putAll(objects);
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
      if (_indexedDB != null) {
        if (_indexedDB!.isOpen) {
          await _indexedDB!.close();
        }
        _indexedDB = null; // Clear reference after closing
      }
    } else {
      if (_isar != null) {
        if (_isar!.isOpen) {
          await _isar!.close();
        }
        _isar = null; // Clear reference after closing
      }
    }
  }
}
