// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ChildrenTableTable extends ChildrenTable
    with TableInfo<$ChildrenTableTable, ChildEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChildrenTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _birthDateMeta = const VerificationMeta(
    'birthDate',
  );
  @override
  late final GeneratedColumn<DateTime> birthDate = GeneratedColumn<DateTime>(
    'birth_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  @override
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('localOnly'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    birthDate,
    createdAt,
    updatedAt,
    syncState,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'children';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChildEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('birth_date')) {
      context.handle(
        _birthDateMeta,
        birthDate.isAcceptableOrUnknown(data['birth_date']!, _birthDateMeta),
      );
    } else if (isInserting) {
      context.missing(_birthDateMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChildEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChildEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      birthDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}birth_date'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
    );
  }

  @override
  $ChildrenTableTable createAlias(String alias) {
    return $ChildrenTableTable(attachedDatabase, alias);
  }
}

class ChildEntity extends DataClass implements Insertable<ChildEntity> {
  final String id;
  final String name;
  final DateTime birthDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String syncState;
  const ChildEntity({
    required this.id,
    required this.name,
    required this.birthDate,
    required this.createdAt,
    required this.updatedAt,
    required this.syncState,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['birth_date'] = Variable<DateTime>(birthDate);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['sync_state'] = Variable<String>(syncState);
    return map;
  }

  ChildrenTableCompanion toCompanion(bool nullToAbsent) {
    return ChildrenTableCompanion(
      id: Value(id),
      name: Value(name),
      birthDate: Value(birthDate),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      syncState: Value(syncState),
    );
  }

  factory ChildEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChildEntity(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      birthDate: serializer.fromJson<DateTime>(json['birthDate']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      syncState: serializer.fromJson<String>(json['syncState']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'birthDate': serializer.toJson<DateTime>(birthDate),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'syncState': serializer.toJson<String>(syncState),
    };
  }

  ChildEntity copyWith({
    String? id,
    String? name,
    DateTime? birthDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? syncState,
  }) => ChildEntity(
    id: id ?? this.id,
    name: name ?? this.name,
    birthDate: birthDate ?? this.birthDate,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    syncState: syncState ?? this.syncState,
  );
  ChildEntity copyWithCompanion(ChildrenTableCompanion data) {
    return ChildEntity(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      birthDate: data.birthDate.present ? data.birthDate.value : this.birthDate,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChildEntity(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('birthDate: $birthDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncState: $syncState')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, birthDate, createdAt, updatedAt, syncState);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChildEntity &&
          other.id == this.id &&
          other.name == this.name &&
          other.birthDate == this.birthDate &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.syncState == this.syncState);
}

class ChildrenTableCompanion extends UpdateCompanion<ChildEntity> {
  final Value<String> id;
  final Value<String> name;
  final Value<DateTime> birthDate;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String> syncState;
  final Value<int> rowid;
  const ChildrenTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.birthDate = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.syncState = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChildrenTableCompanion.insert({
    required String id,
    required String name,
    required DateTime birthDate,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.syncState = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       birthDate = Value(birthDate),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ChildEntity> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<DateTime>? birthDate,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? syncState,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (birthDate != null) 'birth_date': birthDate,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (syncState != null) 'sync_state': syncState,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChildrenTableCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<DateTime>? birthDate,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String>? syncState,
    Value<int>? rowid,
  }) {
    return ChildrenTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      birthDate: birthDate ?? this.birthDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncState: syncState ?? this.syncState,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (birthDate.present) {
      map['birth_date'] = Variable<DateTime>(birthDate.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChildrenTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('birthDate: $birthDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncState: $syncState, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ArtworksTableTable extends ArtworksTable
    with TableInfo<$ArtworksTableTable, ArtworkEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ArtworksTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _childIdMeta = const VerificationMeta(
    'childId',
  );
  @override
  late final GeneratedColumn<String> childId = GeneratedColumn<String>(
    'child_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES children (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _relativeImagePathMeta = const VerificationMeta(
    'relativeImagePath',
  );
  @override
  late final GeneratedColumn<String> relativeImagePath =
      GeneratedColumn<String>(
        'relative_image_path',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _drawnAtMeta = const VerificationMeta(
    'drawnAt',
  );
  @override
  late final GeneratedColumn<DateTime> drawnAt = GeneratedColumn<DateTime>(
    'drawn_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _storyMeta = const VerificationMeta('story');
  @override
  late final GeneratedColumn<String> story = GeneratedColumn<String>(
    'story',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  @override
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('localOnly'),
  );
  static const VerificationMeta _displayImagePathMeta = const VerificationMeta(
    'displayImagePath',
  );
  @override
  late final GeneratedColumn<String> displayImagePath = GeneratedColumn<String>(
    'display_image_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thumbnailImagePathMeta =
      const VerificationMeta('thumbnailImagePath');
  @override
  late final GeneratedColumn<String> thumbnailImagePath =
      GeneratedColumn<String>(
        'thumbnail_image_path',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _imageWidthMeta = const VerificationMeta(
    'imageWidth',
  );
  @override
  late final GeneratedColumn<int> imageWidth = GeneratedColumn<int>(
    'image_width',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageHeightMeta = const VerificationMeta(
    'imageHeight',
  );
  @override
  late final GeneratedColumn<int> imageHeight = GeneratedColumn<int>(
    'image_height',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _displayObjectKeyMeta = const VerificationMeta(
    'displayObjectKey',
  );
  @override
  late final GeneratedColumn<String> displayObjectKey = GeneratedColumn<String>(
    'display_object_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thumbnailObjectKeyMeta =
      const VerificationMeta('thumbnailObjectKey');
  @override
  late final GeneratedColumn<String> thumbnailObjectKey =
      GeneratedColumn<String>(
        'thumbnail_object_key',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _byteSizeMeta = const VerificationMeta(
    'byteSize',
  );
  @override
  late final GeneratedColumn<int> byteSize = GeneratedColumn<int>(
    'byte_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _relativeAudioPathMeta = const VerificationMeta(
    'relativeAudioPath',
  );
  @override
  late final GeneratedColumn<String> relativeAudioPath =
      GeneratedColumn<String>(
        'relative_audio_path',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _audioDurationMsMeta = const VerificationMeta(
    'audioDurationMs',
  );
  @override
  late final GeneratedColumn<int> audioDurationMs = GeneratedColumn<int>(
    'audio_duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioObjectKeyMeta = const VerificationMeta(
    'audioObjectKey',
  );
  @override
  late final GeneratedColumn<String> audioObjectKey = GeneratedColumn<String>(
    'audio_object_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioByteSizeMeta = const VerificationMeta(
    'audioByteSize',
  );
  @override
  late final GeneratedColumn<int> audioByteSize = GeneratedColumn<int>(
    'audio_byte_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _addedByMeta = const VerificationMeta(
    'addedBy',
  );
  @override
  late final GeneratedColumn<String> addedBy = GeneratedColumn<String>(
    'added_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    childId,
    relativeImagePath,
    addedAt,
    drawnAt,
    story,
    syncState,
    displayImagePath,
    thumbnailImagePath,
    imageWidth,
    imageHeight,
    displayObjectKey,
    thumbnailObjectKey,
    byteSize,
    relativeAudioPath,
    audioDurationMs,
    audioObjectKey,
    audioByteSize,
    addedBy,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'artworks';
  @override
  VerificationContext validateIntegrity(
    Insertable<ArtworkEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('child_id')) {
      context.handle(
        _childIdMeta,
        childId.isAcceptableOrUnknown(data['child_id']!, _childIdMeta),
      );
    } else if (isInserting) {
      context.missing(_childIdMeta);
    }
    if (data.containsKey('relative_image_path')) {
      context.handle(
        _relativeImagePathMeta,
        relativeImagePath.isAcceptableOrUnknown(
          data['relative_image_path']!,
          _relativeImagePathMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['created_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    if (data.containsKey('drawn_at')) {
      context.handle(
        _drawnAtMeta,
        drawnAt.isAcceptableOrUnknown(data['drawn_at']!, _drawnAtMeta),
      );
    }
    if (data.containsKey('story')) {
      context.handle(
        _storyMeta,
        story.isAcceptableOrUnknown(data['story']!, _storyMeta),
      );
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    if (data.containsKey('display_image_path')) {
      context.handle(
        _displayImagePathMeta,
        displayImagePath.isAcceptableOrUnknown(
          data['display_image_path']!,
          _displayImagePathMeta,
        ),
      );
    }
    if (data.containsKey('thumbnail_image_path')) {
      context.handle(
        _thumbnailImagePathMeta,
        thumbnailImagePath.isAcceptableOrUnknown(
          data['thumbnail_image_path']!,
          _thumbnailImagePathMeta,
        ),
      );
    }
    if (data.containsKey('image_width')) {
      context.handle(
        _imageWidthMeta,
        imageWidth.isAcceptableOrUnknown(data['image_width']!, _imageWidthMeta),
      );
    }
    if (data.containsKey('image_height')) {
      context.handle(
        _imageHeightMeta,
        imageHeight.isAcceptableOrUnknown(
          data['image_height']!,
          _imageHeightMeta,
        ),
      );
    }
    if (data.containsKey('display_object_key')) {
      context.handle(
        _displayObjectKeyMeta,
        displayObjectKey.isAcceptableOrUnknown(
          data['display_object_key']!,
          _displayObjectKeyMeta,
        ),
      );
    }
    if (data.containsKey('thumbnail_object_key')) {
      context.handle(
        _thumbnailObjectKeyMeta,
        thumbnailObjectKey.isAcceptableOrUnknown(
          data['thumbnail_object_key']!,
          _thumbnailObjectKeyMeta,
        ),
      );
    }
    if (data.containsKey('byte_size')) {
      context.handle(
        _byteSizeMeta,
        byteSize.isAcceptableOrUnknown(data['byte_size']!, _byteSizeMeta),
      );
    }
    if (data.containsKey('relative_audio_path')) {
      context.handle(
        _relativeAudioPathMeta,
        relativeAudioPath.isAcceptableOrUnknown(
          data['relative_audio_path']!,
          _relativeAudioPathMeta,
        ),
      );
    }
    if (data.containsKey('audio_duration_ms')) {
      context.handle(
        _audioDurationMsMeta,
        audioDurationMs.isAcceptableOrUnknown(
          data['audio_duration_ms']!,
          _audioDurationMsMeta,
        ),
      );
    }
    if (data.containsKey('audio_object_key')) {
      context.handle(
        _audioObjectKeyMeta,
        audioObjectKey.isAcceptableOrUnknown(
          data['audio_object_key']!,
          _audioObjectKeyMeta,
        ),
      );
    }
    if (data.containsKey('audio_byte_size')) {
      context.handle(
        _audioByteSizeMeta,
        audioByteSize.isAcceptableOrUnknown(
          data['audio_byte_size']!,
          _audioByteSizeMeta,
        ),
      );
    }
    if (data.containsKey('added_by')) {
      context.handle(
        _addedByMeta,
        addedBy.isAcceptableOrUnknown(data['added_by']!, _addedByMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ArtworkEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ArtworkEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      childId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}child_id'],
      )!,
      relativeImagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relative_image_path'],
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      drawnAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}drawn_at'],
      ),
      story: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}story'],
      ),
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
      displayImagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_image_path'],
      ),
      thumbnailImagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumbnail_image_path'],
      ),
      imageWidth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}image_width'],
      ),
      imageHeight: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}image_height'],
      ),
      displayObjectKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_object_key'],
      ),
      thumbnailObjectKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumbnail_object_key'],
      ),
      byteSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}byte_size'],
      )!,
      relativeAudioPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relative_audio_path'],
      ),
      audioDurationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}audio_duration_ms'],
      ),
      audioObjectKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_object_key'],
      ),
      audioByteSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}audio_byte_size'],
      )!,
      addedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}added_by'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $ArtworksTableTable createAlias(String alias) {
    return $ArtworksTableTable(attachedDatabase, alias);
  }
}

class ArtworkEntity extends DataClass implements Insertable<ArtworkEntity> {
  final String id;
  final String childId;
  final String? relativeImagePath;
  final DateTime addedAt;
  final DateTime? drawnAt;
  final String? story;
  final String syncState;
  final String? displayImagePath;
  final String? thumbnailImagePath;
  final int? imageWidth;
  final int? imageHeight;

  /// Opaque object-storage keys. The public core never encodes a provider
  /// specific key format; an optional capability owns their meaning.
  final String? displayObjectKey;
  final String? thumbnailObjectKey;
  final int byteSize;
  final String? relativeAudioPath;
  final int? audioDurationMs;
  final String? audioObjectKey;
  final int audioByteSize;
  final String? addedBy;
  final DateTime? deletedAt;
  const ArtworkEntity({
    required this.id,
    required this.childId,
    this.relativeImagePath,
    required this.addedAt,
    this.drawnAt,
    this.story,
    required this.syncState,
    this.displayImagePath,
    this.thumbnailImagePath,
    this.imageWidth,
    this.imageHeight,
    this.displayObjectKey,
    this.thumbnailObjectKey,
    required this.byteSize,
    this.relativeAudioPath,
    this.audioDurationMs,
    this.audioObjectKey,
    required this.audioByteSize,
    this.addedBy,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['child_id'] = Variable<String>(childId);
    if (!nullToAbsent || relativeImagePath != null) {
      map['relative_image_path'] = Variable<String>(relativeImagePath);
    }
    map['created_at'] = Variable<DateTime>(addedAt);
    if (!nullToAbsent || drawnAt != null) {
      map['drawn_at'] = Variable<DateTime>(drawnAt);
    }
    if (!nullToAbsent || story != null) {
      map['story'] = Variable<String>(story);
    }
    map['sync_state'] = Variable<String>(syncState);
    if (!nullToAbsent || displayImagePath != null) {
      map['display_image_path'] = Variable<String>(displayImagePath);
    }
    if (!nullToAbsent || thumbnailImagePath != null) {
      map['thumbnail_image_path'] = Variable<String>(thumbnailImagePath);
    }
    if (!nullToAbsent || imageWidth != null) {
      map['image_width'] = Variable<int>(imageWidth);
    }
    if (!nullToAbsent || imageHeight != null) {
      map['image_height'] = Variable<int>(imageHeight);
    }
    if (!nullToAbsent || displayObjectKey != null) {
      map['display_object_key'] = Variable<String>(displayObjectKey);
    }
    if (!nullToAbsent || thumbnailObjectKey != null) {
      map['thumbnail_object_key'] = Variable<String>(thumbnailObjectKey);
    }
    map['byte_size'] = Variable<int>(byteSize);
    if (!nullToAbsent || relativeAudioPath != null) {
      map['relative_audio_path'] = Variable<String>(relativeAudioPath);
    }
    if (!nullToAbsent || audioDurationMs != null) {
      map['audio_duration_ms'] = Variable<int>(audioDurationMs);
    }
    if (!nullToAbsent || audioObjectKey != null) {
      map['audio_object_key'] = Variable<String>(audioObjectKey);
    }
    map['audio_byte_size'] = Variable<int>(audioByteSize);
    if (!nullToAbsent || addedBy != null) {
      map['added_by'] = Variable<String>(addedBy);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  ArtworksTableCompanion toCompanion(bool nullToAbsent) {
    return ArtworksTableCompanion(
      id: Value(id),
      childId: Value(childId),
      relativeImagePath: relativeImagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(relativeImagePath),
      addedAt: Value(addedAt),
      drawnAt: drawnAt == null && nullToAbsent
          ? const Value.absent()
          : Value(drawnAt),
      story: story == null && nullToAbsent
          ? const Value.absent()
          : Value(story),
      syncState: Value(syncState),
      displayImagePath: displayImagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(displayImagePath),
      thumbnailImagePath: thumbnailImagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailImagePath),
      imageWidth: imageWidth == null && nullToAbsent
          ? const Value.absent()
          : Value(imageWidth),
      imageHeight: imageHeight == null && nullToAbsent
          ? const Value.absent()
          : Value(imageHeight),
      displayObjectKey: displayObjectKey == null && nullToAbsent
          ? const Value.absent()
          : Value(displayObjectKey),
      thumbnailObjectKey: thumbnailObjectKey == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailObjectKey),
      byteSize: Value(byteSize),
      relativeAudioPath: relativeAudioPath == null && nullToAbsent
          ? const Value.absent()
          : Value(relativeAudioPath),
      audioDurationMs: audioDurationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(audioDurationMs),
      audioObjectKey: audioObjectKey == null && nullToAbsent
          ? const Value.absent()
          : Value(audioObjectKey),
      audioByteSize: Value(audioByteSize),
      addedBy: addedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(addedBy),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory ArtworkEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ArtworkEntity(
      id: serializer.fromJson<String>(json['id']),
      childId: serializer.fromJson<String>(json['childId']),
      relativeImagePath: serializer.fromJson<String?>(
        json['relativeImagePath'],
      ),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
      drawnAt: serializer.fromJson<DateTime?>(json['drawnAt']),
      story: serializer.fromJson<String?>(json['story']),
      syncState: serializer.fromJson<String>(json['syncState']),
      displayImagePath: serializer.fromJson<String?>(json['displayImagePath']),
      thumbnailImagePath: serializer.fromJson<String?>(
        json['thumbnailImagePath'],
      ),
      imageWidth: serializer.fromJson<int?>(json['imageWidth']),
      imageHeight: serializer.fromJson<int?>(json['imageHeight']),
      displayObjectKey: serializer.fromJson<String?>(json['displayObjectKey']),
      thumbnailObjectKey: serializer.fromJson<String?>(
        json['thumbnailObjectKey'],
      ),
      byteSize: serializer.fromJson<int>(json['byteSize']),
      relativeAudioPath: serializer.fromJson<String?>(
        json['relativeAudioPath'],
      ),
      audioDurationMs: serializer.fromJson<int?>(json['audioDurationMs']),
      audioObjectKey: serializer.fromJson<String?>(json['audioObjectKey']),
      audioByteSize: serializer.fromJson<int>(json['audioByteSize']),
      addedBy: serializer.fromJson<String?>(json['addedBy']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'childId': serializer.toJson<String>(childId),
      'relativeImagePath': serializer.toJson<String?>(relativeImagePath),
      'addedAt': serializer.toJson<DateTime>(addedAt),
      'drawnAt': serializer.toJson<DateTime?>(drawnAt),
      'story': serializer.toJson<String?>(story),
      'syncState': serializer.toJson<String>(syncState),
      'displayImagePath': serializer.toJson<String?>(displayImagePath),
      'thumbnailImagePath': serializer.toJson<String?>(thumbnailImagePath),
      'imageWidth': serializer.toJson<int?>(imageWidth),
      'imageHeight': serializer.toJson<int?>(imageHeight),
      'displayObjectKey': serializer.toJson<String?>(displayObjectKey),
      'thumbnailObjectKey': serializer.toJson<String?>(thumbnailObjectKey),
      'byteSize': serializer.toJson<int>(byteSize),
      'relativeAudioPath': serializer.toJson<String?>(relativeAudioPath),
      'audioDurationMs': serializer.toJson<int?>(audioDurationMs),
      'audioObjectKey': serializer.toJson<String?>(audioObjectKey),
      'audioByteSize': serializer.toJson<int>(audioByteSize),
      'addedBy': serializer.toJson<String?>(addedBy),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  ArtworkEntity copyWith({
    String? id,
    String? childId,
    Value<String?> relativeImagePath = const Value.absent(),
    DateTime? addedAt,
    Value<DateTime?> drawnAt = const Value.absent(),
    Value<String?> story = const Value.absent(),
    String? syncState,
    Value<String?> displayImagePath = const Value.absent(),
    Value<String?> thumbnailImagePath = const Value.absent(),
    Value<int?> imageWidth = const Value.absent(),
    Value<int?> imageHeight = const Value.absent(),
    Value<String?> displayObjectKey = const Value.absent(),
    Value<String?> thumbnailObjectKey = const Value.absent(),
    int? byteSize,
    Value<String?> relativeAudioPath = const Value.absent(),
    Value<int?> audioDurationMs = const Value.absent(),
    Value<String?> audioObjectKey = const Value.absent(),
    int? audioByteSize,
    Value<String?> addedBy = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => ArtworkEntity(
    id: id ?? this.id,
    childId: childId ?? this.childId,
    relativeImagePath: relativeImagePath.present
        ? relativeImagePath.value
        : this.relativeImagePath,
    addedAt: addedAt ?? this.addedAt,
    drawnAt: drawnAt.present ? drawnAt.value : this.drawnAt,
    story: story.present ? story.value : this.story,
    syncState: syncState ?? this.syncState,
    displayImagePath: displayImagePath.present
        ? displayImagePath.value
        : this.displayImagePath,
    thumbnailImagePath: thumbnailImagePath.present
        ? thumbnailImagePath.value
        : this.thumbnailImagePath,
    imageWidth: imageWidth.present ? imageWidth.value : this.imageWidth,
    imageHeight: imageHeight.present ? imageHeight.value : this.imageHeight,
    displayObjectKey: displayObjectKey.present
        ? displayObjectKey.value
        : this.displayObjectKey,
    thumbnailObjectKey: thumbnailObjectKey.present
        ? thumbnailObjectKey.value
        : this.thumbnailObjectKey,
    byteSize: byteSize ?? this.byteSize,
    relativeAudioPath: relativeAudioPath.present
        ? relativeAudioPath.value
        : this.relativeAudioPath,
    audioDurationMs: audioDurationMs.present
        ? audioDurationMs.value
        : this.audioDurationMs,
    audioObjectKey: audioObjectKey.present
        ? audioObjectKey.value
        : this.audioObjectKey,
    audioByteSize: audioByteSize ?? this.audioByteSize,
    addedBy: addedBy.present ? addedBy.value : this.addedBy,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  ArtworkEntity copyWithCompanion(ArtworksTableCompanion data) {
    return ArtworkEntity(
      id: data.id.present ? data.id.value : this.id,
      childId: data.childId.present ? data.childId.value : this.childId,
      relativeImagePath: data.relativeImagePath.present
          ? data.relativeImagePath.value
          : this.relativeImagePath,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      drawnAt: data.drawnAt.present ? data.drawnAt.value : this.drawnAt,
      story: data.story.present ? data.story.value : this.story,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      displayImagePath: data.displayImagePath.present
          ? data.displayImagePath.value
          : this.displayImagePath,
      thumbnailImagePath: data.thumbnailImagePath.present
          ? data.thumbnailImagePath.value
          : this.thumbnailImagePath,
      imageWidth: data.imageWidth.present
          ? data.imageWidth.value
          : this.imageWidth,
      imageHeight: data.imageHeight.present
          ? data.imageHeight.value
          : this.imageHeight,
      displayObjectKey: data.displayObjectKey.present
          ? data.displayObjectKey.value
          : this.displayObjectKey,
      thumbnailObjectKey: data.thumbnailObjectKey.present
          ? data.thumbnailObjectKey.value
          : this.thumbnailObjectKey,
      byteSize: data.byteSize.present ? data.byteSize.value : this.byteSize,
      relativeAudioPath: data.relativeAudioPath.present
          ? data.relativeAudioPath.value
          : this.relativeAudioPath,
      audioDurationMs: data.audioDurationMs.present
          ? data.audioDurationMs.value
          : this.audioDurationMs,
      audioObjectKey: data.audioObjectKey.present
          ? data.audioObjectKey.value
          : this.audioObjectKey,
      audioByteSize: data.audioByteSize.present
          ? data.audioByteSize.value
          : this.audioByteSize,
      addedBy: data.addedBy.present ? data.addedBy.value : this.addedBy,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ArtworkEntity(')
          ..write('id: $id, ')
          ..write('childId: $childId, ')
          ..write('relativeImagePath: $relativeImagePath, ')
          ..write('addedAt: $addedAt, ')
          ..write('drawnAt: $drawnAt, ')
          ..write('story: $story, ')
          ..write('syncState: $syncState, ')
          ..write('displayImagePath: $displayImagePath, ')
          ..write('thumbnailImagePath: $thumbnailImagePath, ')
          ..write('imageWidth: $imageWidth, ')
          ..write('imageHeight: $imageHeight, ')
          ..write('displayObjectKey: $displayObjectKey, ')
          ..write('thumbnailObjectKey: $thumbnailObjectKey, ')
          ..write('byteSize: $byteSize, ')
          ..write('relativeAudioPath: $relativeAudioPath, ')
          ..write('audioDurationMs: $audioDurationMs, ')
          ..write('audioObjectKey: $audioObjectKey, ')
          ..write('audioByteSize: $audioByteSize, ')
          ..write('addedBy: $addedBy, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    childId,
    relativeImagePath,
    addedAt,
    drawnAt,
    story,
    syncState,
    displayImagePath,
    thumbnailImagePath,
    imageWidth,
    imageHeight,
    displayObjectKey,
    thumbnailObjectKey,
    byteSize,
    relativeAudioPath,
    audioDurationMs,
    audioObjectKey,
    audioByteSize,
    addedBy,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ArtworkEntity &&
          other.id == this.id &&
          other.childId == this.childId &&
          other.relativeImagePath == this.relativeImagePath &&
          other.addedAt == this.addedAt &&
          other.drawnAt == this.drawnAt &&
          other.story == this.story &&
          other.syncState == this.syncState &&
          other.displayImagePath == this.displayImagePath &&
          other.thumbnailImagePath == this.thumbnailImagePath &&
          other.imageWidth == this.imageWidth &&
          other.imageHeight == this.imageHeight &&
          other.displayObjectKey == this.displayObjectKey &&
          other.thumbnailObjectKey == this.thumbnailObjectKey &&
          other.byteSize == this.byteSize &&
          other.relativeAudioPath == this.relativeAudioPath &&
          other.audioDurationMs == this.audioDurationMs &&
          other.audioObjectKey == this.audioObjectKey &&
          other.audioByteSize == this.audioByteSize &&
          other.addedBy == this.addedBy &&
          other.deletedAt == this.deletedAt);
}

class ArtworksTableCompanion extends UpdateCompanion<ArtworkEntity> {
  final Value<String> id;
  final Value<String> childId;
  final Value<String?> relativeImagePath;
  final Value<DateTime> addedAt;
  final Value<DateTime?> drawnAt;
  final Value<String?> story;
  final Value<String> syncState;
  final Value<String?> displayImagePath;
  final Value<String?> thumbnailImagePath;
  final Value<int?> imageWidth;
  final Value<int?> imageHeight;
  final Value<String?> displayObjectKey;
  final Value<String?> thumbnailObjectKey;
  final Value<int> byteSize;
  final Value<String?> relativeAudioPath;
  final Value<int?> audioDurationMs;
  final Value<String?> audioObjectKey;
  final Value<int> audioByteSize;
  final Value<String?> addedBy;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const ArtworksTableCompanion({
    this.id = const Value.absent(),
    this.childId = const Value.absent(),
    this.relativeImagePath = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.drawnAt = const Value.absent(),
    this.story = const Value.absent(),
    this.syncState = const Value.absent(),
    this.displayImagePath = const Value.absent(),
    this.thumbnailImagePath = const Value.absent(),
    this.imageWidth = const Value.absent(),
    this.imageHeight = const Value.absent(),
    this.displayObjectKey = const Value.absent(),
    this.thumbnailObjectKey = const Value.absent(),
    this.byteSize = const Value.absent(),
    this.relativeAudioPath = const Value.absent(),
    this.audioDurationMs = const Value.absent(),
    this.audioObjectKey = const Value.absent(),
    this.audioByteSize = const Value.absent(),
    this.addedBy = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ArtworksTableCompanion.insert({
    required String id,
    required String childId,
    this.relativeImagePath = const Value.absent(),
    required DateTime addedAt,
    this.drawnAt = const Value.absent(),
    this.story = const Value.absent(),
    this.syncState = const Value.absent(),
    this.displayImagePath = const Value.absent(),
    this.thumbnailImagePath = const Value.absent(),
    this.imageWidth = const Value.absent(),
    this.imageHeight = const Value.absent(),
    this.displayObjectKey = const Value.absent(),
    this.thumbnailObjectKey = const Value.absent(),
    this.byteSize = const Value.absent(),
    this.relativeAudioPath = const Value.absent(),
    this.audioDurationMs = const Value.absent(),
    this.audioObjectKey = const Value.absent(),
    this.audioByteSize = const Value.absent(),
    this.addedBy = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       childId = Value(childId),
       addedAt = Value(addedAt);
  static Insertable<ArtworkEntity> custom({
    Expression<String>? id,
    Expression<String>? childId,
    Expression<String>? relativeImagePath,
    Expression<DateTime>? addedAt,
    Expression<DateTime>? drawnAt,
    Expression<String>? story,
    Expression<String>? syncState,
    Expression<String>? displayImagePath,
    Expression<String>? thumbnailImagePath,
    Expression<int>? imageWidth,
    Expression<int>? imageHeight,
    Expression<String>? displayObjectKey,
    Expression<String>? thumbnailObjectKey,
    Expression<int>? byteSize,
    Expression<String>? relativeAudioPath,
    Expression<int>? audioDurationMs,
    Expression<String>? audioObjectKey,
    Expression<int>? audioByteSize,
    Expression<String>? addedBy,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (childId != null) 'child_id': childId,
      if (relativeImagePath != null) 'relative_image_path': relativeImagePath,
      if (addedAt != null) 'created_at': addedAt,
      if (drawnAt != null) 'drawn_at': drawnAt,
      if (story != null) 'story': story,
      if (syncState != null) 'sync_state': syncState,
      if (displayImagePath != null) 'display_image_path': displayImagePath,
      if (thumbnailImagePath != null)
        'thumbnail_image_path': thumbnailImagePath,
      if (imageWidth != null) 'image_width': imageWidth,
      if (imageHeight != null) 'image_height': imageHeight,
      if (displayObjectKey != null) 'display_object_key': displayObjectKey,
      if (thumbnailObjectKey != null)
        'thumbnail_object_key': thumbnailObjectKey,
      if (byteSize != null) 'byte_size': byteSize,
      if (relativeAudioPath != null) 'relative_audio_path': relativeAudioPath,
      if (audioDurationMs != null) 'audio_duration_ms': audioDurationMs,
      if (audioObjectKey != null) 'audio_object_key': audioObjectKey,
      if (audioByteSize != null) 'audio_byte_size': audioByteSize,
      if (addedBy != null) 'added_by': addedBy,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ArtworksTableCompanion copyWith({
    Value<String>? id,
    Value<String>? childId,
    Value<String?>? relativeImagePath,
    Value<DateTime>? addedAt,
    Value<DateTime?>? drawnAt,
    Value<String?>? story,
    Value<String>? syncState,
    Value<String?>? displayImagePath,
    Value<String?>? thumbnailImagePath,
    Value<int?>? imageWidth,
    Value<int?>? imageHeight,
    Value<String?>? displayObjectKey,
    Value<String?>? thumbnailObjectKey,
    Value<int>? byteSize,
    Value<String?>? relativeAudioPath,
    Value<int?>? audioDurationMs,
    Value<String?>? audioObjectKey,
    Value<int>? audioByteSize,
    Value<String?>? addedBy,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return ArtworksTableCompanion(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      relativeImagePath: relativeImagePath ?? this.relativeImagePath,
      addedAt: addedAt ?? this.addedAt,
      drawnAt: drawnAt ?? this.drawnAt,
      story: story ?? this.story,
      syncState: syncState ?? this.syncState,
      displayImagePath: displayImagePath ?? this.displayImagePath,
      thumbnailImagePath: thumbnailImagePath ?? this.thumbnailImagePath,
      imageWidth: imageWidth ?? this.imageWidth,
      imageHeight: imageHeight ?? this.imageHeight,
      displayObjectKey: displayObjectKey ?? this.displayObjectKey,
      thumbnailObjectKey: thumbnailObjectKey ?? this.thumbnailObjectKey,
      byteSize: byteSize ?? this.byteSize,
      relativeAudioPath: relativeAudioPath ?? this.relativeAudioPath,
      audioDurationMs: audioDurationMs ?? this.audioDurationMs,
      audioObjectKey: audioObjectKey ?? this.audioObjectKey,
      audioByteSize: audioByteSize ?? this.audioByteSize,
      addedBy: addedBy ?? this.addedBy,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (childId.present) {
      map['child_id'] = Variable<String>(childId.value);
    }
    if (relativeImagePath.present) {
      map['relative_image_path'] = Variable<String>(relativeImagePath.value);
    }
    if (addedAt.present) {
      map['created_at'] = Variable<DateTime>(addedAt.value);
    }
    if (drawnAt.present) {
      map['drawn_at'] = Variable<DateTime>(drawnAt.value);
    }
    if (story.present) {
      map['story'] = Variable<String>(story.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (displayImagePath.present) {
      map['display_image_path'] = Variable<String>(displayImagePath.value);
    }
    if (thumbnailImagePath.present) {
      map['thumbnail_image_path'] = Variable<String>(thumbnailImagePath.value);
    }
    if (imageWidth.present) {
      map['image_width'] = Variable<int>(imageWidth.value);
    }
    if (imageHeight.present) {
      map['image_height'] = Variable<int>(imageHeight.value);
    }
    if (displayObjectKey.present) {
      map['display_object_key'] = Variable<String>(displayObjectKey.value);
    }
    if (thumbnailObjectKey.present) {
      map['thumbnail_object_key'] = Variable<String>(thumbnailObjectKey.value);
    }
    if (byteSize.present) {
      map['byte_size'] = Variable<int>(byteSize.value);
    }
    if (relativeAudioPath.present) {
      map['relative_audio_path'] = Variable<String>(relativeAudioPath.value);
    }
    if (audioDurationMs.present) {
      map['audio_duration_ms'] = Variable<int>(audioDurationMs.value);
    }
    if (audioObjectKey.present) {
      map['audio_object_key'] = Variable<String>(audioObjectKey.value);
    }
    if (audioByteSize.present) {
      map['audio_byte_size'] = Variable<int>(audioByteSize.value);
    }
    if (addedBy.present) {
      map['added_by'] = Variable<String>(addedBy.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ArtworksTableCompanion(')
          ..write('id: $id, ')
          ..write('childId: $childId, ')
          ..write('relativeImagePath: $relativeImagePath, ')
          ..write('addedAt: $addedAt, ')
          ..write('drawnAt: $drawnAt, ')
          ..write('story: $story, ')
          ..write('syncState: $syncState, ')
          ..write('displayImagePath: $displayImagePath, ')
          ..write('thumbnailImagePath: $thumbnailImagePath, ')
          ..write('imageWidth: $imageWidth, ')
          ..write('imageHeight: $imageHeight, ')
          ..write('displayObjectKey: $displayObjectKey, ')
          ..write('thumbnailObjectKey: $thumbnailObjectKey, ')
          ..write('byteSize: $byteSize, ')
          ..write('relativeAudioPath: $relativeAudioPath, ')
          ..write('audioDurationMs: $audioDurationMs, ')
          ..write('audioObjectKey: $audioObjectKey, ')
          ..write('audioByteSize: $audioByteSize, ')
          ..write('addedBy: $addedBy, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingFileCleanupsTableTable extends PendingFileCleanupsTable
    with TableInfo<$PendingFileCleanupsTableTable, PendingFileCleanupEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingFileCleanupsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _relativePathMeta = const VerificationMeta(
    'relativePath',
  );
  @override
  late final GeneratedColumn<String> relativePath = GeneratedColumn<String>(
    'relative_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _failedAtMeta = const VerificationMeta(
    'failedAt',
  );
  @override
  late final GeneratedColumn<DateTime> failedAt = GeneratedColumn<DateTime>(
    'failed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [relativePath, failedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_file_cleanups';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingFileCleanupEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('relative_path')) {
      context.handle(
        _relativePathMeta,
        relativePath.isAcceptableOrUnknown(
          data['relative_path']!,
          _relativePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_relativePathMeta);
    }
    if (data.containsKey('failed_at')) {
      context.handle(
        _failedAtMeta,
        failedAt.isAcceptableOrUnknown(data['failed_at']!, _failedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_failedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {relativePath};
  @override
  PendingFileCleanupEntity map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingFileCleanupEntity(
      relativePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relative_path'],
      )!,
      failedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}failed_at'],
      )!,
    );
  }

  @override
  $PendingFileCleanupsTableTable createAlias(String alias) {
    return $PendingFileCleanupsTableTable(attachedDatabase, alias);
  }
}

class PendingFileCleanupEntity extends DataClass
    implements Insertable<PendingFileCleanupEntity> {
  final String relativePath;
  final DateTime failedAt;
  const PendingFileCleanupEntity({
    required this.relativePath,
    required this.failedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['relative_path'] = Variable<String>(relativePath);
    map['failed_at'] = Variable<DateTime>(failedAt);
    return map;
  }

  PendingFileCleanupsTableCompanion toCompanion(bool nullToAbsent) {
    return PendingFileCleanupsTableCompanion(
      relativePath: Value(relativePath),
      failedAt: Value(failedAt),
    );
  }

  factory PendingFileCleanupEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingFileCleanupEntity(
      relativePath: serializer.fromJson<String>(json['relativePath']),
      failedAt: serializer.fromJson<DateTime>(json['failedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'relativePath': serializer.toJson<String>(relativePath),
      'failedAt': serializer.toJson<DateTime>(failedAt),
    };
  }

  PendingFileCleanupEntity copyWith({
    String? relativePath,
    DateTime? failedAt,
  }) => PendingFileCleanupEntity(
    relativePath: relativePath ?? this.relativePath,
    failedAt: failedAt ?? this.failedAt,
  );
  PendingFileCleanupEntity copyWithCompanion(
    PendingFileCleanupsTableCompanion data,
  ) {
    return PendingFileCleanupEntity(
      relativePath: data.relativePath.present
          ? data.relativePath.value
          : this.relativePath,
      failedAt: data.failedAt.present ? data.failedAt.value : this.failedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingFileCleanupEntity(')
          ..write('relativePath: $relativePath, ')
          ..write('failedAt: $failedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(relativePath, failedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingFileCleanupEntity &&
          other.relativePath == this.relativePath &&
          other.failedAt == this.failedAt);
}

class PendingFileCleanupsTableCompanion
    extends UpdateCompanion<PendingFileCleanupEntity> {
  final Value<String> relativePath;
  final Value<DateTime> failedAt;
  final Value<int> rowid;
  const PendingFileCleanupsTableCompanion({
    this.relativePath = const Value.absent(),
    this.failedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingFileCleanupsTableCompanion.insert({
    required String relativePath,
    required DateTime failedAt,
    this.rowid = const Value.absent(),
  }) : relativePath = Value(relativePath),
       failedAt = Value(failedAt);
  static Insertable<PendingFileCleanupEntity> custom({
    Expression<String>? relativePath,
    Expression<DateTime>? failedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (relativePath != null) 'relative_path': relativePath,
      if (failedAt != null) 'failed_at': failedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingFileCleanupsTableCompanion copyWith({
    Value<String>? relativePath,
    Value<DateTime>? failedAt,
    Value<int>? rowid,
  }) {
    return PendingFileCleanupsTableCompanion(
      relativePath: relativePath ?? this.relativePath,
      failedAt: failedAt ?? this.failedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (relativePath.present) {
      map['relative_path'] = Variable<String>(relativePath.value);
    }
    if (failedAt.present) {
      map['failed_at'] = Variable<DateTime>(failedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingFileCleanupsTableCompanion(')
          ..write('relativePath: $relativePath, ')
          ..write('failedAt: $failedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncOutboxTableTable extends SyncOutboxTable
    with TableInfo<$SyncOutboxTableTable, SyncOutboxEntryEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncOutboxTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _opMeta = const VerificationMeta('op');
  @override
  late final GeneratedColumn<String> op = GeneratedColumn<String>(
    'op',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextAttemptAtMeta = const VerificationMeta(
    'nextAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextAttemptAt =
      GeneratedColumn<DateTime>(
        'next_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    seq,
    entity,
    entityId,
    op,
    attempts,
    nextAttemptAt,
    lastError,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncOutboxEntryEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    }
    if (data.containsKey('entity')) {
      context.handle(
        _entityMeta,
        entity.isAcceptableOrUnknown(data['entity']!, _entityMeta),
      );
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('op')) {
      context.handle(_opMeta, op.isAcceptableOrUnknown(data['op']!, _opMeta));
    } else if (isInserting) {
      context.missing(_opMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
        _nextAttemptAtMeta,
        nextAttemptAt.isAcceptableOrUnknown(
          data['next_attempt_at']!,
          _nextAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {seq};
  @override
  SyncOutboxEntryEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncOutboxEntryEntity(
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      entity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      op: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}op'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      nextAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_attempt_at'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SyncOutboxTableTable createAlias(String alias) {
    return $SyncOutboxTableTable(attachedDatabase, alias);
  }
}

class SyncOutboxEntryEntity extends DataClass
    implements Insertable<SyncOutboxEntryEntity> {
  final int seq;
  final String entity;
  final String entityId;
  final String op;
  final int attempts;
  final DateTime? nextAttemptAt;
  final String? lastError;
  final DateTime createdAt;
  const SyncOutboxEntryEntity({
    required this.seq,
    required this.entity,
    required this.entityId,
    required this.op,
    required this.attempts,
    this.nextAttemptAt,
    this.lastError,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['seq'] = Variable<int>(seq);
    map['entity'] = Variable<String>(entity);
    map['entity_id'] = Variable<String>(entityId);
    map['op'] = Variable<String>(op);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || nextAttemptAt != null) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SyncOutboxTableCompanion toCompanion(bool nullToAbsent) {
    return SyncOutboxTableCompanion(
      seq: Value(seq),
      entity: Value(entity),
      entityId: Value(entityId),
      op: Value(op),
      attempts: Value(attempts),
      nextAttemptAt: nextAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextAttemptAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
    );
  }

  factory SyncOutboxEntryEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncOutboxEntryEntity(
      seq: serializer.fromJson<int>(json['seq']),
      entity: serializer.fromJson<String>(json['entity']),
      entityId: serializer.fromJson<String>(json['entityId']),
      op: serializer.fromJson<String>(json['op']),
      attempts: serializer.fromJson<int>(json['attempts']),
      nextAttemptAt: serializer.fromJson<DateTime?>(json['nextAttemptAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seq': serializer.toJson<int>(seq),
      'entity': serializer.toJson<String>(entity),
      'entityId': serializer.toJson<String>(entityId),
      'op': serializer.toJson<String>(op),
      'attempts': serializer.toJson<int>(attempts),
      'nextAttemptAt': serializer.toJson<DateTime?>(nextAttemptAt),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SyncOutboxEntryEntity copyWith({
    int? seq,
    String? entity,
    String? entityId,
    String? op,
    int? attempts,
    Value<DateTime?> nextAttemptAt = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
    DateTime? createdAt,
  }) => SyncOutboxEntryEntity(
    seq: seq ?? this.seq,
    entity: entity ?? this.entity,
    entityId: entityId ?? this.entityId,
    op: op ?? this.op,
    attempts: attempts ?? this.attempts,
    nextAttemptAt: nextAttemptAt.present
        ? nextAttemptAt.value
        : this.nextAttemptAt,
    lastError: lastError.present ? lastError.value : this.lastError,
    createdAt: createdAt ?? this.createdAt,
  );
  SyncOutboxEntryEntity copyWithCompanion(SyncOutboxTableCompanion data) {
    return SyncOutboxEntryEntity(
      seq: data.seq.present ? data.seq.value : this.seq,
      entity: data.entity.present ? data.entity.value : this.entity,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      op: data.op.present ? data.op.value : this.op,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxEntryEntity(')
          ..write('seq: $seq, ')
          ..write('entity: $entity, ')
          ..write('entityId: $entityId, ')
          ..write('op: $op, ')
          ..write('attempts: $attempts, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    seq,
    entity,
    entityId,
    op,
    attempts,
    nextAttemptAt,
    lastError,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncOutboxEntryEntity &&
          other.seq == this.seq &&
          other.entity == this.entity &&
          other.entityId == this.entityId &&
          other.op == this.op &&
          other.attempts == this.attempts &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt);
}

class SyncOutboxTableCompanion extends UpdateCompanion<SyncOutboxEntryEntity> {
  final Value<int> seq;
  final Value<String> entity;
  final Value<String> entityId;
  final Value<String> op;
  final Value<int> attempts;
  final Value<DateTime?> nextAttemptAt;
  final Value<String?> lastError;
  final Value<DateTime> createdAt;
  const SyncOutboxTableCompanion({
    this.seq = const Value.absent(),
    this.entity = const Value.absent(),
    this.entityId = const Value.absent(),
    this.op = const Value.absent(),
    this.attempts = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SyncOutboxTableCompanion.insert({
    this.seq = const Value.absent(),
    required String entity,
    required String entityId,
    required String op,
    this.attempts = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.lastError = const Value.absent(),
    required DateTime createdAt,
  }) : entity = Value(entity),
       entityId = Value(entityId),
       op = Value(op),
       createdAt = Value(createdAt);
  static Insertable<SyncOutboxEntryEntity> custom({
    Expression<int>? seq,
    Expression<String>? entity,
    Expression<String>? entityId,
    Expression<String>? op,
    Expression<int>? attempts,
    Expression<DateTime>? nextAttemptAt,
    Expression<String>? lastError,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (seq != null) 'seq': seq,
      if (entity != null) 'entity': entity,
      if (entityId != null) 'entity_id': entityId,
      if (op != null) 'op': op,
      if (attempts != null) 'attempts': attempts,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SyncOutboxTableCompanion copyWith({
    Value<int>? seq,
    Value<String>? entity,
    Value<String>? entityId,
    Value<String>? op,
    Value<int>? attempts,
    Value<DateTime?>? nextAttemptAt,
    Value<String?>? lastError,
    Value<DateTime>? createdAt,
  }) {
    return SyncOutboxTableCompanion(
      seq: seq ?? this.seq,
      entity: entity ?? this.entity,
      entityId: entityId ?? this.entityId,
      op: op ?? this.op,
      attempts: attempts ?? this.attempts,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (op.present) {
      map['op'] = Variable<String>(op.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxTableCompanion(')
          ..write('seq: $seq, ')
          ..write('entity: $entity, ')
          ..write('entityId: $entityId, ')
          ..write('op: $op, ')
          ..write('attempts: $attempts, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $VaultMetaTableTable extends VaultMetaTable
    with TableInfo<$VaultMetaTableTable, VaultMetaEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VaultMetaTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _familyIdMeta = const VerificationMeta(
    'familyId',
  );
  @override
  late final GeneratedColumn<String> familyId = GeneratedColumn<String>(
    'family_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _joinResetPendingMeta = const VerificationMeta(
    'joinResetPending',
  );
  @override
  late final GeneratedColumn<bool> joinResetPending = GeneratedColumn<bool>(
    'join_reset_pending',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("join_reset_pending" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastPullCursorMeta = const VerificationMeta(
    'lastPullCursor',
  );
  @override
  late final GeneratedColumn<DateTime> lastPullCursor =
      GeneratedColumn<DateTime>(
        'last_pull_cursor',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _childrenPullCursorMeta =
      const VerificationMeta('childrenPullCursor');
  @override
  late final GeneratedColumn<DateTime> childrenPullCursor =
      GeneratedColumn<DateTime>(
        'children_pull_cursor',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _artworksPullCursorMeta =
      const VerificationMeta('artworksPullCursor');
  @override
  late final GeneratedColumn<DateTime> artworksPullCursor =
      GeneratedColumn<DateTime>(
        'artworks_pull_cursor',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _purgedPullCursorMeta = const VerificationMeta(
    'purgedPullCursor',
  );
  @override
  late final GeneratedColumn<DateTime> purgedPullCursor =
      GeneratedColumn<DateTime>(
        'purged_pull_cursor',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    familyId,
    joinResetPending,
    lastPullCursor,
    childrenPullCursor,
    artworksPullCursor,
    purgedPullCursor,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vault_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<VaultMetaEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('family_id')) {
      context.handle(
        _familyIdMeta,
        familyId.isAcceptableOrUnknown(data['family_id']!, _familyIdMeta),
      );
    }
    if (data.containsKey('join_reset_pending')) {
      context.handle(
        _joinResetPendingMeta,
        joinResetPending.isAcceptableOrUnknown(
          data['join_reset_pending']!,
          _joinResetPendingMeta,
        ),
      );
    }
    if (data.containsKey('last_pull_cursor')) {
      context.handle(
        _lastPullCursorMeta,
        lastPullCursor.isAcceptableOrUnknown(
          data['last_pull_cursor']!,
          _lastPullCursorMeta,
        ),
      );
    }
    if (data.containsKey('children_pull_cursor')) {
      context.handle(
        _childrenPullCursorMeta,
        childrenPullCursor.isAcceptableOrUnknown(
          data['children_pull_cursor']!,
          _childrenPullCursorMeta,
        ),
      );
    }
    if (data.containsKey('artworks_pull_cursor')) {
      context.handle(
        _artworksPullCursorMeta,
        artworksPullCursor.isAcceptableOrUnknown(
          data['artworks_pull_cursor']!,
          _artworksPullCursorMeta,
        ),
      );
    }
    if (data.containsKey('purged_pull_cursor')) {
      context.handle(
        _purgedPullCursorMeta,
        purgedPullCursor.isAcceptableOrUnknown(
          data['purged_pull_cursor']!,
          _purgedPullCursorMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VaultMetaEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VaultMetaEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      familyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}family_id'],
      ),
      joinResetPending: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}join_reset_pending'],
      )!,
      lastPullCursor: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_pull_cursor'],
      ),
      childrenPullCursor: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}children_pull_cursor'],
      ),
      artworksPullCursor: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}artworks_pull_cursor'],
      ),
      purgedPullCursor: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}purged_pull_cursor'],
      ),
    );
  }

  @override
  $VaultMetaTableTable createAlias(String alias) {
    return $VaultMetaTableTable(attachedDatabase, alias);
  }
}

class VaultMetaEntity extends DataClass implements Insertable<VaultMetaEntity> {
  final String id;
  final String? familyId;
  final bool joinResetPending;
  final DateTime? lastPullCursor;
  final DateTime? childrenPullCursor;
  final DateTime? artworksPullCursor;
  final DateTime? purgedPullCursor;
  const VaultMetaEntity({
    required this.id,
    this.familyId,
    required this.joinResetPending,
    this.lastPullCursor,
    this.childrenPullCursor,
    this.artworksPullCursor,
    this.purgedPullCursor,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || familyId != null) {
      map['family_id'] = Variable<String>(familyId);
    }
    map['join_reset_pending'] = Variable<bool>(joinResetPending);
    if (!nullToAbsent || lastPullCursor != null) {
      map['last_pull_cursor'] = Variable<DateTime>(lastPullCursor);
    }
    if (!nullToAbsent || childrenPullCursor != null) {
      map['children_pull_cursor'] = Variable<DateTime>(childrenPullCursor);
    }
    if (!nullToAbsent || artworksPullCursor != null) {
      map['artworks_pull_cursor'] = Variable<DateTime>(artworksPullCursor);
    }
    if (!nullToAbsent || purgedPullCursor != null) {
      map['purged_pull_cursor'] = Variable<DateTime>(purgedPullCursor);
    }
    return map;
  }

  VaultMetaTableCompanion toCompanion(bool nullToAbsent) {
    return VaultMetaTableCompanion(
      id: Value(id),
      familyId: familyId == null && nullToAbsent
          ? const Value.absent()
          : Value(familyId),
      joinResetPending: Value(joinResetPending),
      lastPullCursor: lastPullCursor == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPullCursor),
      childrenPullCursor: childrenPullCursor == null && nullToAbsent
          ? const Value.absent()
          : Value(childrenPullCursor),
      artworksPullCursor: artworksPullCursor == null && nullToAbsent
          ? const Value.absent()
          : Value(artworksPullCursor),
      purgedPullCursor: purgedPullCursor == null && nullToAbsent
          ? const Value.absent()
          : Value(purgedPullCursor),
    );
  }

  factory VaultMetaEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VaultMetaEntity(
      id: serializer.fromJson<String>(json['id']),
      familyId: serializer.fromJson<String?>(json['familyId']),
      joinResetPending: serializer.fromJson<bool>(json['joinResetPending']),
      lastPullCursor: serializer.fromJson<DateTime?>(json['lastPullCursor']),
      childrenPullCursor: serializer.fromJson<DateTime?>(
        json['childrenPullCursor'],
      ),
      artworksPullCursor: serializer.fromJson<DateTime?>(
        json['artworksPullCursor'],
      ),
      purgedPullCursor: serializer.fromJson<DateTime?>(
        json['purgedPullCursor'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'familyId': serializer.toJson<String?>(familyId),
      'joinResetPending': serializer.toJson<bool>(joinResetPending),
      'lastPullCursor': serializer.toJson<DateTime?>(lastPullCursor),
      'childrenPullCursor': serializer.toJson<DateTime?>(childrenPullCursor),
      'artworksPullCursor': serializer.toJson<DateTime?>(artworksPullCursor),
      'purgedPullCursor': serializer.toJson<DateTime?>(purgedPullCursor),
    };
  }

  VaultMetaEntity copyWith({
    String? id,
    Value<String?> familyId = const Value.absent(),
    bool? joinResetPending,
    Value<DateTime?> lastPullCursor = const Value.absent(),
    Value<DateTime?> childrenPullCursor = const Value.absent(),
    Value<DateTime?> artworksPullCursor = const Value.absent(),
    Value<DateTime?> purgedPullCursor = const Value.absent(),
  }) => VaultMetaEntity(
    id: id ?? this.id,
    familyId: familyId.present ? familyId.value : this.familyId,
    joinResetPending: joinResetPending ?? this.joinResetPending,
    lastPullCursor: lastPullCursor.present
        ? lastPullCursor.value
        : this.lastPullCursor,
    childrenPullCursor: childrenPullCursor.present
        ? childrenPullCursor.value
        : this.childrenPullCursor,
    artworksPullCursor: artworksPullCursor.present
        ? artworksPullCursor.value
        : this.artworksPullCursor,
    purgedPullCursor: purgedPullCursor.present
        ? purgedPullCursor.value
        : this.purgedPullCursor,
  );
  VaultMetaEntity copyWithCompanion(VaultMetaTableCompanion data) {
    return VaultMetaEntity(
      id: data.id.present ? data.id.value : this.id,
      familyId: data.familyId.present ? data.familyId.value : this.familyId,
      joinResetPending: data.joinResetPending.present
          ? data.joinResetPending.value
          : this.joinResetPending,
      lastPullCursor: data.lastPullCursor.present
          ? data.lastPullCursor.value
          : this.lastPullCursor,
      childrenPullCursor: data.childrenPullCursor.present
          ? data.childrenPullCursor.value
          : this.childrenPullCursor,
      artworksPullCursor: data.artworksPullCursor.present
          ? data.artworksPullCursor.value
          : this.artworksPullCursor,
      purgedPullCursor: data.purgedPullCursor.present
          ? data.purgedPullCursor.value
          : this.purgedPullCursor,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VaultMetaEntity(')
          ..write('id: $id, ')
          ..write('familyId: $familyId, ')
          ..write('joinResetPending: $joinResetPending, ')
          ..write('lastPullCursor: $lastPullCursor, ')
          ..write('childrenPullCursor: $childrenPullCursor, ')
          ..write('artworksPullCursor: $artworksPullCursor, ')
          ..write('purgedPullCursor: $purgedPullCursor')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    familyId,
    joinResetPending,
    lastPullCursor,
    childrenPullCursor,
    artworksPullCursor,
    purgedPullCursor,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VaultMetaEntity &&
          other.id == this.id &&
          other.familyId == this.familyId &&
          other.joinResetPending == this.joinResetPending &&
          other.lastPullCursor == this.lastPullCursor &&
          other.childrenPullCursor == this.childrenPullCursor &&
          other.artworksPullCursor == this.artworksPullCursor &&
          other.purgedPullCursor == this.purgedPullCursor);
}

class VaultMetaTableCompanion extends UpdateCompanion<VaultMetaEntity> {
  final Value<String> id;
  final Value<String?> familyId;
  final Value<bool> joinResetPending;
  final Value<DateTime?> lastPullCursor;
  final Value<DateTime?> childrenPullCursor;
  final Value<DateTime?> artworksPullCursor;
  final Value<DateTime?> purgedPullCursor;
  final Value<int> rowid;
  const VaultMetaTableCompanion({
    this.id = const Value.absent(),
    this.familyId = const Value.absent(),
    this.joinResetPending = const Value.absent(),
    this.lastPullCursor = const Value.absent(),
    this.childrenPullCursor = const Value.absent(),
    this.artworksPullCursor = const Value.absent(),
    this.purgedPullCursor = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VaultMetaTableCompanion.insert({
    required String id,
    this.familyId = const Value.absent(),
    this.joinResetPending = const Value.absent(),
    this.lastPullCursor = const Value.absent(),
    this.childrenPullCursor = const Value.absent(),
    this.artworksPullCursor = const Value.absent(),
    this.purgedPullCursor = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<VaultMetaEntity> custom({
    Expression<String>? id,
    Expression<String>? familyId,
    Expression<bool>? joinResetPending,
    Expression<DateTime>? lastPullCursor,
    Expression<DateTime>? childrenPullCursor,
    Expression<DateTime>? artworksPullCursor,
    Expression<DateTime>? purgedPullCursor,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (familyId != null) 'family_id': familyId,
      if (joinResetPending != null) 'join_reset_pending': joinResetPending,
      if (lastPullCursor != null) 'last_pull_cursor': lastPullCursor,
      if (childrenPullCursor != null)
        'children_pull_cursor': childrenPullCursor,
      if (artworksPullCursor != null)
        'artworks_pull_cursor': artworksPullCursor,
      if (purgedPullCursor != null) 'purged_pull_cursor': purgedPullCursor,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VaultMetaTableCompanion copyWith({
    Value<String>? id,
    Value<String?>? familyId,
    Value<bool>? joinResetPending,
    Value<DateTime?>? lastPullCursor,
    Value<DateTime?>? childrenPullCursor,
    Value<DateTime?>? artworksPullCursor,
    Value<DateTime?>? purgedPullCursor,
    Value<int>? rowid,
  }) {
    return VaultMetaTableCompanion(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      joinResetPending: joinResetPending ?? this.joinResetPending,
      lastPullCursor: lastPullCursor ?? this.lastPullCursor,
      childrenPullCursor: childrenPullCursor ?? this.childrenPullCursor,
      artworksPullCursor: artworksPullCursor ?? this.artworksPullCursor,
      purgedPullCursor: purgedPullCursor ?? this.purgedPullCursor,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (familyId.present) {
      map['family_id'] = Variable<String>(familyId.value);
    }
    if (joinResetPending.present) {
      map['join_reset_pending'] = Variable<bool>(joinResetPending.value);
    }
    if (lastPullCursor.present) {
      map['last_pull_cursor'] = Variable<DateTime>(lastPullCursor.value);
    }
    if (childrenPullCursor.present) {
      map['children_pull_cursor'] = Variable<DateTime>(
        childrenPullCursor.value,
      );
    }
    if (artworksPullCursor.present) {
      map['artworks_pull_cursor'] = Variable<DateTime>(
        artworksPullCursor.value,
      );
    }
    if (purgedPullCursor.present) {
      map['purged_pull_cursor'] = Variable<DateTime>(purgedPullCursor.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VaultMetaTableCompanion(')
          ..write('id: $id, ')
          ..write('familyId: $familyId, ')
          ..write('joinResetPending: $joinResetPending, ')
          ..write('lastPullCursor: $lastPullCursor, ')
          ..write('childrenPullCursor: $childrenPullCursor, ')
          ..write('artworksPullCursor: $artworksPullCursor, ')
          ..write('purgedPullCursor: $purgedPullCursor, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ShareLinkUrlCacheTableTable extends ShareLinkUrlCacheTable
    with TableInfo<$ShareLinkUrlCacheTableTable, ShareLinkUrlCacheEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShareLinkUrlCacheTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, url];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'share_link_url_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<ShareLinkUrlCacheEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ShareLinkUrlCacheEntity map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShareLinkUrlCacheEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
    );
  }

  @override
  $ShareLinkUrlCacheTableTable createAlias(String alias) {
    return $ShareLinkUrlCacheTableTable(attachedDatabase, alias);
  }
}

class ShareLinkUrlCacheEntity extends DataClass
    implements Insertable<ShareLinkUrlCacheEntity> {
  final String id;
  final String url;
  const ShareLinkUrlCacheEntity({required this.id, required this.url});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['url'] = Variable<String>(url);
    return map;
  }

  ShareLinkUrlCacheTableCompanion toCompanion(bool nullToAbsent) {
    return ShareLinkUrlCacheTableCompanion(id: Value(id), url: Value(url));
  }

  factory ShareLinkUrlCacheEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShareLinkUrlCacheEntity(
      id: serializer.fromJson<String>(json['id']),
      url: serializer.fromJson<String>(json['url']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'url': serializer.toJson<String>(url),
    };
  }

  ShareLinkUrlCacheEntity copyWith({String? id, String? url}) =>
      ShareLinkUrlCacheEntity(id: id ?? this.id, url: url ?? this.url);
  ShareLinkUrlCacheEntity copyWithCompanion(
    ShareLinkUrlCacheTableCompanion data,
  ) {
    return ShareLinkUrlCacheEntity(
      id: data.id.present ? data.id.value : this.id,
      url: data.url.present ? data.url.value : this.url,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShareLinkUrlCacheEntity(')
          ..write('id: $id, ')
          ..write('url: $url')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, url);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShareLinkUrlCacheEntity &&
          other.id == this.id &&
          other.url == this.url);
}

class ShareLinkUrlCacheTableCompanion
    extends UpdateCompanion<ShareLinkUrlCacheEntity> {
  final Value<String> id;
  final Value<String> url;
  final Value<int> rowid;
  const ShareLinkUrlCacheTableCompanion({
    this.id = const Value.absent(),
    this.url = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ShareLinkUrlCacheTableCompanion.insert({
    required String id,
    required String url,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       url = Value(url);
  static Insertable<ShareLinkUrlCacheEntity> custom({
    Expression<String>? id,
    Expression<String>? url,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (url != null) 'url': url,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ShareLinkUrlCacheTableCompanion copyWith({
    Value<String>? id,
    Value<String>? url,
    Value<int>? rowid,
  }) {
    return ShareLinkUrlCacheTableCompanion(
      id: id ?? this.id,
      url: url ?? this.url,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShareLinkUrlCacheTableCompanion(')
          ..write('id: $id, ')
          ..write('url: $url, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ChildrenTableTable childrenTable = $ChildrenTableTable(this);
  late final $ArtworksTableTable artworksTable = $ArtworksTableTable(this);
  late final $PendingFileCleanupsTableTable pendingFileCleanupsTable =
      $PendingFileCleanupsTableTable(this);
  late final $SyncOutboxTableTable syncOutboxTable = $SyncOutboxTableTable(
    this,
  );
  late final $VaultMetaTableTable vaultMetaTable = $VaultMetaTableTable(this);
  late final $ShareLinkUrlCacheTableTable shareLinkUrlCacheTable =
      $ShareLinkUrlCacheTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    childrenTable,
    artworksTable,
    pendingFileCleanupsTable,
    syncOutboxTable,
    vaultMetaTable,
    shareLinkUrlCacheTable,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'children',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('artworks', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$ChildrenTableTableCreateCompanionBuilder =
    ChildrenTableCompanion Function({
      required String id,
      required String name,
      required DateTime birthDate,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<String> syncState,
      Value<int> rowid,
    });
typedef $$ChildrenTableTableUpdateCompanionBuilder =
    ChildrenTableCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<DateTime> birthDate,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String> syncState,
      Value<int> rowid,
    });

final class $$ChildrenTableTableReferences
    extends BaseReferences<_$AppDatabase, $ChildrenTableTable, ChildEntity> {
  $$ChildrenTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$ArtworksTableTable, List<ArtworkEntity>>
  _artworksTableRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.artworksTable,
    aliasName: 'children__id__artworks__child_id',
  );

  $$ArtworksTableTableProcessedTableManager get artworksTableRefs {
    final manager = $$ArtworksTableTableTableManager(
      $_db,
      $_db.artworksTable,
    ).filter((f) => f.childId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_artworksTableRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ChildrenTableTableFilterComposer
    extends Composer<_$AppDatabase, $ChildrenTableTable> {
  $$ChildrenTableTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get birthDate => $composableBuilder(
    column: $table.birthDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> artworksTableRefs(
    Expression<bool> Function($$ArtworksTableTableFilterComposer f) f,
  ) {
    final $$ArtworksTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.artworksTable,
      getReferencedColumn: (t) => t.childId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArtworksTableTableFilterComposer(
            $db: $db,
            $table: $db.artworksTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ChildrenTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ChildrenTableTable> {
  $$ChildrenTableTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get birthDate => $composableBuilder(
    column: $table.birthDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChildrenTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChildrenTableTable> {
  $$ChildrenTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get birthDate =>
      $composableBuilder(column: $table.birthDate, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  Expression<T> artworksTableRefs<T extends Object>(
    Expression<T> Function($$ArtworksTableTableAnnotationComposer a) f,
  ) {
    final $$ArtworksTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.artworksTable,
      getReferencedColumn: (t) => t.childId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArtworksTableTableAnnotationComposer(
            $db: $db,
            $table: $db.artworksTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ChildrenTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChildrenTableTable,
          ChildEntity,
          $$ChildrenTableTableFilterComposer,
          $$ChildrenTableTableOrderingComposer,
          $$ChildrenTableTableAnnotationComposer,
          $$ChildrenTableTableCreateCompanionBuilder,
          $$ChildrenTableTableUpdateCompanionBuilder,
          (ChildEntity, $$ChildrenTableTableReferences),
          ChildEntity,
          PrefetchHooks Function({bool artworksTableRefs})
        > {
  $$ChildrenTableTableTableManager(_$AppDatabase db, $ChildrenTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChildrenTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChildrenTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChildrenTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> birthDate = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChildrenTableCompanion(
                id: id,
                name: name,
                birthDate: birthDate,
                createdAt: createdAt,
                updatedAt: updatedAt,
                syncState: syncState,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required DateTime birthDate,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<String> syncState = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChildrenTableCompanion.insert(
                id: id,
                name: name,
                birthDate: birthDate,
                createdAt: createdAt,
                updatedAt: updatedAt,
                syncState: syncState,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ChildrenTableTable, ChildEntity>(table),
                  $$ChildrenTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({artworksTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (artworksTableRefs) db.artworksTable,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (artworksTableRefs)
                    await $_getPrefetchedData<
                      ChildEntity,
                      $ChildrenTableTable,
                      ArtworkEntity
                    >(
                      currentTable: table,
                      referencedTable: $$ChildrenTableTableReferences
                          ._artworksTableRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ChildrenTableTableReferences(
                            db,
                            table,
                            p0,
                          ).artworksTableRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.childId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ChildrenTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChildrenTableTable,
      ChildEntity,
      $$ChildrenTableTableFilterComposer,
      $$ChildrenTableTableOrderingComposer,
      $$ChildrenTableTableAnnotationComposer,
      $$ChildrenTableTableCreateCompanionBuilder,
      $$ChildrenTableTableUpdateCompanionBuilder,
      (ChildEntity, $$ChildrenTableTableReferences),
      ChildEntity,
      PrefetchHooks Function({bool artworksTableRefs})
    >;
typedef $$ArtworksTableTableCreateCompanionBuilder =
    ArtworksTableCompanion Function({
      required String id,
      required String childId,
      Value<String?> relativeImagePath,
      required DateTime addedAt,
      Value<DateTime?> drawnAt,
      Value<String?> story,
      Value<String> syncState,
      Value<String?> displayImagePath,
      Value<String?> thumbnailImagePath,
      Value<int?> imageWidth,
      Value<int?> imageHeight,
      Value<String?> displayObjectKey,
      Value<String?> thumbnailObjectKey,
      Value<int> byteSize,
      Value<String?> relativeAudioPath,
      Value<int?> audioDurationMs,
      Value<String?> audioObjectKey,
      Value<int> audioByteSize,
      Value<String?> addedBy,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$ArtworksTableTableUpdateCompanionBuilder =
    ArtworksTableCompanion Function({
      Value<String> id,
      Value<String> childId,
      Value<String?> relativeImagePath,
      Value<DateTime> addedAt,
      Value<DateTime?> drawnAt,
      Value<String?> story,
      Value<String> syncState,
      Value<String?> displayImagePath,
      Value<String?> thumbnailImagePath,
      Value<int?> imageWidth,
      Value<int?> imageHeight,
      Value<String?> displayObjectKey,
      Value<String?> thumbnailObjectKey,
      Value<int> byteSize,
      Value<String?> relativeAudioPath,
      Value<int?> audioDurationMs,
      Value<String?> audioObjectKey,
      Value<int> audioByteSize,
      Value<String?> addedBy,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

final class $$ArtworksTableTableReferences
    extends BaseReferences<_$AppDatabase, $ArtworksTableTable, ArtworkEntity> {
  $$ArtworksTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ChildrenTableTable _childIdTable(_$AppDatabase db) =>
      db.childrenTable.createAlias('artworks__child_id__children__id');

  $$ChildrenTableTableProcessedTableManager get childId {
    final $_column = $_itemColumn<String>('child_id')!;

    final manager = $$ChildrenTableTableTableManager(
      $_db,
      $_db.childrenTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_childIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ArtworksTableTableFilterComposer
    extends Composer<_$AppDatabase, $ArtworksTableTable> {
  $$ArtworksTableTableFilterComposer({
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

  ColumnFilters<String> get relativeImagePath => $composableBuilder(
    column: $table.relativeImagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get drawnAt => $composableBuilder(
    column: $table.drawnAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get story => $composableBuilder(
    column: $table.story,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayImagePath => $composableBuilder(
    column: $table.displayImagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbnailImagePath => $composableBuilder(
    column: $table.thumbnailImagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get imageWidth => $composableBuilder(
    column: $table.imageWidth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get imageHeight => $composableBuilder(
    column: $table.imageHeight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayObjectKey => $composableBuilder(
    column: $table.displayObjectKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbnailObjectKey => $composableBuilder(
    column: $table.thumbnailObjectKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relativeAudioPath => $composableBuilder(
    column: $table.relativeAudioPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get audioDurationMs => $composableBuilder(
    column: $table.audioDurationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioObjectKey => $composableBuilder(
    column: $table.audioObjectKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get audioByteSize => $composableBuilder(
    column: $table.audioByteSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get addedBy => $composableBuilder(
    column: $table.addedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ChildrenTableTableFilterComposer get childId {
    final $$ChildrenTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.childrenTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChildrenTableTableFilterComposer(
            $db: $db,
            $table: $db.childrenTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ArtworksTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ArtworksTableTable> {
  $$ArtworksTableTableOrderingComposer({
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

  ColumnOrderings<String> get relativeImagePath => $composableBuilder(
    column: $table.relativeImagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get drawnAt => $composableBuilder(
    column: $table.drawnAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get story => $composableBuilder(
    column: $table.story,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayImagePath => $composableBuilder(
    column: $table.displayImagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbnailImagePath => $composableBuilder(
    column: $table.thumbnailImagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get imageWidth => $composableBuilder(
    column: $table.imageWidth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get imageHeight => $composableBuilder(
    column: $table.imageHeight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayObjectKey => $composableBuilder(
    column: $table.displayObjectKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbnailObjectKey => $composableBuilder(
    column: $table.thumbnailObjectKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relativeAudioPath => $composableBuilder(
    column: $table.relativeAudioPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get audioDurationMs => $composableBuilder(
    column: $table.audioDurationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioObjectKey => $composableBuilder(
    column: $table.audioObjectKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get audioByteSize => $composableBuilder(
    column: $table.audioByteSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get addedBy => $composableBuilder(
    column: $table.addedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ChildrenTableTableOrderingComposer get childId {
    final $$ChildrenTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.childrenTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChildrenTableTableOrderingComposer(
            $db: $db,
            $table: $db.childrenTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ArtworksTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ArtworksTableTable> {
  $$ArtworksTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get relativeImagePath => $composableBuilder(
    column: $table.relativeImagePath,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get drawnAt =>
      $composableBuilder(column: $table.drawnAt, builder: (column) => column);

  GeneratedColumn<String> get story =>
      $composableBuilder(column: $table.story, builder: (column) => column);

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<String> get displayImagePath => $composableBuilder(
    column: $table.displayImagePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get thumbnailImagePath => $composableBuilder(
    column: $table.thumbnailImagePath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get imageWidth => $composableBuilder(
    column: $table.imageWidth,
    builder: (column) => column,
  );

  GeneratedColumn<int> get imageHeight => $composableBuilder(
    column: $table.imageHeight,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayObjectKey => $composableBuilder(
    column: $table.displayObjectKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get thumbnailObjectKey => $composableBuilder(
    column: $table.thumbnailObjectKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get byteSize =>
      $composableBuilder(column: $table.byteSize, builder: (column) => column);

  GeneratedColumn<String> get relativeAudioPath => $composableBuilder(
    column: $table.relativeAudioPath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get audioDurationMs => $composableBuilder(
    column: $table.audioDurationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get audioObjectKey => $composableBuilder(
    column: $table.audioObjectKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get audioByteSize => $composableBuilder(
    column: $table.audioByteSize,
    builder: (column) => column,
  );

  GeneratedColumn<String> get addedBy =>
      $composableBuilder(column: $table.addedBy, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$ChildrenTableTableAnnotationComposer get childId {
    final $$ChildrenTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.childrenTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChildrenTableTableAnnotationComposer(
            $db: $db,
            $table: $db.childrenTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ArtworksTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ArtworksTableTable,
          ArtworkEntity,
          $$ArtworksTableTableFilterComposer,
          $$ArtworksTableTableOrderingComposer,
          $$ArtworksTableTableAnnotationComposer,
          $$ArtworksTableTableCreateCompanionBuilder,
          $$ArtworksTableTableUpdateCompanionBuilder,
          (ArtworkEntity, $$ArtworksTableTableReferences),
          ArtworkEntity,
          PrefetchHooks Function({bool childId})
        > {
  $$ArtworksTableTableTableManager(_$AppDatabase db, $ArtworksTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ArtworksTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ArtworksTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ArtworksTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> childId = const Value.absent(),
                Value<String?> relativeImagePath = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<DateTime?> drawnAt = const Value.absent(),
                Value<String?> story = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<String?> displayImagePath = const Value.absent(),
                Value<String?> thumbnailImagePath = const Value.absent(),
                Value<int?> imageWidth = const Value.absent(),
                Value<int?> imageHeight = const Value.absent(),
                Value<String?> displayObjectKey = const Value.absent(),
                Value<String?> thumbnailObjectKey = const Value.absent(),
                Value<int> byteSize = const Value.absent(),
                Value<String?> relativeAudioPath = const Value.absent(),
                Value<int?> audioDurationMs = const Value.absent(),
                Value<String?> audioObjectKey = const Value.absent(),
                Value<int> audioByteSize = const Value.absent(),
                Value<String?> addedBy = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ArtworksTableCompanion(
                id: id,
                childId: childId,
                relativeImagePath: relativeImagePath,
                addedAt: addedAt,
                drawnAt: drawnAt,
                story: story,
                syncState: syncState,
                displayImagePath: displayImagePath,
                thumbnailImagePath: thumbnailImagePath,
                imageWidth: imageWidth,
                imageHeight: imageHeight,
                displayObjectKey: displayObjectKey,
                thumbnailObjectKey: thumbnailObjectKey,
                byteSize: byteSize,
                relativeAudioPath: relativeAudioPath,
                audioDurationMs: audioDurationMs,
                audioObjectKey: audioObjectKey,
                audioByteSize: audioByteSize,
                addedBy: addedBy,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String childId,
                Value<String?> relativeImagePath = const Value.absent(),
                required DateTime addedAt,
                Value<DateTime?> drawnAt = const Value.absent(),
                Value<String?> story = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<String?> displayImagePath = const Value.absent(),
                Value<String?> thumbnailImagePath = const Value.absent(),
                Value<int?> imageWidth = const Value.absent(),
                Value<int?> imageHeight = const Value.absent(),
                Value<String?> displayObjectKey = const Value.absent(),
                Value<String?> thumbnailObjectKey = const Value.absent(),
                Value<int> byteSize = const Value.absent(),
                Value<String?> relativeAudioPath = const Value.absent(),
                Value<int?> audioDurationMs = const Value.absent(),
                Value<String?> audioObjectKey = const Value.absent(),
                Value<int> audioByteSize = const Value.absent(),
                Value<String?> addedBy = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ArtworksTableCompanion.insert(
                id: id,
                childId: childId,
                relativeImagePath: relativeImagePath,
                addedAt: addedAt,
                drawnAt: drawnAt,
                story: story,
                syncState: syncState,
                displayImagePath: displayImagePath,
                thumbnailImagePath: thumbnailImagePath,
                imageWidth: imageWidth,
                imageHeight: imageHeight,
                displayObjectKey: displayObjectKey,
                thumbnailObjectKey: thumbnailObjectKey,
                byteSize: byteSize,
                relativeAudioPath: relativeAudioPath,
                audioDurationMs: audioDurationMs,
                audioObjectKey: audioObjectKey,
                audioByteSize: audioByteSize,
                addedBy: addedBy,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ArtworksTableTable, ArtworkEntity>(table),
                  $$ArtworksTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({childId = false}) {
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
                    if (childId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.childId,
                                referencedTable: $$ArtworksTableTableReferences
                                    ._childIdTable(db),
                                referencedColumn: $$ArtworksTableTableReferences
                                    ._childIdTable(db)
                                    .id,
                              )
                              as T;
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

typedef $$ArtworksTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ArtworksTableTable,
      ArtworkEntity,
      $$ArtworksTableTableFilterComposer,
      $$ArtworksTableTableOrderingComposer,
      $$ArtworksTableTableAnnotationComposer,
      $$ArtworksTableTableCreateCompanionBuilder,
      $$ArtworksTableTableUpdateCompanionBuilder,
      (ArtworkEntity, $$ArtworksTableTableReferences),
      ArtworkEntity,
      PrefetchHooks Function({bool childId})
    >;
typedef $$PendingFileCleanupsTableTableCreateCompanionBuilder =
    PendingFileCleanupsTableCompanion Function({
      required String relativePath,
      required DateTime failedAt,
      Value<int> rowid,
    });
typedef $$PendingFileCleanupsTableTableUpdateCompanionBuilder =
    PendingFileCleanupsTableCompanion Function({
      Value<String> relativePath,
      Value<DateTime> failedAt,
      Value<int> rowid,
    });

class $$PendingFileCleanupsTableTableFilterComposer
    extends Composer<_$AppDatabase, $PendingFileCleanupsTableTable> {
  $$PendingFileCleanupsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get failedAt => $composableBuilder(
    column: $table.failedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingFileCleanupsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingFileCleanupsTableTable> {
  $$PendingFileCleanupsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get failedAt => $composableBuilder(
    column: $table.failedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingFileCleanupsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingFileCleanupsTableTable> {
  $$PendingFileCleanupsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get failedAt =>
      $composableBuilder(column: $table.failedAt, builder: (column) => column);
}

class $$PendingFileCleanupsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingFileCleanupsTableTable,
          PendingFileCleanupEntity,
          $$PendingFileCleanupsTableTableFilterComposer,
          $$PendingFileCleanupsTableTableOrderingComposer,
          $$PendingFileCleanupsTableTableAnnotationComposer,
          $$PendingFileCleanupsTableTableCreateCompanionBuilder,
          $$PendingFileCleanupsTableTableUpdateCompanionBuilder,
          (
            PendingFileCleanupEntity,
            BaseReferences<
              _$AppDatabase,
              $PendingFileCleanupsTableTable,
              PendingFileCleanupEntity
            >,
          ),
          PendingFileCleanupEntity,
          PrefetchHooks Function()
        > {
  $$PendingFileCleanupsTableTableTableManager(
    _$AppDatabase db,
    $PendingFileCleanupsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingFileCleanupsTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$PendingFileCleanupsTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PendingFileCleanupsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> relativePath = const Value.absent(),
                Value<DateTime> failedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingFileCleanupsTableCompanion(
                relativePath: relativePath,
                failedAt: failedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String relativePath,
                required DateTime failedAt,
                Value<int> rowid = const Value.absent(),
              }) => PendingFileCleanupsTableCompanion.insert(
                relativePath: relativePath,
                failedAt: failedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $PendingFileCleanupsTableTable,
                    PendingFileCleanupEntity
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $PendingFileCleanupsTableTable,
                    PendingFileCleanupEntity
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingFileCleanupsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingFileCleanupsTableTable,
      PendingFileCleanupEntity,
      $$PendingFileCleanupsTableTableFilterComposer,
      $$PendingFileCleanupsTableTableOrderingComposer,
      $$PendingFileCleanupsTableTableAnnotationComposer,
      $$PendingFileCleanupsTableTableCreateCompanionBuilder,
      $$PendingFileCleanupsTableTableUpdateCompanionBuilder,
      (
        PendingFileCleanupEntity,
        BaseReferences<
          _$AppDatabase,
          $PendingFileCleanupsTableTable,
          PendingFileCleanupEntity
        >,
      ),
      PendingFileCleanupEntity,
      PrefetchHooks Function()
    >;
typedef $$SyncOutboxTableTableCreateCompanionBuilder =
    SyncOutboxTableCompanion Function({
      Value<int> seq,
      required String entity,
      required String entityId,
      required String op,
      Value<int> attempts,
      Value<DateTime?> nextAttemptAt,
      Value<String?> lastError,
      required DateTime createdAt,
    });
typedef $$SyncOutboxTableTableUpdateCompanionBuilder =
    SyncOutboxTableCompanion Function({
      Value<int> seq,
      Value<String> entity,
      Value<String> entityId,
      Value<String> op,
      Value<int> attempts,
      Value<DateTime?> nextAttemptAt,
      Value<String?> lastError,
      Value<DateTime> createdAt,
    });

class $$SyncOutboxTableTableFilterComposer
    extends Composer<_$AppDatabase, $SyncOutboxTableTable> {
  $$SyncOutboxTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncOutboxTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncOutboxTableTable> {
  $$SyncOutboxTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncOutboxTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncOutboxTableTable> {
  $$SyncOutboxTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get op =>
      $composableBuilder(column: $table.op, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SyncOutboxTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncOutboxTableTable,
          SyncOutboxEntryEntity,
          $$SyncOutboxTableTableFilterComposer,
          $$SyncOutboxTableTableOrderingComposer,
          $$SyncOutboxTableTableAnnotationComposer,
          $$SyncOutboxTableTableCreateCompanionBuilder,
          $$SyncOutboxTableTableUpdateCompanionBuilder,
          (
            SyncOutboxEntryEntity,
            BaseReferences<
              _$AppDatabase,
              $SyncOutboxTableTable,
              SyncOutboxEntryEntity
            >,
          ),
          SyncOutboxEntryEntity,
          PrefetchHooks Function()
        > {
  $$SyncOutboxTableTableTableManager(
    _$AppDatabase db,
    $SyncOutboxTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncOutboxTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncOutboxTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncOutboxTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                Value<String> entity = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> op = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => SyncOutboxTableCompanion(
                seq: seq,
                entity: entity,
                entityId: entityId,
                op: op,
                attempts: attempts,
                nextAttemptAt: nextAttemptAt,
                lastError: lastError,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                required String entity,
                required String entityId,
                required String op,
                Value<int> attempts = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                required DateTime createdAt,
              }) => SyncOutboxTableCompanion.insert(
                seq: seq,
                entity: entity,
                entityId: entityId,
                op: op,
                attempts: attempts,
                nextAttemptAt: nextAttemptAt,
                lastError: lastError,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncOutboxTableTable, SyncOutboxEntryEntity>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $SyncOutboxTableTable,
                    SyncOutboxEntryEntity
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncOutboxTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncOutboxTableTable,
      SyncOutboxEntryEntity,
      $$SyncOutboxTableTableFilterComposer,
      $$SyncOutboxTableTableOrderingComposer,
      $$SyncOutboxTableTableAnnotationComposer,
      $$SyncOutboxTableTableCreateCompanionBuilder,
      $$SyncOutboxTableTableUpdateCompanionBuilder,
      (
        SyncOutboxEntryEntity,
        BaseReferences<
          _$AppDatabase,
          $SyncOutboxTableTable,
          SyncOutboxEntryEntity
        >,
      ),
      SyncOutboxEntryEntity,
      PrefetchHooks Function()
    >;
typedef $$VaultMetaTableTableCreateCompanionBuilder =
    VaultMetaTableCompanion Function({
      required String id,
      Value<String?> familyId,
      Value<bool> joinResetPending,
      Value<DateTime?> lastPullCursor,
      Value<DateTime?> childrenPullCursor,
      Value<DateTime?> artworksPullCursor,
      Value<DateTime?> purgedPullCursor,
      Value<int> rowid,
    });
typedef $$VaultMetaTableTableUpdateCompanionBuilder =
    VaultMetaTableCompanion Function({
      Value<String> id,
      Value<String?> familyId,
      Value<bool> joinResetPending,
      Value<DateTime?> lastPullCursor,
      Value<DateTime?> childrenPullCursor,
      Value<DateTime?> artworksPullCursor,
      Value<DateTime?> purgedPullCursor,
      Value<int> rowid,
    });

class $$VaultMetaTableTableFilterComposer
    extends Composer<_$AppDatabase, $VaultMetaTableTable> {
  $$VaultMetaTableTableFilterComposer({
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

  ColumnFilters<String> get familyId => $composableBuilder(
    column: $table.familyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get joinResetPending => $composableBuilder(
    column: $table.joinResetPending,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastPullCursor => $composableBuilder(
    column: $table.lastPullCursor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get childrenPullCursor => $composableBuilder(
    column: $table.childrenPullCursor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get artworksPullCursor => $composableBuilder(
    column: $table.artworksPullCursor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get purgedPullCursor => $composableBuilder(
    column: $table.purgedPullCursor,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VaultMetaTableTableOrderingComposer
    extends Composer<_$AppDatabase, $VaultMetaTableTable> {
  $$VaultMetaTableTableOrderingComposer({
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

  ColumnOrderings<String> get familyId => $composableBuilder(
    column: $table.familyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get joinResetPending => $composableBuilder(
    column: $table.joinResetPending,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastPullCursor => $composableBuilder(
    column: $table.lastPullCursor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get childrenPullCursor => $composableBuilder(
    column: $table.childrenPullCursor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get artworksPullCursor => $composableBuilder(
    column: $table.artworksPullCursor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get purgedPullCursor => $composableBuilder(
    column: $table.purgedPullCursor,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VaultMetaTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $VaultMetaTableTable> {
  $$VaultMetaTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get familyId =>
      $composableBuilder(column: $table.familyId, builder: (column) => column);

  GeneratedColumn<bool> get joinResetPending => $composableBuilder(
    column: $table.joinResetPending,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastPullCursor => $composableBuilder(
    column: $table.lastPullCursor,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get childrenPullCursor => $composableBuilder(
    column: $table.childrenPullCursor,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get artworksPullCursor => $composableBuilder(
    column: $table.artworksPullCursor,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get purgedPullCursor => $composableBuilder(
    column: $table.purgedPullCursor,
    builder: (column) => column,
  );
}

class $$VaultMetaTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VaultMetaTableTable,
          VaultMetaEntity,
          $$VaultMetaTableTableFilterComposer,
          $$VaultMetaTableTableOrderingComposer,
          $$VaultMetaTableTableAnnotationComposer,
          $$VaultMetaTableTableCreateCompanionBuilder,
          $$VaultMetaTableTableUpdateCompanionBuilder,
          (
            VaultMetaEntity,
            BaseReferences<
              _$AppDatabase,
              $VaultMetaTableTable,
              VaultMetaEntity
            >,
          ),
          VaultMetaEntity,
          PrefetchHooks Function()
        > {
  $$VaultMetaTableTableTableManager(
    _$AppDatabase db,
    $VaultMetaTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VaultMetaTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VaultMetaTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VaultMetaTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> familyId = const Value.absent(),
                Value<bool> joinResetPending = const Value.absent(),
                Value<DateTime?> lastPullCursor = const Value.absent(),
                Value<DateTime?> childrenPullCursor = const Value.absent(),
                Value<DateTime?> artworksPullCursor = const Value.absent(),
                Value<DateTime?> purgedPullCursor = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VaultMetaTableCompanion(
                id: id,
                familyId: familyId,
                joinResetPending: joinResetPending,
                lastPullCursor: lastPullCursor,
                childrenPullCursor: childrenPullCursor,
                artworksPullCursor: artworksPullCursor,
                purgedPullCursor: purgedPullCursor,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> familyId = const Value.absent(),
                Value<bool> joinResetPending = const Value.absent(),
                Value<DateTime?> lastPullCursor = const Value.absent(),
                Value<DateTime?> childrenPullCursor = const Value.absent(),
                Value<DateTime?> artworksPullCursor = const Value.absent(),
                Value<DateTime?> purgedPullCursor = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VaultMetaTableCompanion.insert(
                id: id,
                familyId: familyId,
                joinResetPending: joinResetPending,
                lastPullCursor: lastPullCursor,
                childrenPullCursor: childrenPullCursor,
                artworksPullCursor: artworksPullCursor,
                purgedPullCursor: purgedPullCursor,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$VaultMetaTableTable, VaultMetaEntity>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $VaultMetaTableTable,
                    VaultMetaEntity
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VaultMetaTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VaultMetaTableTable,
      VaultMetaEntity,
      $$VaultMetaTableTableFilterComposer,
      $$VaultMetaTableTableOrderingComposer,
      $$VaultMetaTableTableAnnotationComposer,
      $$VaultMetaTableTableCreateCompanionBuilder,
      $$VaultMetaTableTableUpdateCompanionBuilder,
      (
        VaultMetaEntity,
        BaseReferences<_$AppDatabase, $VaultMetaTableTable, VaultMetaEntity>,
      ),
      VaultMetaEntity,
      PrefetchHooks Function()
    >;
typedef $$ShareLinkUrlCacheTableTableCreateCompanionBuilder =
    ShareLinkUrlCacheTableCompanion Function({
      required String id,
      required String url,
      Value<int> rowid,
    });
typedef $$ShareLinkUrlCacheTableTableUpdateCompanionBuilder =
    ShareLinkUrlCacheTableCompanion Function({
      Value<String> id,
      Value<String> url,
      Value<int> rowid,
    });

class $$ShareLinkUrlCacheTableTableFilterComposer
    extends Composer<_$AppDatabase, $ShareLinkUrlCacheTableTable> {
  $$ShareLinkUrlCacheTableTableFilterComposer({
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

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ShareLinkUrlCacheTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ShareLinkUrlCacheTableTable> {
  $$ShareLinkUrlCacheTableTableOrderingComposer({
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

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ShareLinkUrlCacheTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShareLinkUrlCacheTableTable> {
  $$ShareLinkUrlCacheTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);
}

class $$ShareLinkUrlCacheTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ShareLinkUrlCacheTableTable,
          ShareLinkUrlCacheEntity,
          $$ShareLinkUrlCacheTableTableFilterComposer,
          $$ShareLinkUrlCacheTableTableOrderingComposer,
          $$ShareLinkUrlCacheTableTableAnnotationComposer,
          $$ShareLinkUrlCacheTableTableCreateCompanionBuilder,
          $$ShareLinkUrlCacheTableTableUpdateCompanionBuilder,
          (
            ShareLinkUrlCacheEntity,
            BaseReferences<
              _$AppDatabase,
              $ShareLinkUrlCacheTableTable,
              ShareLinkUrlCacheEntity
            >,
          ),
          ShareLinkUrlCacheEntity,
          PrefetchHooks Function()
        > {
  $$ShareLinkUrlCacheTableTableTableManager(
    _$AppDatabase db,
    $ShareLinkUrlCacheTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShareLinkUrlCacheTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ShareLinkUrlCacheTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ShareLinkUrlCacheTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ShareLinkUrlCacheTableCompanion(
                id: id,
                url: url,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String url,
                Value<int> rowid = const Value.absent(),
              }) => ShareLinkUrlCacheTableCompanion.insert(
                id: id,
                url: url,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $ShareLinkUrlCacheTableTable,
                    ShareLinkUrlCacheEntity
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ShareLinkUrlCacheTableTable,
                    ShareLinkUrlCacheEntity
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ShareLinkUrlCacheTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ShareLinkUrlCacheTableTable,
      ShareLinkUrlCacheEntity,
      $$ShareLinkUrlCacheTableTableFilterComposer,
      $$ShareLinkUrlCacheTableTableOrderingComposer,
      $$ShareLinkUrlCacheTableTableAnnotationComposer,
      $$ShareLinkUrlCacheTableTableCreateCompanionBuilder,
      $$ShareLinkUrlCacheTableTableUpdateCompanionBuilder,
      (
        ShareLinkUrlCacheEntity,
        BaseReferences<
          _$AppDatabase,
          $ShareLinkUrlCacheTableTable,
          ShareLinkUrlCacheEntity
        >,
      ),
      ShareLinkUrlCacheEntity,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ChildrenTableTableTableManager get childrenTable =>
      $$ChildrenTableTableTableManager(_db, _db.childrenTable);
  $$ArtworksTableTableTableManager get artworksTable =>
      $$ArtworksTableTableTableManager(_db, _db.artworksTable);
  $$PendingFileCleanupsTableTableTableManager get pendingFileCleanupsTable =>
      $$PendingFileCleanupsTableTableTableManager(
        _db,
        _db.pendingFileCleanupsTable,
      );
  $$SyncOutboxTableTableTableManager get syncOutboxTable =>
      $$SyncOutboxTableTableTableManager(_db, _db.syncOutboxTable);
  $$VaultMetaTableTableTableManager get vaultMetaTable =>
      $$VaultMetaTableTableTableManager(_db, _db.vaultMetaTable);
  $$ShareLinkUrlCacheTableTableTableManager get shareLinkUrlCacheTable =>
      $$ShareLinkUrlCacheTableTableTableManager(
        _db,
        _db.shareLinkUrlCacheTable,
      );
}
