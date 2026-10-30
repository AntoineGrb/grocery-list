// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ArticlesTable extends Articles with TableInfo<$ArticlesTable, Article> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ArticlesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _normalizedNameMeta = const VerificationMeta(
    'normalizedName',
  );
  @override
  late final GeneratedColumn<String> normalizedName = GeneratedColumn<String>(
    'normalized_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rayonMeta = const VerificationMeta('rayon');
  @override
  late final GeneratedColumn<String> rayon = GeneratedColumn<String>(
    'rayon',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pictoKeyMeta = const VerificationMeta(
    'pictoKey',
  );
  @override
  late final GeneratedColumn<String> pictoKey = GeneratedColumn<String>(
    'picto_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _inCatalogueMeta = const VerificationMeta(
    'inCatalogue',
  );
  @override
  late final GeneratedColumn<bool> inCatalogue = GeneratedColumn<bool>(
    'in_catalogue',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("in_catalogue" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    updatedAt,
    deletedAt,
    name,
    normalizedName,
    rayon,
    unit,
    pictoKey,
    inCatalogue,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'articles';
  @override
  VerificationContext validateIntegrity(
    Insertable<Article> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('normalized_name')) {
      context.handle(
        _normalizedNameMeta,
        normalizedName.isAcceptableOrUnknown(
          data['normalized_name']!,
          _normalizedNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_normalizedNameMeta);
    }
    if (data.containsKey('rayon')) {
      context.handle(
        _rayonMeta,
        rayon.isAcceptableOrUnknown(data['rayon']!, _rayonMeta),
      );
    } else if (isInserting) {
      context.missing(_rayonMeta);
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    }
    if (data.containsKey('picto_key')) {
      context.handle(
        _pictoKeyMeta,
        pictoKey.isAcceptableOrUnknown(data['picto_key']!, _pictoKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_pictoKeyMeta);
    }
    if (data.containsKey('in_catalogue')) {
      context.handle(
        _inCatalogueMeta,
        inCatalogue.isAcceptableOrUnknown(
          data['in_catalogue']!,
          _inCatalogueMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Article map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Article(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      normalizedName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized_name'],
      )!,
      rayon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rayon'],
      )!,
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      ),
      pictoKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}picto_key'],
      )!,
      inCatalogue: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}in_catalogue'],
      )!,
    );
  }

  @override
  $ArticlesTable createAlias(String alias) {
    return $ArticlesTable(attachedDatabase, alias);
  }
}

class Article extends DataClass implements Insertable<Article> {
  final String id;
  final int updatedAt;
  final int? deletedAt;
  final String name;

  /// `normalizeName(name)` ; unique parmi les articles actifs (AD-17).
  final String normalizedName;

  /// Code de rayon par défaut (AD-11).
  final String rayon;

  /// Unité par défaut : `g`, `ml`, `piece` ou nulle (sans) (AD-6).
  final String? unit;

  /// Clé de picto stable, en kebab-case (AD-18).
  final String pictoKey;

  /// Faux pour un article hors catalogue, né d'un texte validé par Entrée
  /// dans le Panneau + : absent de la recherche et de Paramètres › Articles
  /// (AD-17). Vrai pour les articles d'avant la v2 (AD-14).
  final bool inCatalogue;
  const Article({
    required this.id,
    required this.updatedAt,
    this.deletedAt,
    required this.name,
    required this.normalizedName,
    required this.rayon,
    this.unit,
    required this.pictoKey,
    required this.inCatalogue,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['name'] = Variable<String>(name);
    map['normalized_name'] = Variable<String>(normalizedName);
    map['rayon'] = Variable<String>(rayon);
    if (!nullToAbsent || unit != null) {
      map['unit'] = Variable<String>(unit);
    }
    map['picto_key'] = Variable<String>(pictoKey);
    map['in_catalogue'] = Variable<bool>(inCatalogue);
    return map;
  }

  ArticlesCompanion toCompanion(bool nullToAbsent) {
    return ArticlesCompanion(
      id: Value(id),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      name: Value(name),
      normalizedName: Value(normalizedName),
      rayon: Value(rayon),
      unit: unit == null && nullToAbsent ? const Value.absent() : Value(unit),
      pictoKey: Value(pictoKey),
      inCatalogue: Value(inCatalogue),
    );
  }

  factory Article.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Article(
      id: serializer.fromJson<String>(json['id']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      name: serializer.fromJson<String>(json['name']),
      normalizedName: serializer.fromJson<String>(json['normalizedName']),
      rayon: serializer.fromJson<String>(json['rayon']),
      unit: serializer.fromJson<String?>(json['unit']),
      pictoKey: serializer.fromJson<String>(json['pictoKey']),
      inCatalogue: serializer.fromJson<bool>(json['inCatalogue']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'name': serializer.toJson<String>(name),
      'normalizedName': serializer.toJson<String>(normalizedName),
      'rayon': serializer.toJson<String>(rayon),
      'unit': serializer.toJson<String?>(unit),
      'pictoKey': serializer.toJson<String>(pictoKey),
      'inCatalogue': serializer.toJson<bool>(inCatalogue),
    };
  }

  Article copyWith({
    String? id,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    String? name,
    String? normalizedName,
    String? rayon,
    Value<String?> unit = const Value.absent(),
    String? pictoKey,
    bool? inCatalogue,
  }) => Article(
    id: id ?? this.id,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    name: name ?? this.name,
    normalizedName: normalizedName ?? this.normalizedName,
    rayon: rayon ?? this.rayon,
    unit: unit.present ? unit.value : this.unit,
    pictoKey: pictoKey ?? this.pictoKey,
    inCatalogue: inCatalogue ?? this.inCatalogue,
  );
  Article copyWithCompanion(ArticlesCompanion data) {
    return Article(
      id: data.id.present ? data.id.value : this.id,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      name: data.name.present ? data.name.value : this.name,
      normalizedName: data.normalizedName.present
          ? data.normalizedName.value
          : this.normalizedName,
      rayon: data.rayon.present ? data.rayon.value : this.rayon,
      unit: data.unit.present ? data.unit.value : this.unit,
      pictoKey: data.pictoKey.present ? data.pictoKey.value : this.pictoKey,
      inCatalogue: data.inCatalogue.present
          ? data.inCatalogue.value
          : this.inCatalogue,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Article(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('name: $name, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('rayon: $rayon, ')
          ..write('unit: $unit, ')
          ..write('pictoKey: $pictoKey, ')
          ..write('inCatalogue: $inCatalogue')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    updatedAt,
    deletedAt,
    name,
    normalizedName,
    rayon,
    unit,
    pictoKey,
    inCatalogue,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Article &&
          other.id == this.id &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.name == this.name &&
          other.normalizedName == this.normalizedName &&
          other.rayon == this.rayon &&
          other.unit == this.unit &&
          other.pictoKey == this.pictoKey &&
          other.inCatalogue == this.inCatalogue);
}

class ArticlesCompanion extends UpdateCompanion<Article> {
  final Value<String> id;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<String> name;
  final Value<String> normalizedName;
  final Value<String> rayon;
  final Value<String?> unit;
  final Value<String> pictoKey;
  final Value<bool> inCatalogue;
  final Value<int> rowid;
  const ArticlesCompanion({
    this.id = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.name = const Value.absent(),
    this.normalizedName = const Value.absent(),
    this.rayon = const Value.absent(),
    this.unit = const Value.absent(),
    this.pictoKey = const Value.absent(),
    this.inCatalogue = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ArticlesCompanion.insert({
    required String id,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    required String name,
    required String normalizedName,
    required String rayon,
    this.unit = const Value.absent(),
    required String pictoKey,
    this.inCatalogue = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       updatedAt = Value(updatedAt),
       name = Value(name),
       normalizedName = Value(normalizedName),
       rayon = Value(rayon),
       pictoKey = Value(pictoKey);
  static Insertable<Article> custom({
    Expression<String>? id,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<String>? name,
    Expression<String>? normalizedName,
    Expression<String>? rayon,
    Expression<String>? unit,
    Expression<String>? pictoKey,
    Expression<bool>? inCatalogue,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (name != null) 'name': name,
      if (normalizedName != null) 'normalized_name': normalizedName,
      if (rayon != null) 'rayon': rayon,
      if (unit != null) 'unit': unit,
      if (pictoKey != null) 'picto_key': pictoKey,
      if (inCatalogue != null) 'in_catalogue': inCatalogue,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ArticlesCompanion copyWith({
    Value<String>? id,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<String>? name,
    Value<String>? normalizedName,
    Value<String>? rayon,
    Value<String?>? unit,
    Value<String>? pictoKey,
    Value<bool>? inCatalogue,
    Value<int>? rowid,
  }) {
    return ArticlesCompanion(
      id: id ?? this.id,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      rayon: rayon ?? this.rayon,
      unit: unit ?? this.unit,
      pictoKey: pictoKey ?? this.pictoKey,
      inCatalogue: inCatalogue ?? this.inCatalogue,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (normalizedName.present) {
      map['normalized_name'] = Variable<String>(normalizedName.value);
    }
    if (rayon.present) {
      map['rayon'] = Variable<String>(rayon.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (pictoKey.present) {
      map['picto_key'] = Variable<String>(pictoKey.value);
    }
    if (inCatalogue.present) {
      map['in_catalogue'] = Variable<bool>(inCatalogue.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ArticlesCompanion(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('name: $name, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('rayon: $rayon, ')
          ..write('unit: $unit, ')
          ..write('pictoKey: $pictoKey, ')
          ..write('inCatalogue: $inCatalogue, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FrequentsTable extends Frequents
    with TableInfo<$FrequentsTable, Frequent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FrequentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _articleIdMeta = const VerificationMeta(
    'articleId',
  );
  @override
  late final GeneratedColumn<String> articleId = GeneratedColumn<String>(
    'article_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES articles (id)',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    updatedAt,
    deletedAt,
    articleId,
    position,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'frequents';
  @override
  VerificationContext validateIntegrity(
    Insertable<Frequent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('article_id')) {
      context.handle(
        _articleIdMeta,
        articleId.isAcceptableOrUnknown(data['article_id']!, _articleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_articleIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Frequent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Frequent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      articleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}article_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $FrequentsTable createAlias(String alias) {
    return $FrequentsTable(attachedDatabase, alias);
  }
}

class Frequent extends DataClass implements Insertable<Frequent> {
  final String id;
  final int updatedAt;
  final int? deletedAt;
  final String articleId;

  /// Ordre dans le rayon ; un fréquent ajouté ou déplacé passe en dernier.
  final int position;
  const Frequent({
    required this.id,
    required this.updatedAt,
    this.deletedAt,
    required this.articleId,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['article_id'] = Variable<String>(articleId);
    map['position'] = Variable<int>(position);
    return map;
  }

  FrequentsCompanion toCompanion(bool nullToAbsent) {
    return FrequentsCompanion(
      id: Value(id),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      articleId: Value(articleId),
      position: Value(position),
    );
  }

  factory Frequent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Frequent(
      id: serializer.fromJson<String>(json['id']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      articleId: serializer.fromJson<String>(json['articleId']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'articleId': serializer.toJson<String>(articleId),
      'position': serializer.toJson<int>(position),
    };
  }

  Frequent copyWith({
    String? id,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    String? articleId,
    int? position,
  }) => Frequent(
    id: id ?? this.id,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    articleId: articleId ?? this.articleId,
    position: position ?? this.position,
  );
  Frequent copyWithCompanion(FrequentsCompanion data) {
    return Frequent(
      id: data.id.present ? data.id.value : this.id,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      articleId: data.articleId.present ? data.articleId.value : this.articleId,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Frequent(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('articleId: $articleId, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, updatedAt, deletedAt, articleId, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Frequent &&
          other.id == this.id &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.articleId == this.articleId &&
          other.position == this.position);
}

class FrequentsCompanion extends UpdateCompanion<Frequent> {
  final Value<String> id;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<String> articleId;
  final Value<int> position;
  final Value<int> rowid;
  const FrequentsCompanion({
    this.id = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.articleId = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FrequentsCompanion.insert({
    required String id,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    required String articleId,
    required int position,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       updatedAt = Value(updatedAt),
       articleId = Value(articleId),
       position = Value(position);
  static Insertable<Frequent> custom({
    Expression<String>? id,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<String>? articleId,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (articleId != null) 'article_id': articleId,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FrequentsCompanion copyWith({
    Value<String>? id,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<String>? articleId,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return FrequentsCompanion(
      id: id ?? this.id,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      articleId: articleId ?? this.articleId,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (articleId.present) {
      map['article_id'] = Variable<String>(articleId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FrequentsCompanion(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('articleId: $articleId, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ListLinesTable extends ListLines
    with TableInfo<$ListLinesTable, ListLine> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ListLinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _articleIdMeta = const VerificationMeta(
    'articleId',
  );
  @override
  late final GeneratedColumn<String> articleId = GeneratedColumn<String>(
    'article_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES articles (id)',
    ),
  );
  static const VerificationMeta _rayonMeta = const VerificationMeta('rayon');
  @override
  late final GeneratedColumn<String> rayon = GeneratedColumn<String>(
    'rayon',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<int> addedAt = GeneratedColumn<int>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _checkedAtMeta = const VerificationMeta(
    'checkedAt',
  );
  @override
  late final GeneratedColumn<int> checkedAt = GeneratedColumn<int>(
    'checked_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _manualAtMeta = const VerificationMeta(
    'manualAt',
  );
  @override
  late final GeneratedColumn<int> manualAt = GeneratedColumn<int>(
    'manual_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    updatedAt,
    deletedAt,
    articleId,
    rayon,
    unit,
    addedAt,
    checkedAt,
    manualAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'list_lines';
  @override
  VerificationContext validateIntegrity(
    Insertable<ListLine> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('article_id')) {
      context.handle(
        _articleIdMeta,
        articleId.isAcceptableOrUnknown(data['article_id']!, _articleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_articleIdMeta);
    }
    if (data.containsKey('rayon')) {
      context.handle(
        _rayonMeta,
        rayon.isAcceptableOrUnknown(data['rayon']!, _rayonMeta),
      );
    } else if (isInserting) {
      context.missing(_rayonMeta);
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    if (data.containsKey('checked_at')) {
      context.handle(
        _checkedAtMeta,
        checkedAt.isAcceptableOrUnknown(data['checked_at']!, _checkedAtMeta),
      );
    }
    if (data.containsKey('manual_at')) {
      context.handle(
        _manualAtMeta,
        manualAt.isAcceptableOrUnknown(data['manual_at']!, _manualAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ListLine map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ListLine(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      articleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}article_id'],
      )!,
      rayon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rayon'],
      )!,
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added_at'],
      )!,
      checkedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}checked_at'],
      ),
      manualAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}manual_at'],
      ),
    );
  }

  @override
  $ListLinesTable createAlias(String alias) {
    return $ListLinesTable(attachedDatabase, alias);
  }
}

class ListLine extends DataClass implements Insertable<ListLine> {
  final String id;
  final int updatedAt;
  final int? deletedAt;
  final String articleId;

  /// Rayon copié de l'article à la création (AD-15).
  final String rayon;

  /// Unité de la ligne, nulle sans quantité ; `unit_key` vaut l'unité ou `-`.
  final String? unit;

  /// Fixé à la création, ne change jamais ; ordonne les lignes (AD-4).
  final int addedAt;
  final int? checkedAt;

  /// Fixé quand la quantité est corrigée à la main (AD-5).
  final int? manualAt;
  const ListLine({
    required this.id,
    required this.updatedAt,
    this.deletedAt,
    required this.articleId,
    required this.rayon,
    this.unit,
    required this.addedAt,
    this.checkedAt,
    this.manualAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['article_id'] = Variable<String>(articleId);
    map['rayon'] = Variable<String>(rayon);
    if (!nullToAbsent || unit != null) {
      map['unit'] = Variable<String>(unit);
    }
    map['added_at'] = Variable<int>(addedAt);
    if (!nullToAbsent || checkedAt != null) {
      map['checked_at'] = Variable<int>(checkedAt);
    }
    if (!nullToAbsent || manualAt != null) {
      map['manual_at'] = Variable<int>(manualAt);
    }
    return map;
  }

  ListLinesCompanion toCompanion(bool nullToAbsent) {
    return ListLinesCompanion(
      id: Value(id),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      articleId: Value(articleId),
      rayon: Value(rayon),
      unit: unit == null && nullToAbsent ? const Value.absent() : Value(unit),
      addedAt: Value(addedAt),
      checkedAt: checkedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(checkedAt),
      manualAt: manualAt == null && nullToAbsent
          ? const Value.absent()
          : Value(manualAt),
    );
  }

  factory ListLine.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ListLine(
      id: serializer.fromJson<String>(json['id']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      articleId: serializer.fromJson<String>(json['articleId']),
      rayon: serializer.fromJson<String>(json['rayon']),
      unit: serializer.fromJson<String?>(json['unit']),
      addedAt: serializer.fromJson<int>(json['addedAt']),
      checkedAt: serializer.fromJson<int?>(json['checkedAt']),
      manualAt: serializer.fromJson<int?>(json['manualAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'articleId': serializer.toJson<String>(articleId),
      'rayon': serializer.toJson<String>(rayon),
      'unit': serializer.toJson<String?>(unit),
      'addedAt': serializer.toJson<int>(addedAt),
      'checkedAt': serializer.toJson<int?>(checkedAt),
      'manualAt': serializer.toJson<int?>(manualAt),
    };
  }

  ListLine copyWith({
    String? id,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    String? articleId,
    String? rayon,
    Value<String?> unit = const Value.absent(),
    int? addedAt,
    Value<int?> checkedAt = const Value.absent(),
    Value<int?> manualAt = const Value.absent(),
  }) => ListLine(
    id: id ?? this.id,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    articleId: articleId ?? this.articleId,
    rayon: rayon ?? this.rayon,
    unit: unit.present ? unit.value : this.unit,
    addedAt: addedAt ?? this.addedAt,
    checkedAt: checkedAt.present ? checkedAt.value : this.checkedAt,
    manualAt: manualAt.present ? manualAt.value : this.manualAt,
  );
  ListLine copyWithCompanion(ListLinesCompanion data) {
    return ListLine(
      id: data.id.present ? data.id.value : this.id,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      articleId: data.articleId.present ? data.articleId.value : this.articleId,
      rayon: data.rayon.present ? data.rayon.value : this.rayon,
      unit: data.unit.present ? data.unit.value : this.unit,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      checkedAt: data.checkedAt.present ? data.checkedAt.value : this.checkedAt,
      manualAt: data.manualAt.present ? data.manualAt.value : this.manualAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ListLine(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('articleId: $articleId, ')
          ..write('rayon: $rayon, ')
          ..write('unit: $unit, ')
          ..write('addedAt: $addedAt, ')
          ..write('checkedAt: $checkedAt, ')
          ..write('manualAt: $manualAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    updatedAt,
    deletedAt,
    articleId,
    rayon,
    unit,
    addedAt,
    checkedAt,
    manualAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ListLine &&
          other.id == this.id &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.articleId == this.articleId &&
          other.rayon == this.rayon &&
          other.unit == this.unit &&
          other.addedAt == this.addedAt &&
          other.checkedAt == this.checkedAt &&
          other.manualAt == this.manualAt);
}

class ListLinesCompanion extends UpdateCompanion<ListLine> {
  final Value<String> id;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<String> articleId;
  final Value<String> rayon;
  final Value<String?> unit;
  final Value<int> addedAt;
  final Value<int?> checkedAt;
  final Value<int?> manualAt;
  final Value<int> rowid;
  const ListLinesCompanion({
    this.id = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.articleId = const Value.absent(),
    this.rayon = const Value.absent(),
    this.unit = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.checkedAt = const Value.absent(),
    this.manualAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ListLinesCompanion.insert({
    required String id,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    required String articleId,
    required String rayon,
    this.unit = const Value.absent(),
    required int addedAt,
    this.checkedAt = const Value.absent(),
    this.manualAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       updatedAt = Value(updatedAt),
       articleId = Value(articleId),
       rayon = Value(rayon),
       addedAt = Value(addedAt);
  static Insertable<ListLine> custom({
    Expression<String>? id,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<String>? articleId,
    Expression<String>? rayon,
    Expression<String>? unit,
    Expression<int>? addedAt,
    Expression<int>? checkedAt,
    Expression<int>? manualAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (articleId != null) 'article_id': articleId,
      if (rayon != null) 'rayon': rayon,
      if (unit != null) 'unit': unit,
      if (addedAt != null) 'added_at': addedAt,
      if (checkedAt != null) 'checked_at': checkedAt,
      if (manualAt != null) 'manual_at': manualAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ListLinesCompanion copyWith({
    Value<String>? id,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<String>? articleId,
    Value<String>? rayon,
    Value<String?>? unit,
    Value<int>? addedAt,
    Value<int?>? checkedAt,
    Value<int?>? manualAt,
    Value<int>? rowid,
  }) {
    return ListLinesCompanion(
      id: id ?? this.id,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      articleId: articleId ?? this.articleId,
      rayon: rayon ?? this.rayon,
      unit: unit ?? this.unit,
      addedAt: addedAt ?? this.addedAt,
      checkedAt: checkedAt ?? this.checkedAt,
      manualAt: manualAt ?? this.manualAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (articleId.present) {
      map['article_id'] = Variable<String>(articleId.value);
    }
    if (rayon.present) {
      map['rayon'] = Variable<String>(rayon.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<int>(addedAt.value);
    }
    if (checkedAt.present) {
      map['checked_at'] = Variable<int>(checkedAt.value);
    }
    if (manualAt.present) {
      map['manual_at'] = Variable<int>(manualAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ListLinesCompanion(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('articleId: $articleId, ')
          ..write('rayon: $rayon, ')
          ..write('unit: $unit, ')
          ..write('addedAt: $addedAt, ')
          ..write('checkedAt: $checkedAt, ')
          ..write('manualAt: $manualAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ListContributionsTable extends ListContributions
    with TableInfo<$ListContributionsTable, ListContribution> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ListContributionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lineIdMeta = const VerificationMeta('lineId');
  @override
  late final GeneratedColumn<String> lineId = GeneratedColumn<String>(
    'line_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES list_lines (id)',
    ),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weekSelectionIdMeta = const VerificationMeta(
    'weekSelectionId',
  );
  @override
  late final GeneratedColumn<String> weekSelectionId = GeneratedColumn<String>(
    'week_selection_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
    'quantity',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    updatedAt,
    deletedAt,
    lineId,
    source,
    weekSelectionId,
    quantity,
    unit,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'list_contributions';
  @override
  VerificationContext validateIntegrity(
    Insertable<ListContribution> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('line_id')) {
      context.handle(
        _lineIdMeta,
        lineId.isAcceptableOrUnknown(data['line_id']!, _lineIdMeta),
      );
    } else if (isInserting) {
      context.missing(_lineIdMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('week_selection_id')) {
      context.handle(
        _weekSelectionIdMeta,
        weekSelectionId.isAcceptableOrUnknown(
          data['week_selection_id']!,
          _weekSelectionIdMeta,
        ),
      );
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ListContribution map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ListContribution(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      lineId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}line_id'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      weekSelectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}week_selection_id'],
      ),
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantity'],
      ),
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      ),
    );
  }

  @override
  $ListContributionsTable createAlias(String alias) {
    return $ListContributionsTable(attachedDatabase, alias);
  }
}

class ListContribution extends DataClass
    implements Insertable<ListContribution> {
  final String id;
  final int updatedAt;
  final int? deletedAt;

  /// Parent de la contribution : sa ligne, pas sa source (AD-7).
  final String lineId;

  /// `week_selection`, `ajout` (Panneau +) ou `edition` (AD-4, AD-5).
  final String source;

  /// Sélection de recette validée quand [source] vaut `week_selection`.
  final String? weekSelectionId;

  /// Entier (g, ml ou millièmes de pièce), nul avec [unit] (AD-6).
  final int? quantity;
  final String? unit;
  const ListContribution({
    required this.id,
    required this.updatedAt,
    this.deletedAt,
    required this.lineId,
    required this.source,
    this.weekSelectionId,
    this.quantity,
    this.unit,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['line_id'] = Variable<String>(lineId);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || weekSelectionId != null) {
      map['week_selection_id'] = Variable<String>(weekSelectionId);
    }
    if (!nullToAbsent || quantity != null) {
      map['quantity'] = Variable<int>(quantity);
    }
    if (!nullToAbsent || unit != null) {
      map['unit'] = Variable<String>(unit);
    }
    return map;
  }

  ListContributionsCompanion toCompanion(bool nullToAbsent) {
    return ListContributionsCompanion(
      id: Value(id),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      lineId: Value(lineId),
      source: Value(source),
      weekSelectionId: weekSelectionId == null && nullToAbsent
          ? const Value.absent()
          : Value(weekSelectionId),
      quantity: quantity == null && nullToAbsent
          ? const Value.absent()
          : Value(quantity),
      unit: unit == null && nullToAbsent ? const Value.absent() : Value(unit),
    );
  }

  factory ListContribution.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ListContribution(
      id: serializer.fromJson<String>(json['id']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      lineId: serializer.fromJson<String>(json['lineId']),
      source: serializer.fromJson<String>(json['source']),
      weekSelectionId: serializer.fromJson<String?>(json['weekSelectionId']),
      quantity: serializer.fromJson<int?>(json['quantity']),
      unit: serializer.fromJson<String?>(json['unit']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'lineId': serializer.toJson<String>(lineId),
      'source': serializer.toJson<String>(source),
      'weekSelectionId': serializer.toJson<String?>(weekSelectionId),
      'quantity': serializer.toJson<int?>(quantity),
      'unit': serializer.toJson<String?>(unit),
    };
  }

  ListContribution copyWith({
    String? id,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    String? lineId,
    String? source,
    Value<String?> weekSelectionId = const Value.absent(),
    Value<int?> quantity = const Value.absent(),
    Value<String?> unit = const Value.absent(),
  }) => ListContribution(
    id: id ?? this.id,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    lineId: lineId ?? this.lineId,
    source: source ?? this.source,
    weekSelectionId: weekSelectionId.present
        ? weekSelectionId.value
        : this.weekSelectionId,
    quantity: quantity.present ? quantity.value : this.quantity,
    unit: unit.present ? unit.value : this.unit,
  );
  ListContribution copyWithCompanion(ListContributionsCompanion data) {
    return ListContribution(
      id: data.id.present ? data.id.value : this.id,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      lineId: data.lineId.present ? data.lineId.value : this.lineId,
      source: data.source.present ? data.source.value : this.source,
      weekSelectionId: data.weekSelectionId.present
          ? data.weekSelectionId.value
          : this.weekSelectionId,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      unit: data.unit.present ? data.unit.value : this.unit,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ListContribution(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('lineId: $lineId, ')
          ..write('source: $source, ')
          ..write('weekSelectionId: $weekSelectionId, ')
          ..write('quantity: $quantity, ')
          ..write('unit: $unit')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    updatedAt,
    deletedAt,
    lineId,
    source,
    weekSelectionId,
    quantity,
    unit,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ListContribution &&
          other.id == this.id &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.lineId == this.lineId &&
          other.source == this.source &&
          other.weekSelectionId == this.weekSelectionId &&
          other.quantity == this.quantity &&
          other.unit == this.unit);
}

class ListContributionsCompanion extends UpdateCompanion<ListContribution> {
  final Value<String> id;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<String> lineId;
  final Value<String> source;
  final Value<String?> weekSelectionId;
  final Value<int?> quantity;
  final Value<String?> unit;
  final Value<int> rowid;
  const ListContributionsCompanion({
    this.id = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.lineId = const Value.absent(),
    this.source = const Value.absent(),
    this.weekSelectionId = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unit = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ListContributionsCompanion.insert({
    required String id,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    required String lineId,
    required String source,
    this.weekSelectionId = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unit = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       updatedAt = Value(updatedAt),
       lineId = Value(lineId),
       source = Value(source);
  static Insertable<ListContribution> custom({
    Expression<String>? id,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<String>? lineId,
    Expression<String>? source,
    Expression<String>? weekSelectionId,
    Expression<int>? quantity,
    Expression<String>? unit,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (lineId != null) 'line_id': lineId,
      if (source != null) 'source': source,
      if (weekSelectionId != null) 'week_selection_id': weekSelectionId,
      if (quantity != null) 'quantity': quantity,
      if (unit != null) 'unit': unit,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ListContributionsCompanion copyWith({
    Value<String>? id,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<String>? lineId,
    Value<String>? source,
    Value<String?>? weekSelectionId,
    Value<int?>? quantity,
    Value<String?>? unit,
    Value<int>? rowid,
  }) {
    return ListContributionsCompanion(
      id: id ?? this.id,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      lineId: lineId ?? this.lineId,
      source: source ?? this.source,
      weekSelectionId: weekSelectionId ?? this.weekSelectionId,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (lineId.present) {
      map['line_id'] = Variable<String>(lineId.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (weekSelectionId.present) {
      map['week_selection_id'] = Variable<String>(weekSelectionId.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ListContributionsCompanion(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('lineId: $lineId, ')
          ..write('source: $source, ')
          ..write('weekSelectionId: $weekSelectionId, ')
          ..write('quantity: $quantity, ')
          ..write('unit: $unit, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings
    with TableInfo<$SettingsTable, SettingsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _routeOrderMeta = const VerificationMeta(
    'routeOrder',
  );
  @override
  late final GeneratedColumn<String> routeOrder = GeneratedColumn<String>(
    'route_order',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupByRayonMeta = const VerificationMeta(
    'groupByRayon',
  );
  @override
  late final GeneratedColumn<bool> groupByRayon = GeneratedColumn<bool>(
    'group_by_rayon',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("group_by_rayon" IN (0, 1))',
    ),
  );
  static const VerificationMeta _keepScreenOnMeta = const VerificationMeta(
    'keepScreenOn',
  );
  @override
  late final GeneratedColumn<bool> keepScreenOn = GeneratedColumn<bool>(
    'keep_screen_on',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("keep_screen_on" IN (0, 1))',
    ),
  );
  static const VerificationMeta _firstLaunchMeta = const VerificationMeta(
    'firstLaunch',
  );
  @override
  late final GeneratedColumn<bool> firstLaunch = GeneratedColumn<bool>(
    'first_launch',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("first_launch" IN (0, 1))',
    ),
  );
  static const VerificationMeta _seedVersionsMeta = const VerificationMeta(
    'seedVersions',
  );
  @override
  late final GeneratedColumn<String> seedVersions = GeneratedColumn<String>(
    'seed_versions',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    updatedAt,
    deletedAt,
    routeOrder,
    groupByRayon,
    keepScreenOn,
    firstLaunch,
    seedVersions,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('route_order')) {
      context.handle(
        _routeOrderMeta,
        routeOrder.isAcceptableOrUnknown(data['route_order']!, _routeOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_routeOrderMeta);
    }
    if (data.containsKey('group_by_rayon')) {
      context.handle(
        _groupByRayonMeta,
        groupByRayon.isAcceptableOrUnknown(
          data['group_by_rayon']!,
          _groupByRayonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_groupByRayonMeta);
    }
    if (data.containsKey('keep_screen_on')) {
      context.handle(
        _keepScreenOnMeta,
        keepScreenOn.isAcceptableOrUnknown(
          data['keep_screen_on']!,
          _keepScreenOnMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_keepScreenOnMeta);
    }
    if (data.containsKey('first_launch')) {
      context.handle(
        _firstLaunchMeta,
        firstLaunch.isAcceptableOrUnknown(
          data['first_launch']!,
          _firstLaunchMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_firstLaunchMeta);
    }
    if (data.containsKey('seed_versions')) {
      context.handle(
        _seedVersionsMeta,
        seedVersions.isAcceptableOrUnknown(
          data['seed_versions']!,
          _seedVersionsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_seedVersionsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SettingsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingsRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      routeOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}route_order'],
      )!,
      groupByRayon: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}group_by_rayon'],
      )!,
      keepScreenOn: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}keep_screen_on'],
      )!,
      firstLaunch: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}first_launch'],
      )!,
      seedVersions: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}seed_versions'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class SettingsRow extends DataClass implements Insertable<SettingsRow> {
  final String id;
  final int updatedAt;
  final int? deletedAt;

  /// Les 13 codes de rayon d'AD-11, dans l'ordre du parcours, séparés par `,`.
  final String routeOrder;
  final bool groupByRayon;
  final bool keepScreenOn;

  /// Levé par le chargeur après l'insertion des recettes exemples (AD-13).
  final bool firstLaunch;

  /// `seed_version` par fichier de `assets/seed/`, en JSON
  /// (`{"articles": 1}`) (AD-8).
  final String seedVersions;
  const SettingsRow({
    required this.id,
    required this.updatedAt,
    this.deletedAt,
    required this.routeOrder,
    required this.groupByRayon,
    required this.keepScreenOn,
    required this.firstLaunch,
    required this.seedVersions,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['route_order'] = Variable<String>(routeOrder);
    map['group_by_rayon'] = Variable<bool>(groupByRayon);
    map['keep_screen_on'] = Variable<bool>(keepScreenOn);
    map['first_launch'] = Variable<bool>(firstLaunch);
    map['seed_versions'] = Variable<String>(seedVersions);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      id: Value(id),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      routeOrder: Value(routeOrder),
      groupByRayon: Value(groupByRayon),
      keepScreenOn: Value(keepScreenOn),
      firstLaunch: Value(firstLaunch),
      seedVersions: Value(seedVersions),
    );
  }

  factory SettingsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingsRow(
      id: serializer.fromJson<String>(json['id']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      routeOrder: serializer.fromJson<String>(json['routeOrder']),
      groupByRayon: serializer.fromJson<bool>(json['groupByRayon']),
      keepScreenOn: serializer.fromJson<bool>(json['keepScreenOn']),
      firstLaunch: serializer.fromJson<bool>(json['firstLaunch']),
      seedVersions: serializer.fromJson<String>(json['seedVersions']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'routeOrder': serializer.toJson<String>(routeOrder),
      'groupByRayon': serializer.toJson<bool>(groupByRayon),
      'keepScreenOn': serializer.toJson<bool>(keepScreenOn),
      'firstLaunch': serializer.toJson<bool>(firstLaunch),
      'seedVersions': serializer.toJson<String>(seedVersions),
    };
  }

  SettingsRow copyWith({
    String? id,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    String? routeOrder,
    bool? groupByRayon,
    bool? keepScreenOn,
    bool? firstLaunch,
    String? seedVersions,
  }) => SettingsRow(
    id: id ?? this.id,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    routeOrder: routeOrder ?? this.routeOrder,
    groupByRayon: groupByRayon ?? this.groupByRayon,
    keepScreenOn: keepScreenOn ?? this.keepScreenOn,
    firstLaunch: firstLaunch ?? this.firstLaunch,
    seedVersions: seedVersions ?? this.seedVersions,
  );
  SettingsRow copyWithCompanion(SettingsCompanion data) {
    return SettingsRow(
      id: data.id.present ? data.id.value : this.id,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      routeOrder: data.routeOrder.present
          ? data.routeOrder.value
          : this.routeOrder,
      groupByRayon: data.groupByRayon.present
          ? data.groupByRayon.value
          : this.groupByRayon,
      keepScreenOn: data.keepScreenOn.present
          ? data.keepScreenOn.value
          : this.keepScreenOn,
      firstLaunch: data.firstLaunch.present
          ? data.firstLaunch.value
          : this.firstLaunch,
      seedVersions: data.seedVersions.present
          ? data.seedVersions.value
          : this.seedVersions,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingsRow(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('routeOrder: $routeOrder, ')
          ..write('groupByRayon: $groupByRayon, ')
          ..write('keepScreenOn: $keepScreenOn, ')
          ..write('firstLaunch: $firstLaunch, ')
          ..write('seedVersions: $seedVersions')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    updatedAt,
    deletedAt,
    routeOrder,
    groupByRayon,
    keepScreenOn,
    firstLaunch,
    seedVersions,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingsRow &&
          other.id == this.id &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.routeOrder == this.routeOrder &&
          other.groupByRayon == this.groupByRayon &&
          other.keepScreenOn == this.keepScreenOn &&
          other.firstLaunch == this.firstLaunch &&
          other.seedVersions == this.seedVersions);
}

class SettingsCompanion extends UpdateCompanion<SettingsRow> {
  final Value<String> id;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<String> routeOrder;
  final Value<bool> groupByRayon;
  final Value<bool> keepScreenOn;
  final Value<bool> firstLaunch;
  final Value<String> seedVersions;
  final Value<int> rowid;
  const SettingsCompanion({
    this.id = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.routeOrder = const Value.absent(),
    this.groupByRayon = const Value.absent(),
    this.keepScreenOn = const Value.absent(),
    this.firstLaunch = const Value.absent(),
    this.seedVersions = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String id,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    required String routeOrder,
    required bool groupByRayon,
    required bool keepScreenOn,
    required bool firstLaunch,
    required String seedVersions,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       updatedAt = Value(updatedAt),
       routeOrder = Value(routeOrder),
       groupByRayon = Value(groupByRayon),
       keepScreenOn = Value(keepScreenOn),
       firstLaunch = Value(firstLaunch),
       seedVersions = Value(seedVersions);
  static Insertable<SettingsRow> custom({
    Expression<String>? id,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<String>? routeOrder,
    Expression<bool>? groupByRayon,
    Expression<bool>? keepScreenOn,
    Expression<bool>? firstLaunch,
    Expression<String>? seedVersions,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (routeOrder != null) 'route_order': routeOrder,
      if (groupByRayon != null) 'group_by_rayon': groupByRayon,
      if (keepScreenOn != null) 'keep_screen_on': keepScreenOn,
      if (firstLaunch != null) 'first_launch': firstLaunch,
      if (seedVersions != null) 'seed_versions': seedVersions,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? id,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<String>? routeOrder,
    Value<bool>? groupByRayon,
    Value<bool>? keepScreenOn,
    Value<bool>? firstLaunch,
    Value<String>? seedVersions,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      id: id ?? this.id,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      routeOrder: routeOrder ?? this.routeOrder,
      groupByRayon: groupByRayon ?? this.groupByRayon,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      firstLaunch: firstLaunch ?? this.firstLaunch,
      seedVersions: seedVersions ?? this.seedVersions,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (routeOrder.present) {
      map['route_order'] = Variable<String>(routeOrder.value);
    }
    if (groupByRayon.present) {
      map['group_by_rayon'] = Variable<bool>(groupByRayon.value);
    }
    if (keepScreenOn.present) {
      map['keep_screen_on'] = Variable<bool>(keepScreenOn.value);
    }
    if (firstLaunch.present) {
      map['first_launch'] = Variable<bool>(firstLaunch.value);
    }
    if (seedVersions.present) {
      map['seed_versions'] = Variable<String>(seedVersions.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('routeOrder: $routeOrder, ')
          ..write('groupByRayon: $groupByRayon, ')
          ..write('keepScreenOn: $keepScreenOn, ')
          ..write('firstLaunch: $firstLaunch, ')
          ..write('seedVersions: $seedVersions, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ArticlesTable articles = $ArticlesTable(this);
  late final $FrequentsTable frequents = $FrequentsTable(this);
  late final $ListLinesTable listLines = $ListLinesTable(this);
  late final $ListContributionsTable listContributions =
      $ListContributionsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    articles,
    frequents,
    listLines,
    listContributions,
    settings,
  ];
}

typedef $$ArticlesTableCreateCompanionBuilder = ArticlesCompanion Function({
  required String id,
  required int updatedAt,
  Value<int?> deletedAt,
  required String name,
  required String normalizedName,
  required String rayon,
  Value<String?> unit,
  required String pictoKey,
  Value<bool> inCatalogue,
  Value<int> rowid,
});
typedef $$ArticlesTableUpdateCompanionBuilder = ArticlesCompanion Function({
  Value<String> id,
  Value<int> updatedAt,
  Value<int?> deletedAt,
  Value<String> name,
  Value<String> normalizedName,
  Value<String> rayon,
  Value<String?> unit,
  Value<String> pictoKey,
  Value<bool> inCatalogue,
  Value<int> rowid,
});

final class $$ArticlesTableReferences
    extends BaseReferences<_$AppDatabase, $ArticlesTable, Article> {
  $$ArticlesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$FrequentsTable, List<Frequent>>
  _frequentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.frequents,
    aliasName: 'articles__id__frequents__article_id',
  );

  $$FrequentsTableProcessedTableManager get frequentsRefs {
    final manager = $$FrequentsTableTableManager(
      $_db,
      $_db.frequents,
    ).filter((f) => f.articleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_frequentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ListLinesTable, List<ListLine>>
  _listLinesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.listLines,
    aliasName: 'articles__id__list_lines__article_id',
  );

  $$ListLinesTableProcessedTableManager get listLinesRefs {
    final manager = $$ListLinesTableTableManager(
      $_db,
      $_db.listLines,
    ).filter((f) => f.articleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_listLinesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ArticlesTableFilterComposer
    extends Composer<_$AppDatabase, $ArticlesTable> {
  $$ArticlesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rayon => $composableBuilder(
    column: $table.rayon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pictoKey => $composableBuilder(
    column: $table.pictoKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get inCatalogue => $composableBuilder(
    column: $table.inCatalogue,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> frequentsRefs(
    Expression<bool> Function($$FrequentsTableFilterComposer f) f,
  ) {
    final $$FrequentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.frequents,
      getReferencedColumn: (t) => t.articleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FrequentsTableFilterComposer(
            $db: $db,
            $table: $db.frequents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> listLinesRefs(
    Expression<bool> Function($$ListLinesTableFilterComposer f) f,
  ) {
    final $$ListLinesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.listLines,
      getReferencedColumn: (t) => t.articleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ListLinesTableFilterComposer(
            $db: $db,
            $table: $db.listLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ArticlesTableOrderingComposer
    extends Composer<_$AppDatabase, $ArticlesTable> {
  $$ArticlesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rayon => $composableBuilder(
    column: $table.rayon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pictoKey => $composableBuilder(
    column: $table.pictoKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get inCatalogue => $composableBuilder(
    column: $table.inCatalogue,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ArticlesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ArticlesTable> {
  $$ArticlesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rayon =>
      $composableBuilder(column: $table.rayon, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<String> get pictoKey =>
      $composableBuilder(column: $table.pictoKey, builder: (column) => column);

  GeneratedColumn<bool> get inCatalogue => $composableBuilder(
    column: $table.inCatalogue,
    builder: (column) => column,
  );

  Expression<T> frequentsRefs<T extends Object>(
    Expression<T> Function($$FrequentsTableAnnotationComposer a) f,
  ) {
    final $$FrequentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.frequents,
      getReferencedColumn: (t) => t.articleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FrequentsTableAnnotationComposer(
            $db: $db,
            $table: $db.frequents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> listLinesRefs<T extends Object>(
    Expression<T> Function($$ListLinesTableAnnotationComposer a) f,
  ) {
    final $$ListLinesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.listLines,
      getReferencedColumn: (t) => t.articleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ListLinesTableAnnotationComposer(
            $db: $db,
            $table: $db.listLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ArticlesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ArticlesTable,
          Article,
          $$ArticlesTableFilterComposer,
          $$ArticlesTableOrderingComposer,
          $$ArticlesTableAnnotationComposer,
          $$ArticlesTableCreateCompanionBuilder,
          $$ArticlesTableUpdateCompanionBuilder,
          (Article, $$ArticlesTableReferences),
          Article,
          PrefetchHooks Function({bool frequentsRefs, bool listLinesRefs})
        > {
  $$ArticlesTableTableManager(_$AppDatabase db, $ArticlesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ArticlesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ArticlesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ArticlesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> normalizedName = const Value.absent(),
                Value<String> rayon = const Value.absent(),
                Value<String?> unit = const Value.absent(),
                Value<String> pictoKey = const Value.absent(),
                Value<bool> inCatalogue = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ArticlesCompanion(
                id: id,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                name: name,
                normalizedName: normalizedName,
                rayon: rayon,
                unit: unit,
                pictoKey: pictoKey,
                inCatalogue: inCatalogue,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                required String name,
                required String normalizedName,
                required String rayon,
                Value<String?> unit = const Value.absent(),
                required String pictoKey,
                Value<bool> inCatalogue = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ArticlesCompanion.insert(
                id: id,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                name: name,
                normalizedName: normalizedName,
                rayon: rayon,
                unit: unit,
                pictoKey: pictoKey,
                inCatalogue: inCatalogue,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ArticlesTable, Article>(table),
                  $$ArticlesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({frequentsRefs = false, listLinesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (frequentsRefs) db.frequents,
                    if (listLinesRefs) db.listLines,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (frequentsRefs)
                        await $_getPrefetchedDataByColumns<
                          Article,
                          $ArticlesTable,
                          Frequent,
                          $FrequentsTable
                        >(
                          currentTable: table,
                          referencedTable: $$ArticlesTableReferences
                              ._frequentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ArticlesTableReferences(
                                db,
                                table,
                                p0,
                              ).frequentsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'article_id',
                          typedResults: items,
                        ),
                      if (listLinesRefs)
                        await $_getPrefetchedDataByColumns<
                          Article,
                          $ArticlesTable,
                          ListLine,
                          $ListLinesTable
                        >(
                          currentTable: table,
                          referencedTable: $$ArticlesTableReferences
                              ._listLinesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ArticlesTableReferences(
                                db,
                                table,
                                p0,
                              ).listLinesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'article_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ArticlesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ArticlesTable,
      Article,
      $$ArticlesTableFilterComposer,
      $$ArticlesTableOrderingComposer,
      $$ArticlesTableAnnotationComposer,
      $$ArticlesTableCreateCompanionBuilder,
      $$ArticlesTableUpdateCompanionBuilder,
      (Article, $$ArticlesTableReferences),
      Article,
      PrefetchHooks Function({bool frequentsRefs, bool listLinesRefs})
    >;
typedef $$FrequentsTableCreateCompanionBuilder = FrequentsCompanion Function({
  required String id,
  required int updatedAt,
  Value<int?> deletedAt,
  required String articleId,
  required int position,
  Value<int> rowid,
});
typedef $$FrequentsTableUpdateCompanionBuilder = FrequentsCompanion Function({
  Value<String> id,
  Value<int> updatedAt,
  Value<int?> deletedAt,
  Value<String> articleId,
  Value<int> position,
  Value<int> rowid,
});

final class $$FrequentsTableReferences
    extends BaseReferences<_$AppDatabase, $FrequentsTable, Frequent> {
  $$FrequentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ArticlesTable _articleIdTable(_$AppDatabase db) =>
      db.articles.createAlias('frequents__article_id__articles__id');

  $$ArticlesTableProcessedTableManager get articleId {
    final $_column = $_itemColumn<String>('article_id')!;

    final manager = $$ArticlesTableTableManager(
      $_db,
      $_db.articles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_articleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FrequentsTableFilterComposer
    extends Composer<_$AppDatabase, $FrequentsTable> {
  $$FrequentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  $$ArticlesTableFilterComposer get articleId {
    final $$ArticlesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.articleId,
      referencedTable: $db.articles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticlesTableFilterComposer(
            $db: $db,
            $table: $db.articles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FrequentsTableOrderingComposer
    extends Composer<_$AppDatabase, $FrequentsTable> {
  $$FrequentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  $$ArticlesTableOrderingComposer get articleId {
    final $$ArticlesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.articleId,
      referencedTable: $db.articles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticlesTableOrderingComposer(
            $db: $db,
            $table: $db.articles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FrequentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FrequentsTable> {
  $$FrequentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  $$ArticlesTableAnnotationComposer get articleId {
    final $$ArticlesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.articleId,
      referencedTable: $db.articles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticlesTableAnnotationComposer(
            $db: $db,
            $table: $db.articles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FrequentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FrequentsTable,
          Frequent,
          $$FrequentsTableFilterComposer,
          $$FrequentsTableOrderingComposer,
          $$FrequentsTableAnnotationComposer,
          $$FrequentsTableCreateCompanionBuilder,
          $$FrequentsTableUpdateCompanionBuilder,
          (Frequent, $$FrequentsTableReferences),
          Frequent,
          PrefetchHooks Function({bool articleId})
        > {
  $$FrequentsTableTableManager(_$AppDatabase db, $FrequentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FrequentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FrequentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FrequentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> articleId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FrequentsCompanion(
                id: id,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                articleId: articleId,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                required String articleId,
                required int position,
                Value<int> rowid = const Value.absent(),
              }) => FrequentsCompanion.insert(
                id: id,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                articleId: articleId,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FrequentsTable, Frequent>(table),
                  $$FrequentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({articleId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (articleId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.articleId,
                        referencedTable: $$FrequentsTableReferences
                            ._articleIdTable(db),
                        referencedColumn: $$FrequentsTableReferences
                            ._articleIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FrequentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FrequentsTable,
      Frequent,
      $$FrequentsTableFilterComposer,
      $$FrequentsTableOrderingComposer,
      $$FrequentsTableAnnotationComposer,
      $$FrequentsTableCreateCompanionBuilder,
      $$FrequentsTableUpdateCompanionBuilder,
      (Frequent, $$FrequentsTableReferences),
      Frequent,
      PrefetchHooks Function({bool articleId})
    >;
typedef $$ListLinesTableCreateCompanionBuilder = ListLinesCompanion Function({
  required String id,
  required int updatedAt,
  Value<int?> deletedAt,
  required String articleId,
  required String rayon,
  Value<String?> unit,
  required int addedAt,
  Value<int?> checkedAt,
  Value<int?> manualAt,
  Value<int> rowid,
});
typedef $$ListLinesTableUpdateCompanionBuilder = ListLinesCompanion Function({
  Value<String> id,
  Value<int> updatedAt,
  Value<int?> deletedAt,
  Value<String> articleId,
  Value<String> rayon,
  Value<String?> unit,
  Value<int> addedAt,
  Value<int?> checkedAt,
  Value<int?> manualAt,
  Value<int> rowid,
});

final class $$ListLinesTableReferences
    extends BaseReferences<_$AppDatabase, $ListLinesTable, ListLine> {
  $$ListLinesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ArticlesTable _articleIdTable(_$AppDatabase db) =>
      db.articles.createAlias('list_lines__article_id__articles__id');

  $$ArticlesTableProcessedTableManager get articleId {
    final $_column = $_itemColumn<String>('article_id')!;

    final manager = $$ArticlesTableTableManager(
      $_db,
      $_db.articles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_articleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ListContributionsTable, List<ListContribution>>
  _listContributionsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.listContributions,
        aliasName: 'list_lines__id__list_contributions__line_id',
      );

  $$ListContributionsTableProcessedTableManager get listContributionsRefs {
    final manager = $$ListContributionsTableTableManager(
      $_db,
      $_db.listContributions,
    ).filter((f) => f.lineId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _listContributionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ListLinesTableFilterComposer
    extends Composer<_$AppDatabase, $ListLinesTable> {
  $$ListLinesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rayon => $composableBuilder(
    column: $table.rayon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get checkedAt => $composableBuilder(
    column: $table.checkedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get manualAt => $composableBuilder(
    column: $table.manualAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ArticlesTableFilterComposer get articleId {
    final $$ArticlesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.articleId,
      referencedTable: $db.articles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticlesTableFilterComposer(
            $db: $db,
            $table: $db.articles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> listContributionsRefs(
    Expression<bool> Function($$ListContributionsTableFilterComposer f) f,
  ) {
    final $$ListContributionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.listContributions,
      getReferencedColumn: (t) => t.lineId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ListContributionsTableFilterComposer(
            $db: $db,
            $table: $db.listContributions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ListLinesTableOrderingComposer
    extends Composer<_$AppDatabase, $ListLinesTable> {
  $$ListLinesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rayon => $composableBuilder(
    column: $table.rayon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get checkedAt => $composableBuilder(
    column: $table.checkedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get manualAt => $composableBuilder(
    column: $table.manualAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ArticlesTableOrderingComposer get articleId {
    final $$ArticlesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.articleId,
      referencedTable: $db.articles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticlesTableOrderingComposer(
            $db: $db,
            $table: $db.articles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ListLinesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ListLinesTable> {
  $$ListLinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get rayon =>
      $composableBuilder(column: $table.rayon, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<int> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<int> get checkedAt =>
      $composableBuilder(column: $table.checkedAt, builder: (column) => column);

  GeneratedColumn<int> get manualAt =>
      $composableBuilder(column: $table.manualAt, builder: (column) => column);

  $$ArticlesTableAnnotationComposer get articleId {
    final $$ArticlesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.articleId,
      referencedTable: $db.articles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticlesTableAnnotationComposer(
            $db: $db,
            $table: $db.articles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> listContributionsRefs<T extends Object>(
    Expression<T> Function($$ListContributionsTableAnnotationComposer a) f,
  ) {
    final $$ListContributionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.listContributions,
          getReferencedColumn: (t) => t.lineId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ListContributionsTableAnnotationComposer(
                $db: $db,
                $table: $db.listContributions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ListLinesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ListLinesTable,
          ListLine,
          $$ListLinesTableFilterComposer,
          $$ListLinesTableOrderingComposer,
          $$ListLinesTableAnnotationComposer,
          $$ListLinesTableCreateCompanionBuilder,
          $$ListLinesTableUpdateCompanionBuilder,
          (ListLine, $$ListLinesTableReferences),
          ListLine,
          PrefetchHooks Function({bool articleId, bool listContributionsRefs})
        > {
  $$ListLinesTableTableManager(_$AppDatabase db, $ListLinesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ListLinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ListLinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ListLinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> articleId = const Value.absent(),
                Value<String> rayon = const Value.absent(),
                Value<String?> unit = const Value.absent(),
                Value<int> addedAt = const Value.absent(),
                Value<int?> checkedAt = const Value.absent(),
                Value<int?> manualAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ListLinesCompanion(
                id: id,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                articleId: articleId,
                rayon: rayon,
                unit: unit,
                addedAt: addedAt,
                checkedAt: checkedAt,
                manualAt: manualAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                required String articleId,
                required String rayon,
                Value<String?> unit = const Value.absent(),
                required int addedAt,
                Value<int?> checkedAt = const Value.absent(),
                Value<int?> manualAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ListLinesCompanion.insert(
                id: id,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                articleId: articleId,
                rayon: rayon,
                unit: unit,
                addedAt: addedAt,
                checkedAt: checkedAt,
                manualAt: manualAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ListLinesTable, ListLine>(table),
                  $$ListLinesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({articleId = false, listContributionsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (listContributionsRefs) db.listContributions,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (articleId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.articleId,
                            referencedTable: $$ListLinesTableReferences
                                ._articleIdTable(db),
                            referencedColumn: $$ListLinesTableReferences
                                ._articleIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (listContributionsRefs)
                        await $_getPrefetchedDataByColumns<
                          ListLine,
                          $ListLinesTable,
                          ListContribution,
                          $ListContributionsTable
                        >(
                          currentTable: table,
                          referencedTable: $$ListLinesTableReferences
                              ._listContributionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ListLinesTableReferences(
                                db,
                                table,
                                p0,
                              ).listContributionsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'line_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ListLinesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ListLinesTable,
      ListLine,
      $$ListLinesTableFilterComposer,
      $$ListLinesTableOrderingComposer,
      $$ListLinesTableAnnotationComposer,
      $$ListLinesTableCreateCompanionBuilder,
      $$ListLinesTableUpdateCompanionBuilder,
      (ListLine, $$ListLinesTableReferences),
      ListLine,
      PrefetchHooks Function({bool articleId, bool listContributionsRefs})
    >;
typedef $$ListContributionsTableCreateCompanionBuilder =
    ListContributionsCompanion Function({
      required String id,
      required int updatedAt,
      Value<int?> deletedAt,
      required String lineId,
      required String source,
      Value<String?> weekSelectionId,
      Value<int?> quantity,
      Value<String?> unit,
      Value<int> rowid,
    });
typedef $$ListContributionsTableUpdateCompanionBuilder =
    ListContributionsCompanion Function({
      Value<String> id,
      Value<int> updatedAt,
      Value<int?> deletedAt,
      Value<String> lineId,
      Value<String> source,
      Value<String?> weekSelectionId,
      Value<int?> quantity,
      Value<String?> unit,
      Value<int> rowid,
    });

final class $$ListContributionsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ListContributionsTable,
          ListContribution
        > {
  $$ListContributionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ListLinesTable _lineIdTable(_$AppDatabase db) =>
      db.listLines.createAlias('list_contributions__line_id__list_lines__id');

  $$ListLinesTableProcessedTableManager get lineId {
    final $_column = $_itemColumn<String>('line_id')!;

    final manager = $$ListLinesTableTableManager(
      $_db,
      $_db.listLines,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_lineIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ListContributionsTableFilterComposer
    extends Composer<_$AppDatabase, $ListContributionsTable> {
  $$ListContributionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get weekSelectionId => $composableBuilder(
    column: $table.weekSelectionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  $$ListLinesTableFilterComposer get lineId {
    final $$ListLinesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lineId,
      referencedTable: $db.listLines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ListLinesTableFilterComposer(
            $db: $db,
            $table: $db.listLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ListContributionsTableOrderingComposer
    extends Composer<_$AppDatabase, $ListContributionsTable> {
  $$ListContributionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get weekSelectionId => $composableBuilder(
    column: $table.weekSelectionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  $$ListLinesTableOrderingComposer get lineId {
    final $$ListLinesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lineId,
      referencedTable: $db.listLines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ListLinesTableOrderingComposer(
            $db: $db,
            $table: $db.listLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ListContributionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ListContributionsTable> {
  $$ListContributionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get weekSelectionId => $composableBuilder(
    column: $table.weekSelectionId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  $$ListLinesTableAnnotationComposer get lineId {
    final $$ListLinesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lineId,
      referencedTable: $db.listLines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ListLinesTableAnnotationComposer(
            $db: $db,
            $table: $db.listLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ListContributionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ListContributionsTable,
          ListContribution,
          $$ListContributionsTableFilterComposer,
          $$ListContributionsTableOrderingComposer,
          $$ListContributionsTableAnnotationComposer,
          $$ListContributionsTableCreateCompanionBuilder,
          $$ListContributionsTableUpdateCompanionBuilder,
          (ListContribution, $$ListContributionsTableReferences),
          ListContribution,
          PrefetchHooks Function({bool lineId})
        > {
  $$ListContributionsTableTableManager(
    _$AppDatabase db,
    $ListContributionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ListContributionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ListContributionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ListContributionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> lineId = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> weekSelectionId = const Value.absent(),
                Value<int?> quantity = const Value.absent(),
                Value<String?> unit = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ListContributionsCompanion(
                id: id,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                lineId: lineId,
                source: source,
                weekSelectionId: weekSelectionId,
                quantity: quantity,
                unit: unit,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                required String lineId,
                required String source,
                Value<String?> weekSelectionId = const Value.absent(),
                Value<int?> quantity = const Value.absent(),
                Value<String?> unit = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ListContributionsCompanion.insert(
                id: id,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                lineId: lineId,
                source: source,
                weekSelectionId: weekSelectionId,
                quantity: quantity,
                unit: unit,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ListContributionsTable, ListContribution>(table),
                  $$ListContributionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({lineId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (lineId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.lineId,
                        referencedTable: $$ListContributionsTableReferences
                            ._lineIdTable(db),
                        referencedColumn: $$ListContributionsTableReferences
                            ._lineIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ListContributionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ListContributionsTable,
      ListContribution,
      $$ListContributionsTableFilterComposer,
      $$ListContributionsTableOrderingComposer,
      $$ListContributionsTableAnnotationComposer,
      $$ListContributionsTableCreateCompanionBuilder,
      $$ListContributionsTableUpdateCompanionBuilder,
      (ListContribution, $$ListContributionsTableReferences),
      ListContribution,
      PrefetchHooks Function({bool lineId})
    >;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String id,
  required int updatedAt,
  Value<int?> deletedAt,
  required String routeOrder,
  required bool groupByRayon,
  required bool keepScreenOn,
  required bool firstLaunch,
  required String seedVersions,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> id,
  Value<int> updatedAt,
  Value<int?> deletedAt,
  Value<String> routeOrder,
  Value<bool> groupByRayon,
  Value<bool> keepScreenOn,
  Value<bool> firstLaunch,
  Value<String> seedVersions,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get routeOrder => $composableBuilder(
    column: $table.routeOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get groupByRayon => $composableBuilder(
    column: $table.groupByRayon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get keepScreenOn => $composableBuilder(
    column: $table.keepScreenOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get firstLaunch => $composableBuilder(
    column: $table.firstLaunch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get seedVersions => $composableBuilder(
    column: $table.seedVersions,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get routeOrder => $composableBuilder(
    column: $table.routeOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get groupByRayon => $composableBuilder(
    column: $table.groupByRayon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get keepScreenOn => $composableBuilder(
    column: $table.keepScreenOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get firstLaunch => $composableBuilder(
    column: $table.firstLaunch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get seedVersions => $composableBuilder(
    column: $table.seedVersions,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get routeOrder => $composableBuilder(
    column: $table.routeOrder,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get groupByRayon => $composableBuilder(
    column: $table.groupByRayon,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get keepScreenOn => $composableBuilder(
    column: $table.keepScreenOn,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get firstLaunch => $composableBuilder(
    column: $table.firstLaunch,
    builder: (column) => column,
  );

  GeneratedColumn<String> get seedVersions => $composableBuilder(
    column: $table.seedVersions,
    builder: (column) => column,
  );
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          SettingsRow,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (
            SettingsRow,
            BaseReferences<_$AppDatabase, $SettingsTable, SettingsRow>,
          ),
          SettingsRow,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> routeOrder = const Value.absent(),
                Value<bool> groupByRayon = const Value.absent(),
                Value<bool> keepScreenOn = const Value.absent(),
                Value<bool> firstLaunch = const Value.absent(),
                Value<String> seedVersions = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(
                id: id,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                routeOrder: routeOrder,
                groupByRayon: groupByRayon,
                keepScreenOn: keepScreenOn,
                firstLaunch: firstLaunch,
                seedVersions: seedVersions,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                required String routeOrder,
                required bool groupByRayon,
                required bool keepScreenOn,
                required bool firstLaunch,
                required String seedVersions,
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                id: id,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                routeOrder: routeOrder,
                groupByRayon: groupByRayon,
                keepScreenOn: keepScreenOn,
                firstLaunch: firstLaunch,
                seedVersions: seedVersions,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, SettingsRow>(table),
                  BaseReferences<_$AppDatabase, $SettingsTable, SettingsRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      SettingsRow,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (SettingsRow, BaseReferences<_$AppDatabase, $SettingsTable, SettingsRow>),
      SettingsRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ArticlesTableTableManager get articles =>
      $$ArticlesTableTableManager(_db, _db.articles);
  $$FrequentsTableTableManager get frequents =>
      $$FrequentsTableTableManager(_db, _db.frequents);
  $$ListLinesTableTableManager get listLines =>
      $$ListLinesTableTableManager(_db, _db.listLines);
  $$ListContributionsTableTableManager get listContributions =>
      $$ListContributionsTableTableManager(_db, _db.listContributions);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}
