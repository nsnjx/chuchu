// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feedDraftDB_isar.dart';

// **************************************************************************
// _IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, invalid_use_of_protected_member, lines_longer_than_80_chars, constant_identifier_names, avoid_js_rounded_ints, no_leading_underscores_for_local_identifiers, require_trailing_commas, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_in_if_null_operators, library_private_types_in_public_api, prefer_const_constructors
// ignore_for_file: type=lint

extension GetFeedDraftDBISARCollection on Isar {
  IsarCollection<int, FeedDraftDBISAR> get feedDraftDBISARs =>
      this.collection();
}

const FeedDraftDBISARSchema = IsarGeneratedSchema(
  schema: IsarSchema(
    name: 'FeedDraftDBISAR',
    idName: 'id',
    embedded: false,
    properties: [
      IsarPropertySchema(
        name: 'author',
        type: IsarType.string,
      ),
      IsarPropertySchema(
        name: 'content',
        type: IsarType.string,
      ),
      IsarPropertySchema(
        name: 'imageUrls',
        type: IsarType.stringList,
      ),
      IsarPropertySchema(
        name: 'videoUrls',
        type: IsarType.stringList,
      ),
      IsarPropertySchema(
        name: 'draftCueUserMapJson',
        type: IsarType.string,
      ),
      IsarPropertySchema(
        name: 'updatedAt',
        type: IsarType.long,
      ),
    ],
    indexes: [
      IsarIndexSchema(
        name: 'author',
        properties: [
          "author",
        ],
        unique: true,
        hash: false,
      ),
    ],
  ),
  converter: IsarObjectConverter<int, FeedDraftDBISAR>(
    serialize: serializeFeedDraftDBISAR,
    deserialize: deserializeFeedDraftDBISAR,
    deserializeProperty: deserializeFeedDraftDBISARProp,
  ),
  embeddedSchemas: [],
);

@isarProtected
int serializeFeedDraftDBISAR(IsarWriter writer, FeedDraftDBISAR object) {
  IsarCore.writeString(writer, 1, object.author);
  IsarCore.writeString(writer, 2, object.content);
  {
    final list = object.imageUrls;
    if (list == null) {
      IsarCore.writeNull(writer, 3);
    } else {
      final listWriter = IsarCore.beginList(writer, 3, list.length);
      for (var i = 0; i < list.length; i++) {
        IsarCore.writeString(listWriter, i, list[i]);
      }
      IsarCore.endList(writer, listWriter);
    }
  }
  {
    final list = object.videoUrls;
    if (list == null) {
      IsarCore.writeNull(writer, 4);
    } else {
      final listWriter = IsarCore.beginList(writer, 4, list.length);
      for (var i = 0; i < list.length; i++) {
        IsarCore.writeString(listWriter, i, list[i]);
      }
      IsarCore.endList(writer, listWriter);
    }
  }
  {
    final value = object.draftCueUserMapJson;
    if (value == null) {
      IsarCore.writeNull(writer, 5);
    } else {
      IsarCore.writeString(writer, 5, value);
    }
  }
  IsarCore.writeLong(writer, 6, object.updatedAt);
  return object.id;
}

@isarProtected
FeedDraftDBISAR deserializeFeedDraftDBISAR(IsarReader reader) {
  final String _author;
  _author = IsarCore.readString(reader, 1) ?? '';
  final String _content;
  _content = IsarCore.readString(reader, 2) ?? '';
  final List<String>? _imageUrls;
  {
    final length = IsarCore.readList(reader, 3, IsarCore.readerPtrPtr);
    {
      final reader = IsarCore.readerPtr;
      if (reader.isNull) {
        _imageUrls = null;
      } else {
        final list = List<String>.filled(length, '', growable: true);
        for (var i = 0; i < length; i++) {
          list[i] = IsarCore.readString(reader, i) ?? '';
        }
        IsarCore.freeReader(reader);
        _imageUrls = list;
      }
    }
  }
  final List<String>? _videoUrls;
  {
    final length = IsarCore.readList(reader, 4, IsarCore.readerPtrPtr);
    {
      final reader = IsarCore.readerPtr;
      if (reader.isNull) {
        _videoUrls = null;
      } else {
        final list = List<String>.filled(length, '', growable: true);
        for (var i = 0; i < length; i++) {
          list[i] = IsarCore.readString(reader, i) ?? '';
        }
        IsarCore.freeReader(reader);
        _videoUrls = list;
      }
    }
  }
  final String? _draftCueUserMapJson;
  _draftCueUserMapJson = IsarCore.readString(reader, 5);
  final int _updatedAt;
  {
    final value = IsarCore.readLong(reader, 6);
    if (value == -9223372036854775808) {
      _updatedAt = 0;
    } else {
      _updatedAt = value;
    }
  }
  final object = FeedDraftDBISAR(
    author: _author,
    content: _content,
    imageUrls: _imageUrls,
    videoUrls: _videoUrls,
    draftCueUserMapJson: _draftCueUserMapJson,
    updatedAt: _updatedAt,
  );
  object.id = IsarCore.readId(reader);
  return object;
}

@isarProtected
dynamic deserializeFeedDraftDBISARProp(IsarReader reader, int property) {
  switch (property) {
    case 0:
      return IsarCore.readId(reader);
    case 1:
      return IsarCore.readString(reader, 1) ?? '';
    case 2:
      return IsarCore.readString(reader, 2) ?? '';
    case 3:
      {
        final length = IsarCore.readList(reader, 3, IsarCore.readerPtrPtr);
        {
          final reader = IsarCore.readerPtr;
          if (reader.isNull) {
            return null;
          } else {
            final list = List<String>.filled(length, '', growable: true);
            for (var i = 0; i < length; i++) {
              list[i] = IsarCore.readString(reader, i) ?? '';
            }
            IsarCore.freeReader(reader);
            return list;
          }
        }
      }
    case 4:
      {
        final length = IsarCore.readList(reader, 4, IsarCore.readerPtrPtr);
        {
          final reader = IsarCore.readerPtr;
          if (reader.isNull) {
            return null;
          } else {
            final list = List<String>.filled(length, '', growable: true);
            for (var i = 0; i < length; i++) {
              list[i] = IsarCore.readString(reader, i) ?? '';
            }
            IsarCore.freeReader(reader);
            return list;
          }
        }
      }
    case 5:
      return IsarCore.readString(reader, 5);
    case 6:
      {
        final value = IsarCore.readLong(reader, 6);
        if (value == -9223372036854775808) {
          return 0;
        } else {
          return value;
        }
      }
    default:
      throw ArgumentError('Unknown property: $property');
  }
}

sealed class _FeedDraftDBISARUpdate {
  bool call({
    required int id,
    String? author,
    String? content,
    String? draftCueUserMapJson,
    int? updatedAt,
  });
}

class _FeedDraftDBISARUpdateImpl implements _FeedDraftDBISARUpdate {
  const _FeedDraftDBISARUpdateImpl(this.collection);

  final IsarCollection<int, FeedDraftDBISAR> collection;

  @override
  bool call({
    required int id,
    Object? author = ignore,
    Object? content = ignore,
    Object? draftCueUserMapJson = ignore,
    Object? updatedAt = ignore,
  }) {
    return collection.updateProperties([
          id
        ], {
          if (author != ignore) 1: author as String?,
          if (content != ignore) 2: content as String?,
          if (draftCueUserMapJson != ignore) 5: draftCueUserMapJson as String?,
          if (updatedAt != ignore) 6: updatedAt as int?,
        }) >
        0;
  }
}

sealed class _FeedDraftDBISARUpdateAll {
  int call({
    required List<int> id,
    String? author,
    String? content,
    String? draftCueUserMapJson,
    int? updatedAt,
  });
}

class _FeedDraftDBISARUpdateAllImpl implements _FeedDraftDBISARUpdateAll {
  const _FeedDraftDBISARUpdateAllImpl(this.collection);

  final IsarCollection<int, FeedDraftDBISAR> collection;

  @override
  int call({
    required List<int> id,
    Object? author = ignore,
    Object? content = ignore,
    Object? draftCueUserMapJson = ignore,
    Object? updatedAt = ignore,
  }) {
    return collection.updateProperties(id, {
      if (author != ignore) 1: author as String?,
      if (content != ignore) 2: content as String?,
      if (draftCueUserMapJson != ignore) 5: draftCueUserMapJson as String?,
      if (updatedAt != ignore) 6: updatedAt as int?,
    });
  }
}

extension FeedDraftDBISARUpdate on IsarCollection<int, FeedDraftDBISAR> {
  _FeedDraftDBISARUpdate get update => _FeedDraftDBISARUpdateImpl(this);

  _FeedDraftDBISARUpdateAll get updateAll =>
      _FeedDraftDBISARUpdateAllImpl(this);
}

sealed class _FeedDraftDBISARQueryUpdate {
  int call({
    String? author,
    String? content,
    String? draftCueUserMapJson,
    int? updatedAt,
  });
}

class _FeedDraftDBISARQueryUpdateImpl implements _FeedDraftDBISARQueryUpdate {
  const _FeedDraftDBISARQueryUpdateImpl(this.query, {this.limit});

  final IsarQuery<FeedDraftDBISAR> query;
  final int? limit;

  @override
  int call({
    Object? author = ignore,
    Object? content = ignore,
    Object? draftCueUserMapJson = ignore,
    Object? updatedAt = ignore,
  }) {
    return query.updateProperties(limit: limit, {
      if (author != ignore) 1: author as String?,
      if (content != ignore) 2: content as String?,
      if (draftCueUserMapJson != ignore) 5: draftCueUserMapJson as String?,
      if (updatedAt != ignore) 6: updatedAt as int?,
    });
  }
}

extension FeedDraftDBISARQueryUpdate on IsarQuery<FeedDraftDBISAR> {
  _FeedDraftDBISARQueryUpdate get updateFirst =>
      _FeedDraftDBISARQueryUpdateImpl(this, limit: 1);

  _FeedDraftDBISARQueryUpdate get updateAll =>
      _FeedDraftDBISARQueryUpdateImpl(this);
}

class _FeedDraftDBISARQueryBuilderUpdateImpl
    implements _FeedDraftDBISARQueryUpdate {
  const _FeedDraftDBISARQueryBuilderUpdateImpl(this.query, {this.limit});

  final QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QOperations> query;
  final int? limit;

  @override
  int call({
    Object? author = ignore,
    Object? content = ignore,
    Object? draftCueUserMapJson = ignore,
    Object? updatedAt = ignore,
  }) {
    final q = query.build();
    try {
      return q.updateProperties(limit: limit, {
        if (author != ignore) 1: author as String?,
        if (content != ignore) 2: content as String?,
        if (draftCueUserMapJson != ignore) 5: draftCueUserMapJson as String?,
        if (updatedAt != ignore) 6: updatedAt as int?,
      });
    } finally {
      q.close();
    }
  }
}

extension FeedDraftDBISARQueryBuilderUpdate
    on QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QOperations> {
  _FeedDraftDBISARQueryUpdate get updateFirst =>
      _FeedDraftDBISARQueryBuilderUpdateImpl(this, limit: 1);

  _FeedDraftDBISARQueryUpdate get updateAll =>
      _FeedDraftDBISARQueryBuilderUpdateImpl(this);
}

extension FeedDraftDBISARQueryFilter
    on QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QFilterCondition> {
  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      idEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(
          property: 0,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      idGreaterThan(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 0,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      idGreaterThanOrEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 0,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      idLessThan(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(
          property: 0,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      idLessThanOrEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 0,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      idBetween(
    int lower,
    int upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 0,
          lower: lower,
          upper: upper,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      authorEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      authorGreaterThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      authorGreaterThanOrEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      authorLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      authorLessThanOrEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      authorBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 1,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      authorStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      authorEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      authorContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      authorMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 1,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      authorIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(
          property: 1,
          value: '',
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      authorIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(
          property: 1,
          value: '',
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      contentEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(
          property: 2,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      contentGreaterThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 2,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      contentGreaterThanOrEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 2,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      contentLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(
          property: 2,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      contentLessThanOrEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 2,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      contentBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 2,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      contentStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 2,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      contentEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 2,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      contentContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 2,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      contentMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 2,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      contentIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(
          property: 2,
          value: '',
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      contentIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(
          property: 2,
          value: '',
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      imageUrlsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const IsNullCondition(property: 3));
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      imageUrlsIsNotNull() {
    return QueryBuilder.apply(not(), (query) {
      return query.addFilterCondition(const IsNullCondition(property: 3));
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      imageUrlsElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      imageUrlsElementGreaterThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      imageUrlsElementGreaterThanOrEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      imageUrlsElementLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      imageUrlsElementLessThanOrEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      imageUrlsElementBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 3,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      imageUrlsElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      imageUrlsElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      imageUrlsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      imageUrlsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 3,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      imageUrlsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(
          property: 3,
          value: '',
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      imageUrlsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(
          property: 3,
          value: '',
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      imageUrlsIsEmpty() {
    return not().group(
      (q) => q.imageUrlsIsNull().or().imageUrlsIsNotEmpty(),
    );
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      imageUrlsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterOrEqualCondition(property: 3, value: null),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      videoUrlsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const IsNullCondition(property: 4));
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      videoUrlsIsNotNull() {
    return QueryBuilder.apply(not(), (query) {
      return query.addFilterCondition(const IsNullCondition(property: 4));
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      videoUrlsElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      videoUrlsElementGreaterThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      videoUrlsElementGreaterThanOrEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      videoUrlsElementLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      videoUrlsElementLessThanOrEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      videoUrlsElementBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 4,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      videoUrlsElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      videoUrlsElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      videoUrlsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      videoUrlsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 4,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      videoUrlsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(
          property: 4,
          value: '',
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      videoUrlsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(
          property: 4,
          value: '',
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      videoUrlsIsEmpty() {
    return not().group(
      (q) => q.videoUrlsIsNull().or().videoUrlsIsNotEmpty(),
    );
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      videoUrlsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterOrEqualCondition(property: 4, value: null),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      draftCueUserMapJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const IsNullCondition(property: 5));
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      draftCueUserMapJsonIsNotNull() {
    return QueryBuilder.apply(not(), (query) {
      return query.addFilterCondition(const IsNullCondition(property: 5));
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      draftCueUserMapJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      draftCueUserMapJsonGreaterThan(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      draftCueUserMapJsonGreaterThanOrEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      draftCueUserMapJsonLessThan(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      draftCueUserMapJsonLessThanOrEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      draftCueUserMapJsonBetween(
    String? lower,
    String? upper, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 5,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      draftCueUserMapJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      draftCueUserMapJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      draftCueUserMapJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      draftCueUserMapJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 5,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      draftCueUserMapJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(
          property: 5,
          value: '',
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      draftCueUserMapJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(
          property: 5,
          value: '',
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      updatedAtEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(
          property: 6,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      updatedAtGreaterThan(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 6,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      updatedAtGreaterThanOrEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 6,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      updatedAtLessThan(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(
          property: 6,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      updatedAtLessThanOrEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 6,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterFilterCondition>
      updatedAtBetween(
    int lower,
    int upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 6,
          lower: lower,
          upper: upper,
        ),
      );
    });
  }
}

extension FeedDraftDBISARQueryObject
    on QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QFilterCondition> {}

extension FeedDraftDBISARQuerySortBy
    on QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QSortBy> {
  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterSortBy> sortById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterSortBy> sortByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterSortBy> sortByAuthor(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(
        1,
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterSortBy> sortByAuthorDesc(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(
        1,
        sort: Sort.desc,
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterSortBy> sortByContent(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(
        2,
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterSortBy>
      sortByContentDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(
        2,
        sort: Sort.desc,
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterSortBy>
      sortByDraftCueUserMapJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(
        5,
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterSortBy>
      sortByDraftCueUserMapJsonDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(
        5,
        sort: Sort.desc,
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterSortBy>
      sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6);
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterSortBy>
      sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, sort: Sort.desc);
    });
  }
}

extension FeedDraftDBISARQuerySortThenBy
    on QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QSortThenBy> {
  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterSortBy> thenByAuthor(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterSortBy> thenByAuthorDesc(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterSortBy> thenByContent(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterSortBy>
      thenByContentDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterSortBy>
      thenByDraftCueUserMapJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterSortBy>
      thenByDraftCueUserMapJsonDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterSortBy>
      thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6);
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterSortBy>
      thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, sort: Sort.desc);
    });
  }
}

extension FeedDraftDBISARQueryWhereDistinct
    on QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QDistinct> {
  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterDistinct>
      distinctByAuthor({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterDistinct>
      distinctByContent({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterDistinct>
      distinctByImageUrls() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(3);
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterDistinct>
      distinctByVideoUrls() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(4);
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterDistinct>
      distinctByDraftCueUserMapJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(5, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QAfterDistinct>
      distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(6);
    });
  }
}

extension FeedDraftDBISARQueryProperty1
    on QueryBuilder<FeedDraftDBISAR, FeedDraftDBISAR, QProperty> {
  QueryBuilder<FeedDraftDBISAR, int, QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<FeedDraftDBISAR, String, QAfterProperty> authorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<FeedDraftDBISAR, String, QAfterProperty> contentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<FeedDraftDBISAR, List<String>?, QAfterProperty>
      imageUrlsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<FeedDraftDBISAR, List<String>?, QAfterProperty>
      videoUrlsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<FeedDraftDBISAR, String?, QAfterProperty>
      draftCueUserMapJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<FeedDraftDBISAR, int, QAfterProperty> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }
}

extension FeedDraftDBISARQueryProperty2<R>
    on QueryBuilder<FeedDraftDBISAR, R, QAfterProperty> {
  QueryBuilder<FeedDraftDBISAR, (R, int), QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<FeedDraftDBISAR, (R, String), QAfterProperty> authorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<FeedDraftDBISAR, (R, String), QAfterProperty> contentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<FeedDraftDBISAR, (R, List<String>?), QAfterProperty>
      imageUrlsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<FeedDraftDBISAR, (R, List<String>?), QAfterProperty>
      videoUrlsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<FeedDraftDBISAR, (R, String?), QAfterProperty>
      draftCueUserMapJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<FeedDraftDBISAR, (R, int), QAfterProperty> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }
}

extension FeedDraftDBISARQueryProperty3<R1, R2>
    on QueryBuilder<FeedDraftDBISAR, (R1, R2), QAfterProperty> {
  QueryBuilder<FeedDraftDBISAR, (R1, R2, int), QOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<FeedDraftDBISAR, (R1, R2, String), QOperations>
      authorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<FeedDraftDBISAR, (R1, R2, String), QOperations>
      contentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<FeedDraftDBISAR, (R1, R2, List<String>?), QOperations>
      imageUrlsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<FeedDraftDBISAR, (R1, R2, List<String>?), QOperations>
      videoUrlsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<FeedDraftDBISAR, (R1, R2, String?), QOperations>
      draftCueUserMapJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<FeedDraftDBISAR, (R1, R2, int), QOperations>
      updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }
}
