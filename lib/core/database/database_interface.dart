import 'dart:async';

/// Database abstraction interface
/// Used to unify Isar and IndexedDB interfaces
abstract class DatabaseInterface {
  /// Whether the database is open
  bool get isOpen;

  /// Open database
  Future<void> open(String name);

  /// Close database
  Future<void> close();

  /// Write transaction (async)
  Future<void> write(Future<void> Function(DatabaseInterface db) callback);

  /// Write transaction (sync)
  void writeSync(void Function(DatabaseInterface db) callback);

  /// Get collection
  CollectionInterface<T> getCollection<T>(String collectionName);
}

/// Collection abstraction interface
abstract class CollectionInterface<T> {
  /// Get single object
  Future<T?> get(int id);

  /// Get multiple objects
  Future<List<T?>> getAll(List<int> ids);

  /// Save single object
  Future<void> put(T object);

  /// Save multiple objects
  Future<void> putAll(List<T> objects);

  /// Delete single object
  Future<bool> delete(int id);

  /// Delete multiple objects
  Future<int> deleteAll(List<int> ids);

  /// Clear collection
  Future<void> clear();

  /// Get auto-increment ID
  int autoIncrement();

  /// Start building query
  QueryBuilderInterface<T> where();

  /// Start building filter query
  QueryBuilderInterface<T> filter();
}

/// Query builder interface
abstract class QueryBuilderInterface<T> {
  /// Find all
  Future<List<T>> findAll({int? limit, int? offset});

  /// Find first
  Future<T?> findFirst();

  /// Find last
  Future<T?> findLast();

  /// Count
  Future<int> count();

  /// Equal to
  QueryBuilderInterface<T> equalTo(String property, dynamic value);

  /// Not equal to
  QueryBuilderInterface<T> notEqualTo(String property, dynamic value);

  /// Contains
  QueryBuilderInterface<T> contains(String property, String value, {bool caseSensitive = true});

  /// Element equal to (for lists)
  QueryBuilderInterface<T> elementEqualTo(String property, dynamic value);

  /// Is empty
  QueryBuilderInterface<T> isEmpty(String property);

  /// Is not empty
  QueryBuilderInterface<T> isNotEmpty(String property);

  /// Any match (anyOf)
  QueryBuilderInterface<T> anyOf(String property, List<dynamic> values);

  /// Combine queries (and)
  QueryBuilderInterface<T> and(QueryBuilderInterface<T> Function(QueryBuilderInterface<T>) builder);

  /// Combine queries (or)
  QueryBuilderInterface<T> or(QueryBuilderInterface<T> Function(QueryBuilderInterface<T>) builder);

  /// Create a child builder (for use in or/anyOf). Same collection, empty conditions.
  QueryBuilderInterface<T> createChildBuilder();

  /// Add the child builder's conditions as one OR group. Child must be the same concrete builder type.
  void addOrGroupFromChild(QueryBuilderInterface<T> child);
}
