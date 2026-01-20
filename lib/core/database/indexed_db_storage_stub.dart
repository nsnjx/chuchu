// Stub file for mobile platforms (iOS/Android)
// This file is used when dart:html is not available

import 'dart:async';
import 'database_interface.dart';

/// Stub implementation of IndexedDBStorage for mobile platforms
/// This class should never be instantiated on mobile platforms
class IndexedDBStorage implements DatabaseInterface {
  IndexedDBStorage() {
    throw UnsupportedError('IndexedDBStorage is only available on web platform');
  }

  @override
  bool get isOpen => false;

  /// Get the raw IndexedDB database object (stub for mobile)
  dynamic get rawDb => null;

  @override
  Future<void> open(String name) async {
    throw UnsupportedError('IndexedDBStorage is only available on web platform');
  }

  @override
  Future<void> close() async {
    throw UnsupportedError('IndexedDBStorage is only available on web platform');
  }

  @override
  Future<void> write(Future<void> Function(DatabaseInterface db) callback) async {
    throw UnsupportedError('IndexedDBStorage is only available on web platform');
  }

  @override
  void writeSync(void Function(DatabaseInterface db) callback) {
    throw UnsupportedError('IndexedDBStorage is only available on web platform');
  }

  @override
  CollectionInterface<T> getCollection<T>(String collectionName) {
    throw UnsupportedError('IndexedDBStorage is only available on web platform');
  }
}
