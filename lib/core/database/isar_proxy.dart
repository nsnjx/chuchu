import 'package:isar/isar.dart';
import 'isar_collection_adapter.dart';
import 'database_interface.dart';
import '../account/model/userDB_isar.dart';
import '../feed/model/noteDB_isar.dart';
import '../messages/model/messageDB_isar.dart';

/// Isar proxy class
/// Provides compatible Isar interface on web platform
class IsarProxy implements Isar {
  final Isar? _isar;
  final DatabaseInterface? _indexedDB;
  final bool _isWeb;
  final Map<String, dynamic> _collections = {};

  IsarProxy({
    Isar? isar,
    DatabaseInterface? indexedDB,
    required bool isWeb,
  })  : _isar = isar,
        _indexedDB = indexedDB,
        _isWeb = isWeb {
    // Initialize collection accessors
    if (_isWeb && _indexedDB != null) {
      _collections['userDBISARs'] = IsarCollectionAdapter<int, UserDBISAR>(
        indexedDBCollection: _indexedDB!.getCollection<UserDBISAR>('userDBISARs'),
        isWeb: true,
      );
      _collections['noteDBISARs'] = IsarCollectionAdapter<int, NoteDBISAR>(
        indexedDBCollection: _indexedDB!.getCollection<NoteDBISAR>('noteDBISARs'),
        isWeb: true,
      );
      _collections['messageDBISARs'] = IsarCollectionAdapter<int, MessageDBISAR>(
        indexedDBCollection: _indexedDB!.getCollection<MessageDBISAR>('messageDBISARs'),
        isWeb: true,
      );
      // Add other collections...
    }
  }

  // Collection accessors
  // Note: These getters return IsarCollectionAdapter, which implements IsarCollection
  // So generated extension methods shouldn't be called, as instance methods take priority
  // But if extension methods are called, they will call collection(), we need to handle it
  IsarCollection<int, UserDBISAR> get userDBISARs {
    if (_isWeb) {
      return _collections['userDBISARs'] as IsarCollection<int, UserDBISAR>;
    }
    return IsarCollectionAdapter<int, UserDBISAR>(
      isarCollection: _isar!.userDBISARs,
      isWeb: false,
    );
  }

  IsarCollection<int, NoteDBISAR> get noteDBISARs {
    if (_isWeb) {
      return _collections['noteDBISARs'] as IsarCollection<int, NoteDBISAR>;
    }
    return IsarCollectionAdapter<int, NoteDBISAR>(
      isarCollection: _isar!.noteDBISARs,
      isWeb: false,
    );
  }

  IsarCollection<int, MessageDBISAR> get messageDBISARs {
    if (_isWeb) {
      return _collections['messageDBISARs'] as IsarCollection<int, MessageDBISAR>;
    }
    return IsarCollectionAdapter<int, MessageDBISAR>(
      isarCollection: _isar!.messageDBISARs,
      isWeb: false,
    );
  }

  // Implement other required methods of Isar interface
  @override
  bool get isOpen => _isWeb ? (_indexedDB?.isOpen ?? false) : (_isar?.isOpen ?? false);

  @override
  T write<T>(T Function(Isar isar) callback) {
    if (_isWeb) {
      // Web platform needs async processing, but interface requires sync
      // Here we use sync approach, but actual execution is async
      T? result;
      _indexedDB!.writeSync((db) {
        result = callback(this);
      });
      return result as T;
    } else {
      return _isar!.write(callback);
    }
  }

  @override
  Future<T> readAsync<T>(T Function(Isar isar) callback, {String? debugName}) {
    if (_isWeb) {
      throw UnsupportedError('readAsync is not fully supported with IndexedDB');
    }
    return _isar!.readAsync(callback, debugName: debugName);
  }

  @override
  T read<T>(T Function(Isar isar) callback) {
    if (_isWeb) {
      throw UnsupportedError('read is not fully supported with IndexedDB');
    }
    return _isar!.read(callback);
  }

  @override
  bool close({bool deleteFromDisk = false}) {
    if (_isWeb) {
      // Web platform async close
      _indexedDB?.close();
      return true;
    } else {
      return _isar!.close(deleteFromDisk: deleteFromDisk);
    }
  }

  /// Get collection (Isar generated code will call this method)
  /// Note: Generated extension methods will call this.collection(), we need to return correct collection
  /// Due to type erasure, we cannot know OBJ type at runtime
  /// Solution: Find corresponding collection through type parameter OBJ
  @override
  IsarCollection<ID, OBJ> collection<ID, OBJ>() {
    if (_isWeb) {
      // Web platform: find corresponding collection through type parameter OBJ
      // Due to type erasure, we need to use type comparison
      final objType = OBJ;
      
      // Return corresponding collection based on type
      if (objType == UserDBISAR) {
        return _collections['userDBISARs'] as IsarCollection<ID, OBJ>;
      } else if (objType == NoteDBISAR) {
        return _collections['noteDBISARs'] as IsarCollection<ID, OBJ>;
      } else if (objType == MessageDBISAR) {
        return _collections['messageDBISARs'] as IsarCollection<ID, OBJ>;
      }
      // Can add other types...
      
      throw UnsupportedError('Collection for type $objType is not supported on web. Add it to IsarProxy.collection() method.');
    } else {
      return _isar!.collection<ID, OBJ>();
    }
  }

  // Other required method stubs
  @override
  dynamic noSuchMethod(Invocation invocation) {
    // For unimplemented methods, if it's a collection accessor, try to get from _collections
    final name = invocation.memberName.toString();
    // Remove "Symbol(" and ")" prefix and suffix
    final cleanName = name.replaceAll('Symbol("', '').replaceAll('")', '');
    if (invocation.isGetter && _collections.containsKey(cleanName)) {
      return _collections[cleanName];
    }
    if (!_isWeb && _isar != null) {
      return _isar!.noSuchMethod(invocation);
    }
    throw UnsupportedError('Method $cleanName is not supported');
  }
}
