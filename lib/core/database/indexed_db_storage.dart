import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show debugPrint;
import 'database_interface.dart';
import '../account/model/userDB_isar.dart';
import '../account/model/relayDB_isar.dart';
import '../relayGroups/model/relayGroupDB_isar.dart';
import '../network/eventDB_isar.dart';
import '../feed/model/noteDB_isar.dart';
import '../wallet/model/wallet_info.dart';
import '../wallet/model/wallet_invoice.dart';
import '../wallet/model/wallet_transaction.dart';

/// Convert IndexedDB request to Future
Future<T> _requestToFuture<T>(dynamic request) {
  // Check if it's a Future (some dart:html methods directly return Future)
  if (request is Future) {
    return request as Future<T>;
  }
  
  // If it's an IdbRequest, use onSuccess/onError Stream
  final completer = Completer<T>();
  StreamSubscription? successSub;
  StreamSubscription? errorSub;
  
  try {
    // In dart:html, onSuccess and onError are Streams
    successSub = (request as dynamic).onSuccess.listen((dynamic e) {
      try {
        final result = (e.target as dynamic).result;
        if (!completer.isCompleted) {
          successSub?.cancel();
          errorSub?.cancel();
          completer.complete(result as T);
        }
      } catch (err) {
        if (!completer.isCompleted) {
          successSub?.cancel();
          errorSub?.cancel();
          completer.completeError(err);
        }
      }
    }, onError: (dynamic e) {
      if (!completer.isCompleted) {
        successSub?.cancel();
        errorSub?.cancel();
        completer.completeError(e);
      }
    });
    
    errorSub = (request as dynamic).onError.listen((dynamic e) {
      if (!completer.isCompleted) {
        successSub?.cancel();
        errorSub?.cancel();
        completer.completeError(e);
      }
    });
  } catch (e) {
    debugPrint('[DB-Web] ❌ _requestToFuture: Error setting up handlers: $e');
    successSub?.cancel();
    errorSub?.cancel();
    // If onSuccess/onError cannot be accessed, it might be a Future, return directly
    if (request is Future) {
      return request as Future<T>;
    }
    if (!completer.isCompleted) {
      completer.completeError(e);
    }
  }
  
  return completer.future;
}

/// IndexedDB storage implementation
class IndexedDBStorage implements DatabaseInterface {
  dynamic _idbFactory;
  dynamic _db;
  String? _dbName;
  final Map<String, int> _autoIncrementCounters = {};
  final Map<String, CollectionInterface<dynamic>> _collections = {};

  @override
  bool get isOpen => _db != null;
  
  /// Get the raw IndexedDB database object (for advanced operations)
  /// This is used internally for direct database access
  dynamic get rawDb => _db;
  
  /// Get the database name (for debugging)
  String? get dbName => _dbName;

  @override
  Future<void> open(String name) async {
    try {
      _dbName = 'isar_$name';
      _idbFactory = html.window.indexedDB;
      
      if (_idbFactory == null) {
        throw Exception('IndexedDB is not supported in this browser');
      }

      // Define all collection names
      final collectionNames = [
        'userDBISARs',
        'noteDBISARs',
        'messageDBISARs',
        'relayDBISARs',
        'zapRecordsDBISARs',
        'zapsDBISARs',
        'groupDBISARs',
        'joinRequestDBISARs',
        'moderationDBISARs',
        'relayGroupDBISARs',
        'notificationDBISARs',
        'configDBISARs',
        'eventDBISARs',
        'walletInfos',
        'walletTransactions',
        'walletInvoices',
        'feedDraftDBISARs',
      ];

      // Open or create database
      // In dart:html, open() returns a Future, need to await directly
      _db = await _idbFactory!.open(_dbName!, version: 1, onUpgradeNeeded: (dynamic e) {
        final db = (e.target as dynamic).result;
        
        // Create object store for each collection
        for (final collectionName in collectionNames) {
          if (!db.objectStoreNames.contains(collectionName)) {
            final store = db.createObjectStore(collectionName, keyPath: 'id', autoIncrement: false);
            // Create index (add as needed)
            store.createIndex('id', 'id', unique: true);
          }
        }
      });

      // Initialize auto-increment counters
      await _initializeAutoIncrementCounters();
      
    } catch (e) {
      debugPrint('[DB-Web] ❌ Failed to open database: $e');
      rethrow;
    }
  }

  /// Initialize auto-increment counters
  Future<void> _initializeAutoIncrementCounters() async {
    if (_db == null) return;

    final collectionNames = [
      'userDBISARs', 'noteDBISARs', 'messageDBISARs', 'relayDBISARs',
      'zapRecordsDBISARs', 'zapsDBISARs', 'groupDBISARs', 'joinRequestDBISARs',
      'moderationDBISARs', 'relayGroupDBISARs', 'notificationDBISARs',
      'configDBISARs', 'eventDBISARs', 'walletInfos', 'walletTransactions',
      'walletInvoices', 'feedDraftDBISARs',
    ];

    for (final collectionName in collectionNames) {
      final store = _db!.transaction(collectionName, 'readonly').objectStore(collectionName);
      // getAll() requires an optional key range parameter, pass null to get all
      final request = store.getAll(null);
      final allObjects = await _requestToFuture<List>(request);
      
      if (allObjects.isNotEmpty) {
        int maxId = 0;
        for (final obj in allObjects) {
          final id = (obj as Map)['id'] as int?;
          if (id != null && id > maxId) {
            maxId = id;
          }
        }
        _autoIncrementCounters[collectionName] = maxId;
      } else {
        _autoIncrementCounters[collectionName] = 0;
      }
    }
  }

  @override
  Future<void> close() async {
    if (_db != null) {
      _db!.close();
      _db = null;
      debugPrint('[DB-Web] 🔵 Database closed');
    }
  }

  @override
  Future<void> write(Future<void> Function(DatabaseInterface db) callback) async {
    if (_db == null) throw Exception('Database is not open');
    await callback(this);
  }

  @override
  void writeSync(void Function(DatabaseInterface db) callback) {
    if (_db == null) throw Exception('Database is not open');
    callback(this);
  }

  @override
  CollectionInterface<T> getCollection<T>(String collectionName) {
    if (_collections.containsKey(collectionName)) {
      return _collections[collectionName] as CollectionInterface<T>;
    }
    
    final collection = IndexedDBCollection<T>(_db!, collectionName, _autoIncrementCounters);
    _collections[collectionName] = collection as CollectionInterface<dynamic>;
    return collection;
  }
}

/// IndexedDB collection implementation
class IndexedDBCollection<T> implements CollectionInterface<T> {
  final dynamic _db;
  final String _collectionName;
  final Map<String, int> _autoIncrementCounters;

  IndexedDBCollection(this._db, this._collectionName, this._autoIncrementCounters);

  @override
  Future<T?> get(int id) async {
    try {
      final transaction = _db.transaction(_collectionName, 'readonly');
      final store = transaction.objectStore(_collectionName);
      final request = store.getObject(id);
      final result = await _requestToFuture<dynamic>(request);
      
      if (result == null) return null;
      // Convert LinkedMap to Map<String, dynamic>
      final map = _convertToMapStringDynamic(result);
      return _deserialize(map);
    } catch (e) {
      debugPrint('[DB-Web] ❌ Error getting object: $e');
      return null;
    }
  }

  @override
  Future<List<T?>> getAll(List<int> ids) async {
    final results = <T?>[];
    for (final id in ids) {
      results.add(await get(id));
    }
    return results;
  }

  @override
  Future<void> put(T object) async {
    await putAll([object]);
  }

  @override
  Future<void> putAll(List<T> objects) async {
    if (objects.isEmpty) return;

    try {
      final transaction = _db.transaction(_collectionName, 'readwrite');
      final store = transaction.objectStore(_collectionName);

      final List<Future<void>> putFutures = [];
      for (int i = 0; i < objects.length; i++) {
        final object = objects[i];
        final map = _serialize(object);
        // Handle auto-increment ID
        final dynamic objDynamic = object;
        if (objDynamic.id == 0) {
          final newId = autoIncrement();
          map['id'] = newId;
          objDynamic.id = newId;
        }
        
        // store.put() returns an IdbRequest, need to convert to Future
        final putRequest = store.put(map);
        putFutures.add(_requestToFuture<void>(putRequest));
      }
      
      // Wait for all put operations to complete, add timeout handling
      try {
        await Future.wait(putFutures).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('[DB-Web] ❌ putAll: Timeout waiting for put operations to complete');
            throw TimeoutException('putAll operation timed out after 10 seconds');
          },
        );
      } catch (e) {
        debugPrint('[DB-Web] ❌ putAll: Error waiting for put operations: $e');
        rethrow;
      }
    } catch (e, stackTrace) {
      debugPrint('[DB-Web] ❌ Error putting objects: $e');
      debugPrint('[DB-Web] ❌ Stack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<bool> delete(int id) async {
    try {
      final transaction = _db.transaction(_collectionName, 'readwrite');
      final store = transaction.objectStore(_collectionName);
      await _requestToFuture<void>(store.delete(id));
      return true;
    } catch (e) {
      debugPrint('[DB-Web] ❌ Error deleting object: $e');
      return false;
    }
  }

  @override
  Future<int> deleteAll(List<int> ids) async {
    int count = 0;
    for (final id in ids) {
      if (await delete(id)) {
        count++;
      }
    }
    return count;
  }

  @override
  Future<void> clear() async {
    try {
      final transaction = _db.transaction(_collectionName, 'readwrite');
      final store = transaction.objectStore(_collectionName);
      await _requestToFuture<void>(store.clear());
      _autoIncrementCounters[_collectionName] = 0;
    } catch (e) {
      debugPrint('[DB-Web] ❌ Error clearing collection: $e');
      rethrow;
    }
  }

  @override
  int autoIncrement() {
    final current = _autoIncrementCounters[_collectionName] ?? 0;
    _autoIncrementCounters[_collectionName] = current + 1;
    return current + 1;
  }

  @override
  QueryBuilderInterface<T> where() {
    return IndexedDBQueryBuilder<T>(_db, _collectionName, this);
  }

  @override
  QueryBuilderInterface<T> filter() {
    return IndexedDBQueryBuilder<T>(_db, _collectionName, this);
  }

  /// Serialize object to Map
  Map<String, dynamic> _serialize(T object) {
    // Use dynamic to access object fields and manually build Map
    try {
      final dynamic obj = object;
      final map = <String, dynamic>{};
      
      // Directly access fields (using dynamic's noSuchMethod)
      // This triggers the object's noSuchMethod if the object supports dynamic access
      try {
        map['id'] = obj.id;
      } catch (e) {}
      
      // Use try-catch to safely access fields
      // Only add existing fields
      _tryAddField(map, obj, 'id');
      _tryAddField(map, obj, 'pubKey');
      _tryAddField(map, obj, 'privkey');
      _tryAddField(map, obj, 'name');
      _tryAddField(map, obj, 'nickName');
      _tryAddField(map, obj, 'mainRelay');
      _tryAddField(map, obj, 'dns');
      _tryAddField(map, obj, 'lnurl');
      _tryAddField(map, obj, 'badges');
      _tryAddField(map, obj, 'gender');
      _tryAddField(map, obj, 'area');
      _tryAddField(map, obj, 'about');
      _tryAddField(map, obj, 'picture');
      _tryAddField(map, obj, 'banner');
      _tryAddField(map, obj, 'aliasPubkey');
      _tryAddField(map, obj, 'toAliasPubkey');
      _tryAddField(map, obj, 'toAliasPrivkey');
      _tryAddField(map, obj, 'friendsList');
      _tryAddField(map, obj, 'channelsList');
      _tryAddField(map, obj, 'groupsList');
      _tryAddField(map, obj, 'relayGroupsList');
      _tryAddField(map, obj, 'badgesList');
      _tryAddField(map, obj, 'blockedList');
      _tryAddField(map, obj, 'blockedHashTags');
      _tryAddField(map, obj, 'blockedWords');
      _tryAddField(map, obj, 'blockedThreads');
      _tryAddField(map, obj, 'followingList');
      _tryAddField(map, obj, 'followersList');
      _tryAddField(map, obj, 'relayList');
      _tryAddField(map, obj, 'dmRelayList');
      _tryAddField(map, obj, 'inboxRelayList');
      _tryAddField(map, obj, 'outboxRelayList');
      _tryAddField(map, obj, 'lastFriendsListUpdatedTime');
      _tryAddField(map, obj, 'lastChannelsListUpdatedTime');
      _tryAddField(map, obj, 'lastGroupsListUpdatedTime');
      _tryAddField(map, obj, 'lastRelayGroupsListUpdatedTime');
      _tryAddField(map, obj, 'lastBadgesListUpdatedTime');
      _tryAddField(map, obj, 'lastBlockListUpdatedTime');
      _tryAddField(map, obj, 'lastRelayListUpdatedTime');
      _tryAddField(map, obj, 'lastFollowingListUpdatedTime');
      _tryAddField(map, obj, 'lastDMRelayListUpdatedTime');
      _tryAddField(map, obj, 'mute');
      _tryAddField(map, obj, 'lastUpdatedTime');
      _tryAddField(map, obj, 'otherField');
      _tryAddField(map, obj, 'nwcURI');
      
      // Try to add other possible fields (for other model types)
      _tryAddField(map, obj, 'noteId');
      _tryAddField(map, obj, 'groupId');
      _tryAddField(map, obj, 'author');
      _tryAddField(map, obj, 'createAt');
      _tryAddField(map, obj, 'content');
      _tryAddField(map, obj, 'root');
      _tryAddField(map, obj, 'rootRelay');
      _tryAddField(map, obj, 'reply');
      _tryAddField(map, obj, 'replyRelay');
      _tryAddField(map, obj, 'mentions');
      _tryAddField(map, obj, 'pTags');
      _tryAddField(map, obj, 'hashTags');
      _tryAddField(map, obj, 'private');
      _tryAddField(map, obj, 'read');
      _tryAddField(map, obj, 'warning');
      _tryAddField(map, obj, 'repostId');
      _tryAddField(map, obj, 'quoteRepostId');
      _tryAddField(map, obj, 'messageId');
      _tryAddField(map, obj, 'sender');
      _tryAddField(map, obj, 'receiver');
      _tryAddField(map, obj, 'sessionId');
      _tryAddField(map, obj, 'type');
      _tryAddField(map, obj, 'decryptContent');
      _tryAddField(map, obj, 'reactionEventIds');
      _tryAddField(map, obj, 'zapEventIds');
      _tryAddField(map, obj, 'findEvent');
      _tryAddField(map, obj, 'relay');
      _tryAddField(map, obj, 'url');
      _tryAddField(map, obj, 'readWrite');
      _tryAddField(map, obj, 'invoiceId');
      _tryAddField(map, obj, 'transactionId');
      _tryAddField(map, obj, 'amount');
      _tryAddField(map, obj, 'status');
      _tryAddField(map, obj, 'timestamp');
      _tryAddField(map, obj, 'description');
      _tryAddField(map, obj, 'eventId');
      _tryAddField(map, obj, 'kind');
      _tryAddField(map, obj, 'groupName');
      _tryAddField(map, obj, 'groupDescription');
      _tryAddField(map, obj, 'groupPicture');
      _tryAddField(map, obj, 'requestId');
      _tryAddField(map, obj, 'moderatorPubkey');
      _tryAddField(map, obj, 'action');
      _tryAddField(map, obj, 'reason');
      _tryAddField(map, obj, 'imageUrls');
      _tryAddField(map, obj, 'videoUrls');
      _tryAddField(map, obj, 'draftCueUserMapJson');
      _tryAddField(map, obj, 'updatedAt');
      
      return map;
    } catch (e) {
      debugPrint('[DB-Web] ❌ Error serializing object: $e');
      // Last fallback: only save id
      final dynamic obj = object;
      return {'id': obj.id ?? 0};
    }
  }

  /// Try to add field to Map
  void _tryAddField(Map<String, dynamic> map, dynamic obj, String fieldName) {
    try {
      // Use noSuchMethod to dynamically access fields
      // Access fields by creating an Invocation
      final value = _getFieldValue(obj, fieldName);
      if (value != null) {
        map[fieldName] = _serializeValue(value);
      }
    } catch (e) {
      // Field doesn't exist or cannot be accessed, ignore
    }
  }

  /// Get object field value
  dynamic _getFieldValue(dynamic obj, String fieldName) {
    // Use dynamic call, let Dart's noSuchMethod handle it
    // This requires the object to support dynamic field access
    try {
      // Try direct access (if field is public)
      switch (fieldName) {
        case 'id': return obj.id;
        case 'pubKey': return obj.pubKey;
        case 'privkey': return obj.privkey;
        case 'name': return obj.name;
        case 'nickName': return obj.nickName;
        case 'mainRelay': return obj.mainRelay;
        case 'dns': return obj.dns;
        case 'lnurl': return obj.lnurl;
        case 'badges': return obj.badges;
        case 'gender': return obj.gender;
        case 'area': return obj.area;
        case 'about': return obj.about;
        case 'picture': return obj.picture;
        case 'banner': return obj.banner;
        case 'aliasPubkey': return obj.aliasPubkey;
        case 'toAliasPubkey': return obj.toAliasPubkey;
        case 'toAliasPrivkey': return obj.toAliasPrivkey;
        case 'friendsList': return obj.friendsList;
        case 'channelsList': return obj.channelsList;
        case 'groupsList': return obj.groupsList;
        case 'relayGroupsList': return obj.relayGroupsList;
        case 'badgesList': return obj.badgesList;
        case 'blockedList': return obj.blockedList;
        case 'blockedHashTags': return obj.blockedHashTags;
        case 'blockedWords': return obj.blockedWords;
        case 'blockedThreads': return obj.blockedThreads;
        case 'followingList': return obj.followingList;
        case 'followersList': return obj.followersList;
        case 'relayList': return obj.relayList;
        case 'dmRelayList': return obj.dmRelayList;
        case 'inboxRelayList': return obj.inboxRelayList;
        case 'outboxRelayList': return obj.outboxRelayList;
        case 'lastFriendsListUpdatedTime': return obj.lastFriendsListUpdatedTime;
        case 'lastChannelsListUpdatedTime': return obj.lastChannelsListUpdatedTime;
        case 'lastGroupsListUpdatedTime': return obj.lastGroupsListUpdatedTime;
        case 'lastRelayGroupsListUpdatedTime': return obj.lastRelayGroupsListUpdatedTime;
        case 'lastBadgesListUpdatedTime': return obj.lastBadgesListUpdatedTime;
        case 'lastBlockListUpdatedTime': return obj.lastBlockListUpdatedTime;
        case 'lastRelayListUpdatedTime': return obj.lastRelayListUpdatedTime;
        case 'lastFollowingListUpdatedTime': return obj.lastFollowingListUpdatedTime;
        case 'lastDMRelayListUpdatedTime': return obj.lastDMRelayListUpdatedTime;
        case 'mute': return obj.mute;
        case 'lastUpdatedTime': return obj.lastUpdatedTime;
        case 'otherField': return obj.otherField;
        case 'nwcURI': return obj.nwcURI;
        case 'noteId': return obj.noteId;
        case 'groupId': return obj.groupId;
        case 'author': return obj.author;
        case 'createAt': return obj.createAt;
        case 'content': return obj.content;
        case 'root': return obj.root;
        case 'rootRelay': return obj.rootRelay;
        case 'reply': return obj.reply;
        case 'replyRelay': return obj.replyRelay;
        case 'mentions': return obj.mentions;
        case 'pTags': return obj.pTags;
        case 'hashTags': return obj.hashTags;
        case 'private': return obj.private;
        case 'read': return obj.read;
        case 'warning': return obj.warning;
        case 'repostId': return obj.repostId;
        case 'quoteRepostId': return obj.quoteRepostId;
        case 'messageId': return obj.messageId;
        case 'sender': return obj.sender;
        case 'receiver': return obj.receiver;
        case 'sessionId': return obj.sessionId;
        case 'type': return obj.type;
        case 'decryptContent': return obj.decryptContent;
        case 'reactionEventIds': return obj.reactionEventIds;
        case 'zapEventIds': return obj.zapEventIds;
        case 'findEvent': return obj.findEvent;
        case 'relay': return obj.relay;
        case 'url': return obj.url;
        case 'readWrite': return obj.readWrite;
        case 'invoiceId': return obj.invoiceId;
        case 'transactionId': return obj.transactionId;
        case 'amount': return obj.amount;
        case 'status': return obj.status;
        case 'timestamp': return obj.timestamp;
        case 'description': return obj.description;
        case 'eventId': return obj.eventId;
        case 'kind': return obj.kind;
        case 'groupName': return obj.groupName;
        case 'groupDescription': return obj.groupDescription;
        case 'groupPicture': return obj.groupPicture;
        case 'requestId': return obj.requestId;
        case 'moderatorPubkey': return obj.moderatorPubkey;
        case 'action': return obj.action;
        case 'reason': return obj.reason;
        case 'imageUrls': return obj.imageUrls;
        case 'videoUrls': return obj.videoUrls;
        case 'draftCueUserMapJson': return obj.draftCueUserMapJson;
        case 'updatedAt': return obj.updatedAt;
        default: return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Serialize value
  dynamic _serializeValue(dynamic value) {
    if (value == null) return null;
    if (value is String || value is int || value is double || value is bool) {
      return value;
    }
    if (value is List) {
      return value.map((e) => _serializeValue(e)).toList();
    }
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _serializeValue(v)));
    }
    // For other objects, try to convert to string
    return value.toString();
  }

  /// Deserialize Map to object
  T _deserialize(Map<String, dynamic> map) {
    return IndexedDBCollection._deserializeFromMap<T>(map, _collectionName);
  }
  
  /// Convert LinkedMap<dynamic, dynamic>, IdentityMap or other Map types to Map<String, dynamic>
  Map<String, dynamic> _convertToMapStringDynamic(dynamic obj) {
    if (obj is Map<String, dynamic>) {
      return obj;
    }
    if (obj is Map) {
      // Convert LinkedMap<dynamic, dynamic>, IdentityMap<String, dynamic> or other Map types
      final result = <String, dynamic>{};
      obj.forEach((key, value) {
        // Recursively process nested Maps and Lists
        result[key.toString()] = _convertValue(value);
      });
      return result;
    }
    // If not a Map, throw exception
    throw Exception('Expected Map, got ${obj.runtimeType}');
  }
  
  /// Recursively convert value (handle nested Maps and Lists)
  dynamic _convertValue(dynamic value) {
    if (value is Map) {
      // Recursively convert nested Map
      final result = <String, dynamic>{};
      value.forEach((key, val) {
        result[key.toString()] = _convertValue(val);
      });
      return result;
    } else if (value is List) {
      // Recursively convert elements in List
      return value.map((item) => _convertValue(item)).toList();
    }
    return value;
  }
  
  /// Static recursive convert value (handle nested Maps and Lists)
  static dynamic _convertValueStatic(dynamic value) {
    if (value is Map) {
      // Recursively convert nested Map (including IdentityMap and LinkedMap)
      final result = <String, dynamic>{};
      value.forEach((key, val) {
        result[key.toString()] = _convertValueStatic(val);
      });
      return result;
    } else if (value is List) {
      // Recursively convert elements in List
      return value.map((item) => _convertValueStatic(item)).toList();
    }
    return value;
  }
  
  /// Static deserialization method (for QueryBuilder)
  /// Note: Due to Dart's type erasure, T == SomeType won't work at runtime
  /// We need to determine type based on collectionName
  static T _deserializeFromMap<T>(Map<String, dynamic> map, [String? collectionName]) {
    try {
      // Ensure map is a real Map<String, dynamic>, not IdentityMap or other types
      // Check runtime type, if it's IdentityMap or other Map types, need to convert
      Map<String, dynamic> convertedMap;
      final runtimeType = map.runtimeType.toString();
      if (runtimeType.contains('IdentityMap') || runtimeType.contains('LinkedMap')) {
        // If map is IdentityMap or LinkedMap, convert to Map<String, dynamic>
        // Use recursive conversion to ensure nested Maps and Lists are also converted
        convertedMap = <String, dynamic>{};
        map.forEach((key, value) {
          // Recursively convert value, handle nested Maps and Lists
          convertedMap[key.toString()] = _convertValueStatic(value);
        });
      } else {
        // Even if not IdentityMap, it may contain nested IdentityMap, need recursive conversion
        convertedMap = <String, dynamic>{};
        map.forEach((key, value) {
          convertedMap[key.toString()] = _convertValueStatic(value);
        });
      }
      
      // Determine type based on collectionName (if provided)
      if (collectionName != null) {
        switch (collectionName) {
          case 'userDBISARs':
            return UserDBISAR.fromMap(convertedMap) as T;
          case 'relayDBISARs':
            return RelayDBISAR.fromMap(convertedMap) as T;
          case 'relayGroupDBISARs':
            return RelayGroupDBISAR.fromMap(convertedMap) as T;
          case 'eventDBISARs':
            return EventDBISAR.fromMap(convertedMap) as T;
          case 'noteDBISARs':
            try {
              debugPrint('[DB-Web] 🔵 Calling NoteDBISAR.fromMap, map keys: ${convertedMap.keys.take(10).toList()}');
              final note = NoteDBISAR.fromMap(convertedMap);
              debugPrint('[DB-Web] 🔵 NoteDBISAR.fromMap succeeded');
              return note as T;
            } catch (e, stackTrace) {
              debugPrint('[DB-Web] ❌ NoteDBISAR.fromMap failed: $e');
              debugPrint('[DB-Web] ❌ Map keys: ${convertedMap.keys.toList()}');
              debugPrint('[DB-Web] ❌ Stack trace: $stackTrace');
              rethrow;
            }
          case 'walletInfos':
            return WalletInfo.fromJson(convertedMap) as T;
          case 'walletInvoices':
            return WalletInvoice.fromJson(convertedMap) as T;
          case 'walletTransactions':
            return WalletTransaction.fromJson(convertedMap) as T;
          default:
            break;
        }
      }
      
      // Try to use fromMap factory method (may not work after type erasure, but try)
      // Note: Due to type erasure, these checks may not work at runtime
      // But we can try calling fromMap/fromJson, fallback if it fails
      try {
        // Try UserDBISAR
        final user = UserDBISAR.fromMap(convertedMap);
        return user as T;
      } catch (_) {}
      
      try {
        // Try RelayDBISAR
        final relay = RelayDBISAR.fromMap(convertedMap);
        return relay as T;
      } catch (_) {}
      
      try {
        // Try RelayGroupDBISAR
        final group = RelayGroupDBISAR.fromMap(convertedMap);
        return group as T;
      } catch (_) {}
      
      try {
        // Try EventDBISAR
        final event = EventDBISAR.fromMap(convertedMap);
        return event as T;
      } catch (_) {}
      
      try {
        // Try NoteDBISAR
        final note = NoteDBISAR.fromMap(convertedMap);
        return note as T;
      } catch (_) {}
      
      try {
        // Try WalletInfo
        final wallet = WalletInfo.fromJson(convertedMap);
        return wallet as T;
      } catch (_) {}
      
      try {
        // Try WalletInvoice
        final invoice = WalletInvoice.fromJson(convertedMap);
        return invoice as T;
      } catch (_) {}
      
      try {
        // Try WalletTransaction
        final transaction = WalletTransaction.fromJson(convertedMap);
        return transaction as T;
      } catch (_) {}
      
      // If no fromMap, try to directly create object and set fields
      return _createObjectFromMapStatic<T>(convertedMap);
    } catch (e) {
      debugPrint('❌ [IndexedDB] Error deserializing object: $e');
      // Last fallback: return map (this will cause type error, but at least won't crash)
      return map as T;
    }
  }
  
  /// Static object creation method (for QueryBuilder)
  static T _createObjectFromMapStatic<T>(Map<String, dynamic> map) {
    try {
      // Use type-specific creation method
      if (T == UserDBISAR) {
        return _createUserDBISARFromMapStatic(map) as T;
      }
      // Can add creation methods for other types
      
      // If none match, return map (will cause type error)
      return map as T;
    } catch (e) {
      debugPrint('❌ [IndexedDB] Error creating object from map: $e');
      return map as T;
    }
  }
  
  /// Static create UserDBISAR (for QueryBuilder)
  static UserDBISAR _createUserDBISARFromMapStatic(Map<String, dynamic> map) {
    return UserDBISAR(
      pubKey: map['pubKey']?.toString() ?? '',
      privkey: map['privkey']?.toString(),
      name: map['name']?.toString(),
      nickName: map['nickName']?.toString(),
      mainRelay: map['mainRelay']?.toString(),
      dns: map['dns']?.toString(),
      lnurl: map['lnurl']?.toString(),
      badges: map['badges']?.toString(),
      gender: map['gender']?.toString(),
      area: map['area']?.toString(),
      about: map['about']?.toString(),
      picture: map['picture']?.toString(),
      banner: map['banner']?.toString(),
      aliasPubkey: map['aliasPubkey']?.toString(),
      toAliasPubkey: map['toAliasPubkey']?.toString(),
      toAliasPrivkey: map['toAliasPrivkey']?.toString(),
      friendsList: map['friendsList']?.toString(),
      channelsList: (map['channelsList'] as List?)?.cast<String>(),
      groupsList: (map['groupsList'] as List?)?.cast<String>(),
      relayGroupsList: (map['relayGroupsList'] as List?)?.cast<String>(),
      badgesList: (map['badgesList'] as List?)?.cast<String>(),
      blockedList: (map['blockedList'] as List?)?.cast<String>(),
      blockedHashTags: (map['blockedHashTags'] as List?)?.cast<String>(),
      blockedWords: (map['blockedWords'] as List?)?.cast<String>(),
      blockedThreads: (map['blockedThreads'] as List?)?.cast<String>(),
      followingList: (map['followingList'] as List?)?.cast<String>(),
      followersList: (map['followersList'] as List?)?.cast<String>(),
      relayList: (map['relayList'] as List?)?.cast<String>(),
      dmRelayList: (map['dmRelayList'] as List?)?.cast<String>(),
      inboxRelayList: (map['inboxRelayList'] as List?)?.cast<String>(),
      outboxRelayList: (map['outboxRelayList'] as List?)?.cast<String>(),
      lastFriendsListUpdatedTime: map['lastFriendsListUpdatedTime'] as int? ?? 0,
      lastChannelsListUpdatedTime: map['lastChannelsListUpdatedTime'] as int? ?? 0,
      lastGroupsListUpdatedTime: map['lastGroupsListUpdatedTime'] as int? ?? 0,
      lastRelayGroupsListUpdatedTime: map['lastRelayGroupsListUpdatedTime'] as int? ?? 0,
      lastBadgesListUpdatedTime: map['lastBadgesListUpdatedTime'] as int? ?? 0,
      lastBlockListUpdatedTime: map['lastBlockListUpdatedTime'] as int? ?? 0,
      lastRelayListUpdatedTime: map['lastRelayListUpdatedTime'] as int? ?? 0,
      lastFollowingListUpdatedTime: map['lastFollowingListUpdatedTime'] as int? ?? 0,
      lastDMRelayListUpdatedTime: map['lastDMRelayListUpdatedTime'] as int? ?? 0,
      mute: map['mute'] as bool?,
      lastUpdatedTime: map['lastUpdatedTime'] as int? ?? 0,
      otherField: map['otherField']?.toString(),
      nwcURI: map['nwcURI']?.toString(),
    )..id = map['id'] as int? ?? 0;
  }
}

/// IndexedDB query builder implementation
class IndexedDBQueryBuilder<T> implements QueryBuilderInterface<T> {
  final dynamic _db;
  final String _collectionName;
  final List<QueryCondition> _conditions = [];
  /// OR groups: each group is a list of conditions (ANDed within group); results from each group are unioned with main AND result.
  final List<List<QueryCondition>> _orGroups = [];
  final IndexedDBCollection<T>? _collection; // Reference to collection for deserialization

  IndexedDBQueryBuilder(this._db, this._collectionName, [this._collection]);

  @override
  Future<List<T>> findAll({int? limit, int? offset}) async {
    try {
      final transaction = _db.transaction(_collectionName, 'readonly');
      final store = transaction.objectStore(_collectionName);
      // getAll() requires an optional key range parameter, pass null to get all
      final request = store.getAll(null);
      final allObjects = await _requestToFuture<List>(request);

      // Convert to List<Map<String, dynamic>>
      final allMaps = allObjects.map((obj) => _convertToMapStringDynamic(obj)).toList();

      // Apply AND conditions first
      List<Map<String, dynamic>> filtered = allMaps;
      for (final condition in _conditions) {
        filtered = _applyCondition(filtered, condition);
      }

      // Union with each OR group: (main result) ∪ (data matching group1) ∪ (data matching group2) ...
      if (_orGroups.isNotEmpty) {
        final seenIds = <dynamic>{};
        for (final map in filtered) {
          final id = map['id'];
          if (id != null) seenIds.add(id);
        }
        for (final group in _orGroups) {
          List<Map<String, dynamic>> subset = allMaps;
          for (final condition in group) {
            subset = _applyCondition(subset, condition);
          }
          for (final map in subset) {
            final id = map['id'];
            if (id != null && !seenIds.contains(id)) {
              seenIds.add(id);
              filtered.add(map);
            }
          }
        }
      }

      // Apply offset and limit
      if (offset != null && offset > 0) {
        filtered = filtered.skip(offset).toList();
      }
      if (limit != null && limit > 0) {
        filtered = filtered.take(limit).toList();
      }

      // Convert to object list - use collection's _deserialize method
      List<T> result = [];
      if (_collection != null) {
        for (var map in filtered) {
          try {
            result.add(_collection._deserialize(map));
          } catch (e) {
            debugPrint('[DB-Web] ❌ Error deserializing item in findAll with collection: $e');
            // Don't rethrow, continue processing other objects
          }
        }
      } else {
        // If no collection reference, try direct deserialization (pass collectionName)
        for (var map in filtered) {
          try {
            result.add(IndexedDBCollection._deserializeFromMap<T>(map, _collectionName));
          } catch (e) {
            debugPrint('[DB-Web] ❌ Error deserializing item in findAll without collection: $e');
            // Don't rethrow, continue processing other objects
          }
        }
      }
      return result;
    } catch (e, stackTrace) {
      debugPrint('[DB-Web] ❌ Error in findAll: $e');
      debugPrint('[DB-Web] ❌ Stack trace: $stackTrace');
      return [];
    }
  }
  
  /// Convert LinkedMap<dynamic, dynamic>, IdentityMap or other Map types to Map<String, dynamic>
  Map<String, dynamic> _convertToMapStringDynamic(dynamic obj) {
    if (obj is Map<String, dynamic>) {
      return obj;
    }
    if (obj is Map) {
      // Convert LinkedMap<dynamic, dynamic>, IdentityMap<String, dynamic> or other Map types
      final result = <String, dynamic>{};
      obj.forEach((key, value) {
        // Recursively process nested Maps and Lists
        result[key.toString()] = _convertValue(value);
      });
      return result;
    }
    // If not a Map, throw exception
    throw Exception('Expected Map, got ${obj.runtimeType}');
  }
  
  /// Recursively convert value (handle nested Maps and Lists)
  dynamic _convertValue(dynamic value) {
    if (value is Map) {
      // Recursively convert nested Map
      final result = <String, dynamic>{};
      value.forEach((key, val) {
        result[key.toString()] = _convertValue(val);
      });
      return result;
    } else if (value is List) {
      // Recursively convert elements in List
      return value.map((item) => _convertValue(item)).toList();
    }
    return value;
  }

  @override
  Future<T?> findFirst() async {
    final results = await findAll(limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  @override
  Future<T?> findLast() async {
    final results = await findAll();
    return results.isNotEmpty ? results.last : null;
  }

  @override
  Future<int> count() async {
    final results = await findAll();
    return results.length;
  }

  @override
  QueryBuilderInterface<T> equalTo(String property, dynamic value) {
    _conditions.add(QueryCondition(
      type: QueryConditionType.equalTo,
      property: property,
      value: value,
    ));
    return this;
  }

  @override
  QueryBuilderInterface<T> notEqualTo(String property, dynamic value) {
    _conditions.add(QueryCondition(
      type: QueryConditionType.notEqualTo,
      property: property,
      value: value,
    ));
    return this;
  }

  @override
  QueryBuilderInterface<T> contains(String property, String value, {bool caseSensitive = true}) {
    _conditions.add(QueryCondition(
      type: QueryConditionType.contains,
      property: property,
      value: value,
      caseSensitive: caseSensitive,
    ));
    return this;
  }

  @override
  QueryBuilderInterface<T> elementEqualTo(String property, dynamic value) {
    _conditions.add(QueryCondition(
      type: QueryConditionType.elementEqualTo,
      property: property,
      value: value,
    ));
    return this;
  }

  @override
  QueryBuilderInterface<T> isEmpty(String property) {
    _conditions.add(QueryCondition(
      type: QueryConditionType.isEmpty,
      property: property,
    ));
    return this;
  }

  @override
  QueryBuilderInterface<T> isNotEmpty(String property) {
    _conditions.add(QueryCondition(
      type: QueryConditionType.isNotEmpty,
      property: property,
    ));
    return this;
  }

  @override
  QueryBuilderInterface<T> anyOf(String property, List<dynamic> values) {
    _conditions.add(QueryCondition(
      type: QueryConditionType.anyOf,
      property: property,
      values: values,
    ));
    return this;
  }

  @override
  QueryBuilderInterface<T> and(QueryBuilderInterface<T> Function(QueryBuilderInterface<T>) builder) {
    final child = IndexedDBQueryBuilder<T>(_db, _collectionName, _collection);
    builder(child);
    _conditions.addAll(child._conditions);
    return this;
  }

  @override
  QueryBuilderInterface<T> or(QueryBuilderInterface<T> Function(QueryBuilderInterface<T>) builder) {
    final child = createChildBuilder() as IndexedDBQueryBuilder<T>;
    builder(child);
    addOrGroupFromChild(child);
    return this;
  }

  @override
  QueryBuilderInterface<T> createChildBuilder() {
    return IndexedDBQueryBuilder<T>(_db, _collectionName, _collection);
  }

  @override
  void addOrGroupFromChild(QueryBuilderInterface<T> child) {
    if (child is IndexedDBQueryBuilder<T>) {
      _orGroups.add(List<QueryCondition>.from(child._conditions));
    }
  }

  /// Apply query conditions
  List<Map<String, dynamic>> _applyCondition(List<Map<String, dynamic>> data, QueryCondition condition) {
    switch (condition.type) {
      case QueryConditionType.equalTo:
        return data.where((item) {
          final value = item[condition.property];
          return value == condition.value;
        }).toList();
      
      case QueryConditionType.notEqualTo:
        return data.where((item) {
          final value = item[condition.property];
          return value != condition.value;
        }).toList();
      
      case QueryConditionType.contains:
        return data.where((item) {
          final value = item[condition.property];
          if (value is! String) return false;
          final searchValue = condition.value as String;
          if (condition.caseSensitive ?? true) {
            return value.contains(searchValue);
          } else {
            return value.toLowerCase().contains(searchValue.toLowerCase());
          }
        }).toList();
      
      case QueryConditionType.elementEqualTo:
        return data.where((item) {
          final value = item[condition.property];
          if (value is List) {
            return value.contains(condition.value);
          }
          return false;
        }).toList();
      
      case QueryConditionType.isEmpty:
        return data.where((item) {
          final value = item[condition.property];
          return value == null || 
                 (value is String && value.isEmpty) ||
                 (value is List && value.isEmpty);
        }).toList();
      
      case QueryConditionType.isNotEmpty:
        return data.where((item) {
          final value = item[condition.property];
          return value != null && 
                 !(value is String && value.isEmpty) &&
                 !(value is List && value.isEmpty);
        }).toList();
      
      case QueryConditionType.anyOf:
        return data.where((item) {
          final value = item[condition.property];
          return condition.values?.contains(value) ?? false;
        }).toList();
    }
  }
}

/// Query condition type
enum QueryConditionType {
  equalTo,
  notEqualTo,
  contains,
  elementEqualTo,
  isEmpty,
  isNotEmpty,
  anyOf,
}

/// Query condition
class QueryCondition {
  final QueryConditionType type;
  final String property;
  final dynamic value;
  final List<dynamic>? values;
  final bool? caseSensitive;

  QueryCondition({
    required this.type,
    required this.property,
    this.value,
    this.values,
    this.caseSensitive,
  });
}
