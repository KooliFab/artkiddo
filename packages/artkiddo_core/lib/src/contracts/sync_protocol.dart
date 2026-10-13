/// Vendor-neutral synchronization protocol, version 3.
///
/// The protocol has three parts:
///
/// * **Replayable operations.** Every local edit becomes one [EntityPatch]
///   identified by an `opId` generated on the device. The remote side
///   applies a given `opId` at most once and answers every replay with the
///   same [MutationReceipt].
/// * **Per-field revisions.** A patch names the revision each field was
///   based on. Independent fields merge; the same field changed to a
///   different value on two devices becomes an explicit [FieldConflict]
///   that keeps both values.
/// * **An ordered change journal.** [SyncChangePage]s are read with an
///   opaque [ChangeCursor]; a [ChangeCursor.generation] change tells the
///   device that its cursor no longer describes the remote history.
///
/// Merge rules by field
///
/// | Entity  | Field       | Rule                                          |
/// |---------|-------------|-----------------------------------------------|
/// | child   | `name`      | independent revision                          |
/// | child   | `birthDate` | independent revision                          |
/// | child   | `lifecycle` | lifecycle (`active`, `purged`)                |
/// | artwork | `childId`   | create-only                                   |
/// | artwork | `addedAt`   | create-only                                   |
/// | artwork | `photo`     | create-only optimized photo version           |
/// | artwork | `story`     | independent revision                          |
/// | artwork | `drawnAt`   | independent revision                          |
/// | artwork | `audio`     | indivisible media version (file, duration,    |
/// |         |             | size and revision change together)            |
/// | artwork | `lifecycle` | lifecycle (`active`, `trashed`, `purged`)     |
/// | artwork | `addedBy`   | remote-owned, read only                       |
///
/// For every field of a patch the remote side applies one rule:
///
/// 1. base revision equals the current revision: the value is accepted
///    and the field revision is incremented;
/// 2. the submitted value equals the current value: accepted with the
///    current revision, no conflict (identical concurrent edit);
/// 3. otherwise: a [FieldConflict] carrying both values; the remote value
///    is kept and the local value must stay durable until an explicit
///    resolution, which is itself a new patch.
///
/// An edit that reaches a trashed, purged or unknown entity is never
/// applied and never resurrects it: every field of the patch comes back as
/// a [FieldConflictKind.deleteVsEdit] conflict, so the device keeps the
/// edit for recovery.
///
/// The JSON produced by `toJson` is the neutral, durable encoding used to
/// persist operations, receipts and conflicts locally. A private adapter
/// owns the mapping to and from its own transport.
library;

/// Maximum number of changes in one [SyncChangePage].
const int kMaxChangePageSize = 200;

/// Upper bound of the longest edge of a cloud photo, in pixels.
const int kOptimizedPhotoMaxEdgePx = 1600;

/// Upper bound of a cloud photo, in bytes.
const int kOptimizedPhotoMaxBytes = 300000;

// ---------------------------------------------------------------------------
// Entities and fields
// ---------------------------------------------------------------------------

enum SyncEntityType { child, artwork }

/// JSON shape of a field value.
enum SyncValueType {
  /// A non-empty string.
  text,

  /// A calendar date, `YYYY-MM-DD`, without time zone.
  date,

  /// An ISO-8601 instant in UTC.
  instant,

  /// A lowercase UUID.
  id,

  /// A [MediaRef] encoded with [MediaRef.toJson].
  mediaRef,

  /// One of [SyncLifecycle]'s names.
  lifecycle,
}

/// How concurrent writes to one field are reconciled.
enum FieldMergeRule {
  /// Own revision; identical values merge, different values conflict.
  independent,

  /// One media version; file, duration, size and revision are a single
  /// value, so a concurrent different version is a
  /// [FieldConflictKind.audio] conflict.
  indivisibleMedia,

  /// Written once, at creation (base revision 0). A later different value
  /// conflicts.
  createOnly,

  /// Entity lifecycle. A non-`active` value turns edits of every other
  /// field into [FieldConflictKind.deleteVsEdit] conflicts; `purged` is
  /// terminal. A patch that changes the lifecycle changes nothing else.
  lifecycle,

  /// Set by the remote side; never part of a patch.
  remoteOwned,
}

/// Lifecycle states. Children have no trash: a child is `active` or
/// `purged` (explicit, irreversible deletion).
enum SyncLifecycle { active, trashed, purged }

final class SyncFieldSpec {
  final String name;
  final SyncValueType type;
  final bool nullable;
  final FieldMergeRule rule;

  /// Required role of the media referenced by a [SyncValueType.mediaRef]
  /// field.
  final MediaRole? mediaRole;

  const SyncFieldSpec(
    this.name,
    this.type,
    this.rule, {
    this.nullable = false,
    this.mediaRole,
  });
}

abstract final class ChildSyncFields {
  static const name = 'name';
  static const birthDate = 'birthDate';
  static const lifecycle = 'lifecycle';

  static const lifecycles = {SyncLifecycle.active, SyncLifecycle.purged};

  /// Fields a creation patch must carry.
  static const requiredOnCreate = {name, birthDate};

  static const specs = <String, SyncFieldSpec>{
    name: SyncFieldSpec(name, SyncValueType.text, FieldMergeRule.independent),
    birthDate: SyncFieldSpec(
      birthDate,
      SyncValueType.date,
      FieldMergeRule.independent,
    ),
    lifecycle: SyncFieldSpec(
      lifecycle,
      SyncValueType.lifecycle,
      FieldMergeRule.lifecycle,
    ),
  };
}

abstract final class ArtworkSyncFields {
  static const childId = 'childId';
  static const addedAt = 'addedAt';
  static const photo = 'photo';
  static const story = 'story';
  static const drawnAt = 'drawnAt';
  static const audio = 'audio';
  static const lifecycle = 'lifecycle';
  static const addedBy = 'addedBy';

  static const lifecycles = {
    SyncLifecycle.active,
    SyncLifecycle.trashed,
    SyncLifecycle.purged,
  };

  /// Fields a creation patch must carry.
  static const requiredOnCreate = {childId, addedAt, photo};

  static const specs = <String, SyncFieldSpec>{
    childId: SyncFieldSpec(
      childId,
      SyncValueType.id,
      FieldMergeRule.createOnly,
    ),
    addedAt: SyncFieldSpec(
      addedAt,
      SyncValueType.instant,
      FieldMergeRule.createOnly,
    ),
    photo: SyncFieldSpec(
      photo,
      SyncValueType.mediaRef,
      FieldMergeRule.createOnly,
      mediaRole: MediaRole.optimized,
    ),
    story: SyncFieldSpec(
      story,
      SyncValueType.text,
      FieldMergeRule.independent,
      nullable: true,
    ),
    drawnAt: SyncFieldSpec(
      drawnAt,
      SyncValueType.date,
      FieldMergeRule.independent,
      nullable: true,
    ),
    audio: SyncFieldSpec(
      audio,
      SyncValueType.mediaRef,
      FieldMergeRule.indivisibleMedia,
      nullable: true,
      mediaRole: MediaRole.audio,
    ),
    lifecycle: SyncFieldSpec(
      lifecycle,
      SyncValueType.lifecycle,
      FieldMergeRule.lifecycle,
    ),
    addedBy: SyncFieldSpec(
      addedBy,
      SyncValueType.id,
      FieldMergeRule.remoteOwned,
      nullable: true,
    ),
  };
}

/// Field specifications of [type].
Map<String, SyncFieldSpec> syncFieldSpecs(SyncEntityType type) =>
    switch (type) {
      SyncEntityType.child => ChildSyncFields.specs,
      SyncEntityType.artwork => ArtworkSyncFields.specs,
    };

Set<SyncLifecycle> _lifecyclesOf(SyncEntityType type) => switch (type) {
  SyncEntityType.child => ChildSyncFields.lifecycles,
  SyncEntityType.artwork => ArtworkSyncFields.lifecycles,
};

/// Encodes a calendar date as a [SyncValueType.date] value.
String syncDateValue(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Encodes an instant as a [SyncValueType.instant] value.
String syncInstantValue(DateTime instant) => instant.toUtc().toIso8601String();

// ---------------------------------------------------------------------------
// Media
// ---------------------------------------------------------------------------

/// The original stays on the device; only `optimized` photos and `audio`
/// are sent to a remote backup. Their hashes are never interchangeable.
enum MediaRole { original, optimized, audio }

enum MediaFormat { jpeg, png, heic, webp, m4a }

const _formatsByRole = <MediaRole, Set<MediaFormat>>{
  MediaRole.original: {
    MediaFormat.jpeg,
    MediaFormat.png,
    MediaFormat.heic,
    MediaFormat.webp,
  },
  MediaRole.optimized: {MediaFormat.jpeg},
  MediaRole.audio: {MediaFormat.m4a},
};

/// Identity of one immutable media version: the value of a
/// [SyncValueType.mediaRef] field.
final class MediaRef {
  final String mediaId;
  final int version;

  MediaRef({required this.mediaId, required this.version}) {
    _require(_isUuid(mediaId), 'mediaId must be a UUID');
    _require(version >= 1, 'version must be >= 1');
  }

  factory MediaRef.fromJson(Object? json) => _decode('MediaRef', () {
    final map = _asMap(json);
    _onlyKeys(map, const {'mediaId', 'version'});
    return MediaRef(
      mediaId: map['mediaId'] as String,
      version: map['version'] as int,
    );
  });

  Map<String, Object?> toJson() => {'mediaId': mediaId, 'version': version};

  @override
  bool operator ==(Object other) =>
      other is MediaRef && other.mediaId == mediaId && other.version == version;

  @override
  int get hashCode => Object.hash(mediaId, version);

  @override
  String toString() => 'MediaRef($mediaId v$version)';
}

/// Exact description of one immutable media version. A new recording or a
/// new photo is a new version; the bytes of a version never change.
final class MediaDescriptor {
  final String mediaId;
  final int version;
  final MediaRole role;
  final MediaFormat format;
  final int byteSize;

  /// Lowercase hex SHA-256 of the exact bytes.
  final String sha256;

  /// Required for [MediaRole.audio], absent otherwise.
  final int? durationMs;

  /// Required for [MediaRole.optimized], optional for
  /// [MediaRole.original], absent for [MediaRole.audio].
  final int? widthPx;
  final int? heightPx;

  MediaDescriptor({
    required this.mediaId,
    required this.version,
    required this.role,
    required this.format,
    required this.byteSize,
    required this.sha256,
    this.durationMs,
    this.widthPx,
    this.heightPx,
  }) {
    _require(_isUuid(mediaId), 'mediaId must be a UUID');
    _require(version >= 1, 'version must be >= 1');
    _require(byteSize >= 1, 'byteSize must be >= 1');
    _require(_sha256.hasMatch(sha256), 'sha256 must be 64 lowercase hex');
    _require(
      _formatsByRole[role]!.contains(format),
      '${format.name} is not a valid format for ${role.name}',
    );
    final isAudio = role == MediaRole.audio;
    _require(
      isAudio ? (durationMs ?? 0) >= 1 : durationMs == null,
      isAudio ? 'audio requires durationMs >= 1' : 'durationMs is audio-only',
    );
    _require(
      (widthPx == null) == (heightPx == null),
      'widthPx and heightPx go together',
    );
    _require(
      widthPx == null || (widthPx! >= 1 && heightPx! >= 1),
      'dimensions must be >= 1',
    );
    switch (role) {
      case MediaRole.audio:
        _require(widthPx == null, 'audio has no dimensions');
      case MediaRole.optimized:
        _require(widthPx != null, 'optimized photo requires dimensions');
        _require(
          widthPx! <= kOptimizedPhotoMaxEdgePx &&
              heightPx! <= kOptimizedPhotoMaxEdgePx,
          'optimized photo exceeds $kOptimizedPhotoMaxEdgePx px',
        );
        _require(
          byteSize <= kOptimizedPhotoMaxBytes,
          'optimized photo exceeds $kOptimizedPhotoMaxBytes bytes',
        );
      case MediaRole.original:
        break;
    }
  }

  MediaRef get ref => MediaRef(mediaId: mediaId, version: version);

  factory MediaDescriptor.fromJson(Object? json) =>
      _decode('MediaDescriptor', () {
        final map = _asMap(json);
        _onlyKeys(map, const {
          'mediaId',
          'version',
          'role',
          'format',
          'byteSize',
          'sha256',
          'durationMs',
          'widthPx',
          'heightPx',
        });
        return MediaDescriptor(
          mediaId: map['mediaId'] as String,
          version: map['version'] as int,
          role: MediaRole.values.byName(map['role'] as String),
          format: MediaFormat.values.byName(map['format'] as String),
          byteSize: map['byteSize'] as int,
          sha256: map['sha256'] as String,
          durationMs: map['durationMs'] as int?,
          widthPx: map['widthPx'] as int?,
          heightPx: map['heightPx'] as int?,
        );
      });

  Map<String, Object?> toJson() => {
    'mediaId': mediaId,
    'version': version,
    'role': role.name,
    'format': format.name,
    'byteSize': byteSize,
    'sha256': sha256,
    if (durationMs != null) 'durationMs': durationMs,
    if (widthPx != null) 'widthPx': widthPx,
    if (heightPx != null) 'heightPx': heightPx,
  };

  @override
  bool operator ==(Object other) =>
      other is MediaDescriptor && _jsonEquals(other.toJson(), toJson());

  @override
  int get hashCode => _jsonHash(toJson());
}

// ---------------------------------------------------------------------------
// Mutations
// ---------------------------------------------------------------------------

/// One immutable, replayable local operation on one entity.
///
/// Once sent, a patch never changes: an edit made while it is in flight is
/// a new patch with a new [opId]. Every field in [fields] has exactly one
/// entry in [baseRevisions]: the last remote revision of that field the
/// device knew, `0` when the remote side has never had it.
final class EntityPatch {
  /// UUID v4 generated on the device.
  final String opId;
  final SyncEntityType entityType;
  final String entityId;
  final Map<String, int> baseRevisions;

  /// JSON-compatible values, typed by [syncFieldSpecs].
  final Map<String, Object?> fields;

  /// Exact descriptor of every [MediaRef] referenced by [fields], and
  /// nothing else. Originals are never part of a patch.
  final List<MediaDescriptor> media;
  final DateTime createdAt;

  EntityPatch({
    required this.opId,
    required this.entityType,
    required this.entityId,
    required Map<String, int> baseRevisions,
    required Map<String, Object?> fields,
    List<MediaDescriptor> media = const [],
    required DateTime createdAt,
  }) : baseRevisions = Map.unmodifiable(baseRevisions),
       fields = Map.unmodifiable(fields),
       media = List.unmodifiable(media),
       createdAt = createdAt.toUtc() {
    _require(_uuidV4.hasMatch(opId), 'opId must be a lowercase UUID v4');
    _require(_isUuid(entityId), 'entityId must be a UUID');
    _require(fields.isNotEmpty, 'a patch changes at least one field');
    _require(
      _sameKeys(fields, baseRevisions),
      'every field needs exactly one base revision',
    );
    final specs = syncFieldSpecs(entityType);
    for (final MapEntry(key: name, :value) in fields.entries) {
      final spec = specs[name];
      _require(spec != null, 'unknown ${entityType.name} field: $name');
      _require(
        spec!.rule != FieldMergeRule.remoteOwned,
        '$name is remote-owned',
      );
      _checkValue(entityType, spec, value);
      final base = baseRevisions[name]!;
      _require(base >= 0, 'base revision of $name must be >= 0');
      _require(
        spec.rule != FieldMergeRule.createOnly || base == 0,
        '$name is create-only',
      );
    }
    _require(
      !fields.containsKey('lifecycle') || fields.length == 1,
      'a lifecycle change carries no other field',
    );
    _checkMedia(specs, fields, media);
  }

  /// True when the patch can create the entity: every required field is
  /// present and no remote revision is known.
  bool get isCreation {
    final requiredFields = switch (entityType) {
      SyncEntityType.child => ChildSyncFields.requiredOnCreate,
      SyncEntityType.artwork => ArtworkSyncFields.requiredOnCreate,
    };
    return fields.keys.toSet().containsAll(requiredFields) &&
        baseRevisions.values.every((revision) => revision == 0);
  }

  factory EntityPatch.fromJson(Object? json) => _decode('EntityPatch', () {
    final map = _asMap(json);
    _onlyKeys(map, const {
      'opId',
      'entityType',
      'entityId',
      'baseRevisions',
      'fields',
      'media',
      'createdAt',
    });
    return EntityPatch(
      opId: map['opId'] as String,
      entityType: SyncEntityType.values.byName(map['entityType'] as String),
      entityId: map['entityId'] as String,
      baseRevisions: _asMap(map['baseRevisions']).cast<String, int>(),
      fields: _asMap(map['fields']),
      media: [
        for (final item in (map['media'] as List? ?? const []))
          MediaDescriptor.fromJson(item),
      ],
      createdAt: _parseInstant(map['createdAt']),
    );
  });

  Map<String, Object?> toJson() => {
    'opId': opId,
    'entityType': entityType.name,
    'entityId': entityId,
    'baseRevisions': baseRevisions,
    'fields': fields,
    'media': [for (final item in media) item.toJson()],
    'createdAt': syncInstantValue(createdAt),
  };

  @override
  bool operator ==(Object other) =>
      other is EntityPatch && _jsonEquals(other.toJson(), toJson());

  @override
  int get hashCode => _jsonHash(toJson());
}

enum FieldConflictKind {
  /// Same scalar field changed to two different values.
  field,

  /// Two different audio versions; both recordings are kept.
  audio,

  /// The entity is trashed, purged or unknown remotely; the edit is kept
  /// for recovery and never resurrects the entity.
  deleteVsEdit,
}

/// Both values of one field that could not be merged. Neither value may be
/// discarded until an explicit resolution patch is acknowledged.
final class FieldConflict {
  final String field;
  final Object? localValue;
  final Object? remoteValue;
  final int baseRevision;
  final int remoteRevision;
  final FieldConflictKind kind;

  FieldConflict({
    required this.field,
    required this.localValue,
    required this.remoteValue,
    required this.baseRevision,
    required this.remoteRevision,
    required this.kind,
  }) {
    _require(field.isNotEmpty, 'field must not be empty');
    _require(baseRevision >= 0, 'baseRevision must be >= 0');
    _require(remoteRevision >= 0, 'remoteRevision must be >= 0');
    _require(_isJsonValue(localValue), 'localValue must be JSON-compatible');
    _require(_isJsonValue(remoteValue), 'remoteValue must be JSON-compatible');
    _require(
      kind != FieldConflictKind.audio || field == ArtworkSyncFields.audio,
      'an audio conflict is on the audio field',
    );
  }

  factory FieldConflict.fromJson(Object? json) => _decode('FieldConflict', () {
    final map = _asMap(json);
    _onlyKeys(map, const {
      'field',
      'localValue',
      'remoteValue',
      'baseRevision',
      'remoteRevision',
      'kind',
    });
    _require(
      map.containsKey('localValue') && map.containsKey('remoteValue'),
      'both values are required, even when null',
    );
    return FieldConflict(
      field: map['field'] as String,
      localValue: map['localValue'],
      remoteValue: map['remoteValue'],
      baseRevision: map['baseRevision'] as int,
      remoteRevision: map['remoteRevision'] as int,
      kind: FieldConflictKind.values.byName(map['kind'] as String),
    );
  });

  Map<String, Object?> toJson() => {
    'field': field,
    'localValue': localValue,
    'remoteValue': remoteValue,
    'baseRevision': baseRevision,
    'remoteRevision': remoteRevision,
    'kind': kind.name,
  };

  @override
  bool operator ==(Object other) =>
      other is FieldConflict && _jsonEquals(other.toJson(), toJson());

  @override
  int get hashCode => _jsonHash(toJson());
}

/// The remote answer to exactly one [EntityPatch].
///
/// It acknowledges only the fields of its own [opId]: every field of the
/// patch is either in [accepted] (with its new remote revision) or in
/// [conflicts], never both. A replay of the same `opId` returns the same
/// receipt with [alreadyApplied] set and produces no second effect.
final class MutationReceipt {
  final String opId;
  final Map<String, int> accepted;
  final List<FieldConflict> conflicts;
  final bool alreadyApplied;

  MutationReceipt({
    required this.opId,
    required Map<String, int> accepted,
    List<FieldConflict> conflicts = const [],
    this.alreadyApplied = false,
  }) : accepted = Map.unmodifiable(accepted),
       conflicts = List.unmodifiable(conflicts) {
    _require(_uuidV4.hasMatch(opId), 'opId must be a lowercase UUID v4');
    _require(
      accepted.values.every((revision) => revision >= 1),
      'accepted revisions must be >= 1',
    );
    final conflicted = {for (final conflict in conflicts) conflict.field};
    _require(
      conflicted.length == conflicts.length,
      'one conflict per field at most',
    );
    _require(
      conflicted.intersection(accepted.keys.toSet()).isEmpty,
      'a field is either accepted or in conflict',
    );
  }

  /// Fields this receipt answers.
  Set<String> get answeredFields => {
    ...accepted.keys,
    for (final conflict in conflicts) conflict.field,
  };

  /// Throws [MutationReceiptMismatchException] unless this receipt answers
  /// exactly [patch]: same `opId`, every field of the patch answered once,
  /// no other field.
  void ensureAnswers(EntityPatch patch) {
    if (opId != patch.opId) {
      throw MutationReceiptMismatchException(
        opId: patch.opId,
        reason: 'receipt is for $opId',
      );
    }
    final expected = patch.fields.keys.toSet();
    final answered = answeredFields;
    if (answered.length != expected.length || !answered.containsAll(expected)) {
      throw MutationReceiptMismatchException(
        opId: patch.opId,
        reason: 'answers $answered, patch has $expected',
      );
    }
  }

  /// The same receipt, as returned to a replay of its `opId`.
  MutationReceipt asReplay() => MutationReceipt(
    opId: opId,
    accepted: accepted,
    conflicts: conflicts,
    alreadyApplied: true,
  );

  factory MutationReceipt.fromJson(Object? json) => _decode(
    'MutationReceipt',
    () {
      final map = _asMap(json);
      _onlyKeys(map, const {'opId', 'accepted', 'conflicts', 'alreadyApplied'});
      return MutationReceipt(
        opId: map['opId'] as String,
        accepted: _asMap(map['accepted']).cast<String, int>(),
        conflicts: [
          for (final item in map['conflicts'] as List)
            FieldConflict.fromJson(item),
        ],
        alreadyApplied: map['alreadyApplied'] as bool,
      );
    },
  );

  Map<String, Object?> toJson() => {
    'opId': opId,
    'accepted': accepted,
    'conflicts': [for (final conflict in conflicts) conflict.toJson()],
    'alreadyApplied': alreadyApplied,
  };

  @override
  bool operator ==(Object other) =>
      other is MutationReceipt && _jsonEquals(other.toJson(), toJson());

  @override
  int get hashCode => _jsonHash(toJson());
}

// ---------------------------------------------------------------------------
// Change journal
// ---------------------------------------------------------------------------

/// Opaque position in the remote change journal of one family.
///
/// [value] is only meaningful to the remote side; the device stores it as
/// is, together with the page it ends, in one local transaction.
final class ChangeCursor {
  final String value;

  /// Remote history generation; it changes when the remote history is
  /// restored or rebuilt and every older cursor becomes invalid.
  final int generation;

  ChangeCursor({required this.value, required this.generation}) {
    _require(value.isNotEmpty, 'cursor value must not be empty');
    _require(generation >= 1, 'generation must be >= 1');
  }

  factory ChangeCursor.fromJson(Object? json) => _decode('ChangeCursor', () {
    final map = _asMap(json);
    _onlyKeys(map, const {'value', 'generation'});
    return ChangeCursor(
      value: map['value'] as String,
      generation: map['generation'] as int,
    );
  });

  Map<String, Object?> toJson() => {'value': value, 'generation': generation};

  @override
  bool operator ==(Object other) =>
      other is ChangeCursor &&
      other.value == value &&
      other.generation == generation;

  @override
  int get hashCode => Object.hash(value, generation);
}

enum SyncChangeKind {
  /// Creation or field edit.
  upsert,

  /// Artwork moved to the trash.
  trash,

  /// Artwork restored from the trash.
  restore,

  /// Explicit, irreversible removal (artwork trash expiry or deletion,
  /// child deletion). Carries no snapshot.
  purge,

  /// A new media version was published on the entity.
  mediaVersion,
}

/// Complete, consistent state of one entity right after a change.
final class EntitySnapshot {
  /// Every set field, typed by [syncFieldSpecs], including `lifecycle`.
  final Map<String, Object?> fields;

  /// Current remote revision of every revisioned field.
  final Map<String, int> revisions;

  /// Descriptor of every media version referenced by [fields].
  final List<MediaDescriptor> media;

  /// Referenced versions whose bytes cannot currently be read remotely.
  /// The reference stays; a device must report the media as unavailable,
  /// never drop the entity or its local copy.
  final List<MediaRef> unavailableMedia;

  EntitySnapshot({
    required Map<String, Object?> fields,
    required Map<String, int> revisions,
    List<MediaDescriptor> media = const [],
    List<MediaRef> unavailableMedia = const [],
  }) : fields = Map.unmodifiable(fields),
       revisions = Map.unmodifiable(revisions),
       media = List.unmodifiable(media),
       unavailableMedia = List.unmodifiable(unavailableMedia) {
    _require(
      revisions.values.every((revision) => revision >= 1),
      'snapshot revisions must be >= 1',
    );
  }

  factory EntitySnapshot.fromJson(Object? json) =>
      _decode('EntitySnapshot', () {
        final map = _asMap(json);
        _onlyKeys(map, const {
          'fields',
          'revisions',
          'media',
          'unavailableMedia',
        });
        return EntitySnapshot(
          fields: _asMap(map['fields']),
          revisions: _asMap(map['revisions']).cast<String, int>(),
          media: [
            for (final item in map['media'] as List? ?? const [])
              MediaDescriptor.fromJson(item),
          ],
          unavailableMedia: [
            for (final item in map['unavailableMedia'] as List? ?? const [])
              MediaRef.fromJson(item),
          ],
        );
      });

  Map<String, Object?> toJson() => {
    'fields': fields,
    'revisions': revisions,
    'media': [for (final item in media) item.toJson()],
    'unavailableMedia': [for (final ref in unavailableMedia) ref.toJson()],
  };

  void _checkFor(SyncEntityType type) {
    final specs = syncFieldSpecs(type);
    for (final MapEntry(key: name, :value) in fields.entries) {
      final spec = specs[name];
      _require(spec != null, 'unknown ${type.name} field: $name');
      _checkValue(type, spec!, value);
    }
    for (final name in revisions.keys) {
      final spec = specs[name];
      _require(
        spec != null && spec.rule != FieldMergeRule.remoteOwned,
        'no revision for $name',
      );
    }
    _checkMedia(specs, fields, media);
    final referenced = {for (final item in media) item.ref};
    _require(
      unavailableMedia.every(referenced.contains),
      'unavailable media must be referenced',
    );
  }
}

/// One journal entry. [seq] is strictly increasing within a family and a
/// generation; a change committed late never lands behind a cursor that
/// was already returned.
final class SyncChange {
  final int seq;
  final SyncChangeKind kind;
  final SyncEntityType entityType;
  final String entityId;

  /// Null exactly when [kind] is [SyncChangeKind.purge].
  final EntitySnapshot? snapshot;

  /// The operation that produced the change, when it came from a patch.
  final String? opId;

  SyncChange({
    required this.seq,
    required this.kind,
    required this.entityType,
    required this.entityId,
    required this.snapshot,
    this.opId,
  }) {
    _require(seq >= 1, 'seq must be >= 1');
    _require(_isUuid(entityId), 'entityId must be a UUID');
    _require(
      opId == null || _uuidV4.hasMatch(opId!),
      'opId must be a lowercase UUID v4',
    );
    _require(
      (snapshot == null) == (kind == SyncChangeKind.purge),
      'only a purge has no snapshot',
    );
    _require(
      entityType == SyncEntityType.artwork ||
          (kind != SyncChangeKind.trash && kind != SyncChangeKind.restore),
      'children have no trash',
    );
    snapshot?._checkFor(entityType);
  }

  factory SyncChange.fromJson(Object? json) => _decode('SyncChange', () {
    final map = _asMap(json);
    _onlyKeys(map, const {
      'seq',
      'kind',
      'entityType',
      'entityId',
      'snapshot',
      'opId',
    });
    final snapshot = map['snapshot'];
    return SyncChange(
      seq: map['seq'] as int,
      kind: SyncChangeKind.values.byName(map['kind'] as String),
      entityType: SyncEntityType.values.byName(map['entityType'] as String),
      entityId: map['entityId'] as String,
      snapshot: snapshot == null ? null : EntitySnapshot.fromJson(snapshot),
      opId: map['opId'] as String?,
    );
  });

  Map<String, Object?> toJson() => {
    'seq': seq,
    'kind': kind.name,
    'entityType': entityType.name,
    'entityId': entityId,
    'snapshot': snapshot?.toJson(),
    if (opId != null) 'opId': opId,
  };

  @override
  bool operator ==(Object other) =>
      other is SyncChange && _jsonEquals(other.toJson(), toJson());

  @override
  int get hashCode => _jsonHash(toJson());
}

/// A bounded page of the change journal.
///
/// The device applies every change and stores [nextCursor] in a single
/// local transaction, then asks again while [hasMore] is true. An empty
/// page with `hasMore == false` means the device is up to date.
final class SyncChangePage {
  final List<SyncChange> changes;
  final ChangeCursor nextCursor;
  final bool hasMore;
  final int generation;

  SyncChangePage({
    required List<SyncChange> changes,
    required this.nextCursor,
    required this.hasMore,
    required this.generation,
  }) : changes = List.unmodifiable(changes) {
    _require(
      changes.length <= kMaxChangePageSize,
      'a page holds at most $kMaxChangePageSize changes',
    );
    _require(
      nextCursor.generation == generation,
      'nextCursor belongs to the page generation',
    );
    _require(!hasMore || changes.isNotEmpty, 'hasMore needs progress');
    for (var i = 1; i < changes.length; i++) {
      _require(
        changes[i].seq > changes[i - 1].seq,
        'seq must be strictly increasing',
      );
    }
  }

  factory SyncChangePage.fromJson(Object? json) => _decode(
    'SyncChangePage',
    () {
      final map = _asMap(json);
      _onlyKeys(map, const {'changes', 'nextCursor', 'hasMore', 'generation'});
      return SyncChangePage(
        changes: [
          for (final item in map['changes'] as List) SyncChange.fromJson(item),
        ],
        nextCursor: ChangeCursor.fromJson(map['nextCursor']),
        hasMore: map['hasMore'] as bool,
        generation: map['generation'] as int,
      );
    },
  );

  Map<String, Object?> toJson() => {
    'changes': [for (final change in changes) change.toJson()],
    'nextCursor': nextCursor.toJson(),
    'hasMore': hasMore,
    'generation': generation,
  };

  @override
  bool operator ==(Object other) =>
      other is SyncChangePage && _jsonEquals(other.toJson(), toJson());

  @override
  int get hashCode => _jsonHash(toJson());
}

// ---------------------------------------------------------------------------
// Media transfer
// ---------------------------------------------------------------------------

/// Permission to store the bytes of exactly one media version.
///
/// The transfer path is reserve → upload → confirm (remote check of size,
/// format and SHA-256 over the stored bytes) → reference it in a patch.
/// A media version is only usable in a patch after confirmation.
final class MediaReservation {
  final String reservationId;

  /// Operation that will reference the media.
  final String opId;
  final String artworkId;
  final MediaDescriptor media;

  /// Opaque credential a foreground or background transport presents with
  /// the bytes. Never logged.
  final String ticket;
  final DateTime expiresAt;

  /// The same bytes were already verified for this version (replay); the
  /// upload can be skipped.
  final bool alreadyVerified;

  MediaReservation({
    required this.reservationId,
    required this.opId,
    required this.artworkId,
    required this.media,
    required this.ticket,
    required DateTime expiresAt,
    this.alreadyVerified = false,
  }) : expiresAt = expiresAt.toUtc() {
    _require(_isUuid(reservationId), 'reservationId must be a UUID');
    _require(_uuidV4.hasMatch(opId), 'opId must be a lowercase UUID v4');
    _require(_isUuid(artworkId), 'artworkId must be a UUID');
    _require(media.role != MediaRole.original, 'originals stay local');
    _require(ticket.isNotEmpty, 'ticket must not be empty');
  }
}

// ---------------------------------------------------------------------------
// Backend interface
// ---------------------------------------------------------------------------

/// Remote side of protocol v3, implemented by an application adapter.
///
/// The adapter resolves the family from its session. Every method throws
/// only [SyncProtocolException]s, [QuotaExceededException] (see the object
/// storage contract) or I/O errors that mean "outcome unknown": the caller
/// then replays the same `opId`.
abstract interface class SyncProtocolBackend {
  /// Applies [patch] at most once. Conflicts are part of the receipt, not
  /// errors.
  Future<MutationReceipt> applyPatch(EntityPatch patch);

  /// Reads the journal after [cursor] (from the beginning when null).
  /// [limit] is capped at [kMaxChangePageSize].
  ///
  /// Throws [ChangeCursorInvalidException] when the cursor is unreadable
  /// or belongs to an older generation; the device then reconciles from
  /// the beginning while keeping local data and pending operations.
  Future<SyncChangePage> pullChanges(
    ChangeCursor? cursor, {
    int limit = kMaxChangePageSize,
  });

  /// Reserves the storage of one new media version for [opId].
  Future<MediaReservation> reserveMedia({
    required String opId,
    required String artworkId,
    required MediaDescriptor media,
  });

  /// Sends the exact bytes of a reserved version.
  Future<void> uploadMedia(MediaReservation reservation, List<int> bytes);

  /// Asks the remote side to verify the stored bytes against the
  /// descriptor. Returns the verified descriptor; throws
  /// [MediaIntegrityException] when they differ.
  Future<MediaDescriptor> confirmMedia(MediaReservation reservation);
}

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

sealed class SyncProtocolException implements Exception {
  const SyncProtocolException();
}

enum ChangeCursorInvalidReason { unreadable, generationChanged }

/// The cursor cannot continue the journal; reconcile from the beginning.
final class ChangeCursorInvalidException extends SyncProtocolException {
  final ChangeCursorInvalidReason reason;

  /// Current remote generation, when known.
  final int? currentGeneration;

  const ChangeCursorInvalidException({
    required this.reason,
    this.currentGeneration,
  });

  @override
  String toString() =>
      'ChangeCursorInvalidException(${reason.name}, '
      'currentGeneration: $currentGeneration)';
}

/// A write the remote side refuses as a whole because it contradicts an
/// identity already recorded. Field conflicts are not errors; they are
/// returned in [MutationReceipt.conflicts].
sealed class SyncConflictException extends SyncProtocolException {
  const SyncConflictException();
}

/// The `opId` was already used for a different patch.
final class OperationIdReusedException extends SyncConflictException {
  final String opId;
  const OperationIdReusedException(this.opId);

  @override
  String toString() => 'OperationIdReusedException($opId)';
}

/// The media version already exists with different bytes or metadata.
final class MediaVersionConflictException extends SyncConflictException {
  final MediaRef media;
  const MediaVersionConflictException(this.media);

  @override
  String toString() => 'MediaVersionConflictException($media)';
}

/// A receipt that does not answer exactly the patch that was sent. The
/// operation stays pending; nothing may be acknowledged from it.
final class MutationReceiptMismatchException extends SyncProtocolException {
  final String opId;
  final String reason;
  const MutationReceiptMismatchException({
    required this.opId,
    required this.reason,
  });

  @override
  String toString() => 'MutationReceiptMismatchException($opId: $reason)';
}

final class SyncRateLimitedException extends SyncProtocolException {
  final Duration? retryAfter;
  const SyncRateLimitedException({this.retryAfter});

  @override
  String toString() => 'SyncRateLimitedException(retryAfter: $retryAfter)';
}

enum SyncAuthFailure { unauthenticated, sessionExpired, notFamilyMember }

/// Never a reason to erase local data.
final class SyncAuthException extends SyncProtocolException {
  final SyncAuthFailure failure;
  const SyncAuthException(this.failure);

  @override
  String toString() => 'SyncAuthException(${failure.name})';
}

enum MediaIntegrityFailure {
  missingBytes,
  sizeMismatch,
  formatMismatch,
  sha256Mismatch,
}

/// Stored bytes do not match their descriptor. The version is not
/// verified; the device keeps its file and may upload again.
final class MediaIntegrityException extends SyncProtocolException {
  final MediaRef media;
  final MediaIntegrityFailure failure;
  const MediaIntegrityException(this.media, this.failure);

  @override
  String toString() => 'MediaIntegrityException($media, ${failure.name})';
}

/// A patch references media versions that are not verified remotely. The
/// patch had no effect.
final class MediaUnavailableException extends SyncProtocolException {
  final List<MediaRef> media;
  const MediaUnavailableException(this.media);

  @override
  String toString() => 'MediaUnavailableException($media)';
}

// ---------------------------------------------------------------------------
// Validation and JSON helpers
// ---------------------------------------------------------------------------

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);
final _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
final _sha256 = RegExp(r'^[0-9a-f]{64}$');
final _date = RegExp(r'^\d{4}-\d{2}-\d{2}$');

bool _isUuid(String value) => _uuid.hasMatch(value);

void _require(bool condition, String message) {
  if (!condition) throw ArgumentError(message);
}

void _checkValue(SyncEntityType entity, SyncFieldSpec spec, Object? value) {
  if (value == null) {
    _require(spec.nullable, '${spec.name} must not be null');
    return;
  }
  final valid = switch (spec.type) {
    SyncValueType.text => value is String && value.isNotEmpty,
    SyncValueType.date =>
      value is String &&
          _date.hasMatch(value) &&
          syncDateValue(DateTime.parse(value)) == value,
    SyncValueType.instant =>
      value is String &&
          value.endsWith('Z') &&
          DateTime.tryParse(value) != null,
    SyncValueType.id => value is String && _isUuid(value),
    SyncValueType.mediaRef => _tryMediaRef(value) != null,
    SyncValueType.lifecycle =>
      value is String &&
          _lifecyclesOf(entity).any((lifecycle) => lifecycle.name == value),
  };
  _require(valid, 'invalid ${spec.type.name} value for ${spec.name}');
}

MediaRef? _tryMediaRef(Object? value) {
  try {
    return MediaRef.fromJson(value);
  } on FormatException {
    return null;
  }
}

void _checkMedia(
  Map<String, SyncFieldSpec> specs,
  Map<String, Object?> fields,
  List<MediaDescriptor> media,
) {
  final byRef = <MediaRef, MediaDescriptor>{};
  for (final item in media) {
    _require(item.role != MediaRole.original, 'originals stay local');
    _require(byRef[item.ref] == null, 'duplicate media ${item.ref}');
    byRef[item.ref] = item;
  }
  final referenced = <MediaRef>{};
  for (final MapEntry(key: name, :value) in fields.entries) {
    final spec = specs[name]!;
    if (spec.type != SyncValueType.mediaRef || value == null) continue;
    final ref = MediaRef.fromJson(value);
    final descriptor = byRef[ref];
    _require(descriptor != null, '$name references undescribed media $ref');
    _require(
      descriptor!.role == spec.mediaRole,
      '$name requires a ${spec.mediaRole!.name} media',
    );
    referenced.add(ref);
  }
  _require(
    referenced.length == byRef.length,
    'every described media must be referenced by a field',
  );
}

bool _sameKeys(Map<String, Object?> left, Map<String, Object?> right) =>
    left.length == right.length && left.keys.every(right.containsKey);

T _decode<T>(String type, T Function() decode) {
  try {
    return decode();
  } on FormatException {
    rethrow;
  } on ArgumentError catch (error) {
    throw FormatException('Invalid $type: ${error.message}');
  } on TypeError catch (error) {
    throw FormatException('Invalid $type: $error');
  }
}

Map<String, Object?> _asMap(Object? json) {
  if (json is! Map) throw const FormatException('Expected a JSON object');
  return json.cast<String, Object?>();
}

void _onlyKeys(Map<String, Object?> map, Set<String> allowed) {
  for (final key in map.keys) {
    if (!allowed.contains(key)) throw FormatException('Unknown key: $key');
  }
}

DateTime _parseInstant(Object? value) {
  final parsed = value is String ? DateTime.tryParse(value) : null;
  if (parsed == null) throw FormatException('Invalid instant: $value');
  return parsed.toUtc();
}

bool _isJsonValue(Object? value) => switch (value) {
  null || bool() || num() || String() => true,
  List() => value.every(_isJsonValue),
  Map() =>
    value.keys.every((key) => key is String) &&
        value.values.every(_isJsonValue),
  _ => false,
};

bool _jsonEquals(Object? left, Object? right) {
  if (left is Map && right is Map) {
    return left.length == right.length &&
        left.keys.every(
          (key) => right.containsKey(key) && _jsonEquals(left[key], right[key]),
        );
  }
  if (left is List && right is List) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (!_jsonEquals(left[i], right[i])) return false;
    }
    return true;
  }
  return left == right;
}

int _jsonHash(Object? value) => switch (value) {
  Map() => Object.hashAllUnordered(
    value.entries.map(
      (entry) => Object.hash(entry.key, _jsonHash(entry.value)),
    ),
  ),
  List() => Object.hashAll(value.map(_jsonHash)),
  _ => value.hashCode,
};
