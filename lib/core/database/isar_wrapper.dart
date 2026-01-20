import 'dart:async';
import 'package:isar/isar.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
// Conditional import: indexed_db_storage.dart only works on web (uses dart:html)
import 'indexed_db_storage.dart' if (dart.library.io) 'indexed_db_storage_stub.dart';
import 'database_interface.dart';

/// Isar wrapper
/// Uses IndexedDB on web platform, uses Isar on mobile platform
class IsarWrapper {
  Isar? _isar;
  DatabaseInterface? _indexedDB;
  bool _isWeb = false;

  bool get isOpen => _isWeb ? (_indexedDB?.isOpen ?? false) : (_isar?.isOpen ?? false);

  /// Open database
  Future<void> open({
    required List<IsarGeneratedSchema> schemas,
    required String name,
    required String directory,
    IsarEngine? engine,
  }) async {
    _isWeb = kIsWeb;

    if (_isWeb) {
      // Web platform uses IndexedDB
      debugPrint('🔵 [IsarWrapper] Using IndexedDB for web platform');
      _indexedDB = IndexedDBStorage();
      await _indexedDB!.open(name);
    } else {
      // Mobile platform uses Isar
      debugPrint('🔵 [IsarWrapper] Using Isar for native platform');
      _isar = await Isar.open(
        schemas: schemas,
        directory: directory,
        name: name,
        engine: engine ?? IsarEngine.isar,
      );
    }
  }

  /// Close database
  Future<void> close() async {
    if (_isWeb) {
      await _indexedDB?.close();
    } else {
      if (_isar?.isOpen ?? false) {
        await _isar!.close();
      }
    }
  }

  /// Write transaction
  Future<void> write(Future<void> Function(Isar isar) callback) async {
    if (_isWeb) {
      await _indexedDB!.write((db) async {
        // Create a fake Isar object for callback
        // Actually we need to directly operate IndexedDB
        await _executeWriteOperation(callback);
      });
    } else {
      await _isar!.write(callback);
    }
  }

  /// Sync write transaction (Note: Isar doesn't support sync operations on web)
  void writeSync(void Function(Isar isar) callback) {
    if (_isWeb) {
      // Web platform uses async version
      _indexedDB!.writeSync((db) {
        _executeWriteOperationSync(callback);
      });
    } else {
      // Mobile platform uses Isar's write method (sync execution)
      _isar!.write(callback);
    }
  }

  /// Execute write operation (web platform)
  Future<void> _executeWriteOperation(Future<void> Function(Isar isar) callback) async {
    // Here we need to intercept Isar operations and convert to IndexedDB operations
    // Since Isar's interface is complex, we need to handle it at DBISAR level
    // Leave empty for now, actual handling is in DBISAR
  }

  /// Execute sync write operation (web platform)
  void _executeWriteOperationSync(void Function(Isar isar) callback) {
    // Same as above
  }

  /// Get collection (through dynamic property access)
  dynamic getCollection(String collectionName) {
    if (_isWeb) {
      return _indexedDB!.getCollection(collectionName);
    } else {
      // Return Isar's collection accessor
      // Since Isar uses code generation, we need to access through reflection or mapping
      return _getIsarCollection(collectionName);
    }
  }

  /// Get Isar collection (by name)
  dynamic _getIsarCollection(String collectionName) {
    // Here we need to return corresponding Isar collection based on collection name
    // Since Isar uses code generation, we need to create a mapping
    // Temporarily return null, need to implement based on specific use case
    return null;
  }

  /// Direct access to Isar instance (for mobile platform)
  Isar? get isar => _isWeb ? null : _isar;

  /// Direct access to IndexedDB instance (for web platform)
  DatabaseInterface? get indexedDB => _isWeb ? _indexedDB : null;
}
