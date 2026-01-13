import 'dart:async';
import 'package:isar/isar.dart';
import 'package:flutter/foundation.dart' show debugPrint, protected;
import 'database_interface.dart';

/// IsarCollection adapter
/// Uses IndexedDB on web platform, uses Isar on mobile platform
class IsarCollectionAdapter<ID, OBJ> implements IsarCollection<ID, OBJ> {
  final IsarCollection<ID, OBJ>? _isarCollection;
  final CollectionInterface<OBJ>? _indexedDBCollection;
  final bool _isWeb;

  IsarCollectionAdapter({
    IsarCollection<ID, OBJ>? isarCollection,
    CollectionInterface<OBJ>? indexedDBCollection,
    required bool isWeb,
  })  : _isarCollection = isarCollection,
        _indexedDBCollection = indexedDBCollection,
        _isWeb = isWeb;

  @override
  Isar get isar {
    if (_isWeb) {
      throw UnsupportedError('isar property is not available when using IndexedDB');
    }
    return _isarCollection!.isar;
  }

  @override
  IsarSchema get schema {
    if (_isWeb) {
      throw UnsupportedError('schema property is not available when using IndexedDB');
    }
    return _isarCollection!.schema;
  }

  @override
  int autoIncrement() {
    if (_isWeb) {
      return _indexedDBCollection!.autoIncrement();
    }
    return _isarCollection!.autoIncrement();
  }

  @override
  OBJ? get(ID id) {
    if (_isWeb) {
      // IndexedDB is async, but Isar's get is sync
      // Here we need to return a Future, but interface requires sync
      // Temporarily use sync approach, may need adjustment
      throw UnsupportedError('Synchronous get is not supported with IndexedDB. Use getAsync instead.');
    }
    return _isarCollection!.get(id);
  }

  @override
  List<OBJ?> getAll(List<ID> ids) {
    if (_isWeb) {
      throw UnsupportedError('Synchronous getAll is not supported with IndexedDB. Use getAllAsync instead.');
    }
    return _isarCollection!.getAll(ids);
  }

  // Note: These methods are not part of IsarCollection interface, but we provide them for compatibility
  // Async get (for web platform)
  Future<OBJ?> getAsync(ID id) async {
    if (_isWeb) {
      return await _indexedDBCollection!.get(id as int);
    }
    return _isarCollection!.get(id);
  }

  // Async get multiple (for web platform)
  Future<List<OBJ?>> getAllAsync(List<ID> ids) async {
    if (_isWeb) {
      return await _indexedDBCollection!.getAll(ids.cast<int>());
    }
    return _isarCollection!.getAll(ids);
  }

  @override
  void put(OBJ object) {
    if (_isWeb) {
      throw UnsupportedError('Synchronous put is not supported with IndexedDB. Use putAsync instead.');
    }
    _isarCollection!.put(object);
  }

  @override
  void putAll(List<OBJ> objects) {
    if (_isWeb) {
      throw UnsupportedError('Synchronous putAll is not supported with IndexedDB. Use putAllAsync instead.');
    }
    _isarCollection!.putAll(objects);
  }

  /// Async save (for web platform)
  Future<void> putAsync(OBJ object) async {
    if (_isWeb) {
      await _indexedDBCollection!.put(object);
    } else {
      _isarCollection!.put(object);
    }
  }

  /// Async save multiple (for web platform)
  Future<void> putAllAsync(List<OBJ> objects) async {
    if (_isWeb) {
      await _indexedDBCollection!.putAll(objects);
    } else {
      _isarCollection!.putAll(objects);
    }
  }

  @override
  bool delete(ID id) {
    if (_isWeb) {
      throw UnsupportedError('Synchronous delete is not supported with IndexedDB. Use deleteAsync instead.');
    }
    return _isarCollection!.delete(id);
  }

  @override
  int deleteAll(List<ID> ids) {
    if (_isWeb) {
      throw UnsupportedError('Synchronous deleteAll is not supported with IndexedDB. Use deleteAllAsync instead.');
    }
    return _isarCollection!.deleteAll(ids);
  }

  /// Async delete (for web platform)
  Future<bool> deleteAsync(ID id) async {
    if (_isWeb) {
      return await _indexedDBCollection!.delete(id as int);
    }
    return _isarCollection!.delete(id);
  }

  /// Async delete multiple (for web platform)
  Future<int> deleteAllAsync(List<ID> ids) async {
    if (_isWeb) {
      return await _indexedDBCollection!.deleteAll(ids.cast<int>());
    }
    return _isarCollection!.deleteAll(ids);
  }

  @override
  QueryBuilder<OBJ, OBJ, QStart> where() {
    if (_isWeb) {
      // Web platform: don't create QueryBuilder instance, directly return wrapper
      // Use type assertion, because QueryBuilder constructor is @protected
      final wrapper = _IsarQueryBuilderWrapper<OBJ, OBJ, QStart>(
        indexedDBQueryBuilder: _indexedDBCollection!.where(),
        collection: this,
      );
      // Return using type assertion (user said type mismatch is ok, can use assertion)
      return wrapper as QueryBuilder<OBJ, OBJ, QStart>;
    }
    return _isarCollection!.where();
  }

  @override
  QueryBuilder<OBJ, OBJ, QFilterCondition> filter() {
    if (_isWeb) {
      // IndexedDB's filter() is actually where()
      // CollectionInterface only has where(), no filter()
      final wrapper = _IsarQueryBuilderWrapper<OBJ, OBJ, QFilterCondition>(
        indexedDBQueryBuilder: _indexedDBCollection!.where(),
        collection: this,
      );
      return wrapper as QueryBuilder<OBJ, OBJ, QFilterCondition>;
    }
    // IsarCollection has filter() method, but type system may not recognize it
    // Use dynamic call
    return (_isarCollection as dynamic).filter() as QueryBuilder<OBJ, OBJ, QFilterCondition>;
  }

  @override
  int count() {
    if (_isWeb) {
      throw UnsupportedError('Synchronous count is not supported with IndexedDB. Use countAsync instead.');
    }
    return _isarCollection!.count();
  }

  // Note: This method is not part of IsarCollection interface, but we provide it for compatibility
  // Async count (for web platform)
  Future<int> countAsync() async {
    if (_isWeb) {
      final queryBuilder = _indexedDBCollection!.where();
      return await queryBuilder.count();
    }
    return _isarCollection!.count();
  }

  @override
  int getSize({bool includeIndexes = false}) {
    if (_isWeb) {
      throw UnsupportedError('getSize is not supported with IndexedDB');
    }
    return _isarCollection!.getSize(includeIndexes: includeIndexes);
  }

  @override
  int importJson(List<Map<String, dynamic>> json) {
    if (_isWeb) {
      throw UnsupportedError('importJson is not supported with IndexedDB');
    }
    return _isarCollection!.importJson(json);
  }

  @override
  int importJsonString(String json) {
    if (_isWeb) {
      throw UnsupportedError('importJsonString is not supported with IndexedDB');
    }
    return _isarCollection!.importJsonString(json);
  }

  @override
  void clear() {
    if (_isWeb) {
      throw UnsupportedError('Synchronous clear is not supported with IndexedDB. Use clearAsync instead.');
    }
    _isarCollection!.clear();
  }

  // Note: This method is not part of IsarCollection interface, but we provide it for compatibility
  // Async clear (for web platform)
  Future<void> clearAsync() async {
    if (_isWeb) {
      await _indexedDBCollection!.clear();
    } else {
      _isarCollection!.clear();
    }
  }

  @override
  Stream<void> watchLazy({bool fireImmediately = false}) {
    if (_isWeb) {
      throw UnsupportedError('watchLazy is not supported with IndexedDB');
    }
    return _isarCollection!.watchLazy(fireImmediately: fireImmediately);
  }

  @override
  Stream<OBJ?> watchObject(ID id, {bool fireImmediately = false}) {
    if (_isWeb) {
      throw UnsupportedError('watchObject is not supported with IndexedDB');
    }
    return _isarCollection!.watchObject(id, fireImmediately: fireImmediately);
  }

  @override
  Stream<void> watchObjectLazy(ID id, {bool fireImmediately = false}) {
    if (_isWeb) {
      throw UnsupportedError('watchObjectLazy is not supported with IndexedDB');
    }
    return _isarCollection!.watchObjectLazy(id, fireImmediately: fireImmediately);
  }

  @override
  IsarQuery<R> buildQuery<R>({
    Filter? filter,
    List<SortProperty>? sortBy,
    List<DistinctProperty>? distinctBy,
    List<int>? properties,
  }) {
    if (_isWeb) {
      throw UnsupportedError('buildQuery is not supported with IndexedDB');
    }
    return _isarCollection!.buildQuery<R>(
      filter: filter,
      sortBy: sortBy,
      distinctBy: distinctBy,
      properties: properties,
    );
  }

  int updateProperties(List<ID> ids, Map<int, dynamic> changes) {
    if (_isWeb) {
      throw UnsupportedError('updateProperties is not supported with IndexedDB');
    }
    return _isarCollection!.updateProperties(ids, changes);
  }
}

/// Isar QueryBuilder wrapper
/// Adapts IndexedDB query builder to Isar's QueryBuilder
/// Doesn't extend QueryBuilder, because its constructor is @protected
/// Uses noSuchMethod to handle all method calls
class _IsarQueryBuilderWrapper<OBJ, R, S> implements QueryBuilder<OBJ, R, S> {
  final QueryBuilderInterface<OBJ> indexedDBQueryBuilder;
  final IsarCollection<dynamic, OBJ> collection;
  // Create a fake _query object to satisfy some internal checks
  // Using a simple object to avoid type check errors
  late final dynamic _query = <String, dynamic>{};

  _IsarQueryBuilderWrapper({
    required this.indexedDBQueryBuilder,
    required this.collection,
  });

  // Note: Extension methods findAll/findFirst/count are sync
  // But code uses await, indicating async version is expected
  // We intercept these calls through noSuchMethod, return Future

  // Use noSuchMethod to handle all method calls
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString();
    final cleanName = name.replaceAll('Symbol("', '').replaceAll('")', '');
    
    // Handle findAll method (extension method, sync version, but code uses await)
    if (cleanName == 'findAll') {
      // Return Future, because IndexedDB is async
      // Code uses await, so this should be async version
      return indexedDBQueryBuilder.findAll();
    }
    
    // Handle findFirst method
    if (cleanName == 'findFirst') {
      return indexedDBQueryBuilder.findFirst();
    }
    
    // Handle findLast method
    if (cleanName == 'findLast') {
      return indexedDBQueryBuilder.findLast();
    }
    
    // Handle count method
    if (cleanName == 'count') {
      return indexedDBQueryBuilder.count();
    }
    
    // Handle methods like pubKeyEqualTo
    if (cleanName.endsWith('EqualTo')) {
      final property = cleanName.replaceAll('EqualTo', '');
      final value = invocation.positionalArguments.isNotEmpty 
          ? invocation.positionalArguments.first 
          : null;
      if (value != null) {
        indexedDBQueryBuilder.equalTo(_camelToSnake(property), value);
        return this;
      }
    }
    
    // Handle methods like hashTagsElementEqualTo
    if (cleanName.endsWith('ElementEqualTo')) {
      final property = cleanName.replaceAll('ElementEqualTo', '');
      final value = invocation.positionalArguments.isNotEmpty 
          ? invocation.positionalArguments.first 
          : null;
      if (value != null) {
        indexedDBQueryBuilder.elementEqualTo(_camelToSnake(property), value);
        return this;
      }
    }
    
    // Handle methods like groupIdIsEmpty
    if (cleanName.endsWith('IsEmpty')) {
      final property = cleanName.replaceAll('IsEmpty', '');
      indexedDBQueryBuilder.isEmpty(_camelToSnake(property));
      return this;
    }
    
    // Handle methods like groupIdIsNotEmpty
    if (cleanName.endsWith('IsNotEmpty')) {
      final property = cleanName.replaceAll('IsNotEmpty', '');
      indexedDBQueryBuilder.isNotEmpty(_camelToSnake(property));
      return this;
    }
    
    // Handle anyOf method
    if (cleanName == 'anyOf') {
      // anyOf method implementation is complex, temporarily return this
      // TODO: Implement complete anyOf logic
      return this;
    }
    
    // For other methods, directly throw error
    debugPrint('⚠️ [IsarQueryBuilderWrapper] Unhandled method: $cleanName');
    throw UnsupportedError('Method $cleanName is not supported on web platform');
  }

  /// Convert camelCase to snake_case
  String _camelToSnake(String camel) {
    return camel.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => '_${match.group(1)!.toLowerCase()}',
    ).replaceFirst(RegExp(r'^_'), '');
  }
}

/// Isar QueryBuilder adapter (deprecated, use _IsarQueryBuilderWrapper)
/// Adapts IndexedDB query builder to Isar's query builder
@Deprecated('Use _IsarQueryBuilderWrapper instead')
class IsarQueryBuilderAdapter<OBJ> implements QueryBuilder<OBJ, OBJ, dynamic> {
  final QueryBuilderInterface<OBJ> _indexedDBQueryBuilder;

  IsarQueryBuilderAdapter(this._indexedDBQueryBuilder);

  @override
  Future<List<OBJ>> findAll({int? limit, int? offset}) async {
    return await _indexedDBQueryBuilder.findAll(limit: limit, offset: offset);
  }

  @override
  Future<OBJ?> findFirst() async {
    return await _indexedDBQueryBuilder.findFirst();
  }

  @override
  Future<OBJ?> findLast() async {
    return await _indexedDBQueryBuilder.findLast();
  }

  @override
  Future<int> count() async {
    return await _indexedDBQueryBuilder.count();
  }

  // Since Isar's QueryBuilder has many dynamically generated methods (like pubKeyEqualTo)
  // We need to use noSuchMethod to intercept these calls
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString();
    
    // Handle methods like pubKeyEqualTo
    if (name.endsWith('EqualTo')) {
      final property = name.replaceAll('EqualTo', '');
      final value = invocation.positionalArguments.first;
      return _indexedDBQueryBuilder.equalTo(_camelToSnake(property), value);
    }
    
    // Handle methods like hashTagsElementEqualTo
    if (name.endsWith('ElementEqualTo')) {
      final property = name.replaceAll('ElementEqualTo', '');
      final value = invocation.positionalArguments.first;
      return _indexedDBQueryBuilder.elementEqualTo(_camelToSnake(property), value);
    }
    
    // Handle methods like groupIdIsEmpty
    if (name.endsWith('IsEmpty')) {
      final property = name.replaceAll('IsEmpty', '');
      return _indexedDBQueryBuilder.isEmpty(_camelToSnake(property));
    }
    
    // Handle methods like groupIdIsNotEmpty
    if (name.endsWith('IsNotEmpty')) {
      final property = name.replaceAll('IsNotEmpty', '');
      return _indexedDBQueryBuilder.isNotEmpty(_camelToSnake(property));
    }
    
    // Handle anyOf method
    if (name == 'anyOf') {
      // anyOf method implementation is complex, temporarily return this
      // TODO: Implement complete anyOf logic
      return this;
    }
    
    debugPrint('⚠️ [IsarQueryBuilderAdapter] Unhandled method: $name');
    return this;
  }

  /// Convert camelCase to snake_case
  String _camelToSnake(String camel) {
    return camel.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => '_${match.group(1)!.toLowerCase()}',
    ).replaceFirst(RegExp(r'^_'), '');
  }
}
