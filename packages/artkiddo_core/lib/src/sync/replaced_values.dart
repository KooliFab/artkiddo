import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../contracts/sync_protocol.dart';
import '../local/database/app_database.dart';

/// Whose value a [ReplacedValue] is.
enum ReplacedValueSource {
  /// The remote value lost: a local edit won a conflict on the same field.
  remote,

  /// The local value lost: it was replaced by a remote value, or the
  /// entity it was edited on no longer exists remotely.
  local,
}

/// A value that a conflict replaced, kept for [ReplacedValuesRepository.retention].
///
/// There is no resolution screen in V1: this history is read by support and
/// by a future interface, and nothing here is ever sent to a remote side.
class ReplacedValue {
  final String id;
  final SyncEntityType entityType;
  final String entityId;
  final String field;

  /// JSON-compatible value as it was stored in the field.
  final Object? value;

  /// The media version when [value] is one (an audio recording); the file
  /// itself is never deleted because of the replacement.
  final MediaRef? mediaRef;
  final ReplacedValueSource source;
  final DateTime createdAt;

  const ReplacedValue({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.field,
    required this.value,
    required this.mediaRef,
    required this.source,
    required this.createdAt,
  });
}

/// Local history of the values that lost a conflict (table
/// `replaced_values`).
///
/// [record] may be called from inside the caller's transaction so the
/// history entry and the state change that caused it commit together.
class ReplacedValuesRepository {
  /// How long an entry is kept.
  static const retention = Duration(days: 30);

  /// `source` of a [hold] entry: not a [ReplacedValueSource], never listed.
  static const _held = 'held';

  final AppDatabase _db;
  final Uuid _uuid;
  final DateTime Function() _now;

  ReplacedValuesRepository(this._db, {Uuid? uuid, DateTime Function()? now})
    : _uuid = uuid ?? const Uuid(),
      _now = now ?? DateTime.now;

  Future<void> record({
    required SyncEntityType entityType,
    required String entityId,
    required String field,
    required Object? value,
    required ReplacedValueSource source,
    MediaRef? mediaRef,
  }) async {
    // The same replaced value can be met twice (by the pull, then in the
    // receipt of the pending operation); the history keeps it once, for the
    // retention period that follows its latest replacement.
    final valueJson = jsonEncode(value);
    final known = _db.update(_db.replacedValuesTable)
      ..where(
        (t) =>
            t.entityId.equals(entityId) &
            t.field.equals(field) &
            t.valueJson.equals(valueJson) &
            t.source.equals(source.name),
      );
    if (await known.write(
          ReplacedValuesTableCompanion(createdAt: Value(_now())),
        ) >
        0) {
      return;
    }
    await _db
        .into(_db.replacedValuesTable)
        .insert(
          ReplacedValuesTableCompanion.insert(
            id: _uuid.v4(),
            entityType: entityType.name,
            entityId: entityId,
            field: field,
            valueJson: valueJson,
            mediaRef: Value(
              mediaRef == null ? null : jsonEncode(mediaRef.toJson()),
            ),
            source: source.name,
            createdAt: _now(),
          ),
        );
  }

  /// Keeps [value] of [field] as the local edit the remote side refused
  /// because [entityId] was trashed there (`deleteVsEdit`). Until it is
  /// [release]d, the pull leaves that field on the local row and a remote
  /// restore sends it again ([heldValues]). One entry per field.
  Future<void> hold({
    required SyncEntityType entityType,
    required String entityId,
    required String field,
    required Object? value,
  }) async {
    await release(entityId, field: field);
    await _db
        .into(_db.replacedValuesTable)
        .insert(
          ReplacedValuesTableCompanion.insert(
            id: _uuid.v4(),
            entityType: entityType.name,
            entityId: entityId,
            field: field,
            valueJson: jsonEncode(value),
            source: _held,
            createdAt: _now(),
          ),
        );
  }

  /// The edits held on [entityId] by [hold], by field.
  Future<Map<String, Object?>> heldValues(String entityId) async {
    final rows =
        await (_db.select(_db.replacedValuesTable)..where(
              (t) => t.entityId.equals(entityId) & t.source.equals(_held),
            ))
            .get();
    return {for (final row in rows) row.field: jsonDecode(row.valueJson)};
  }

  /// Drops what [hold] kept on [entityId] ([field] only, when given): the
  /// edit was acknowledged, or the entity is purged.
  Future<void> release(String entityId, {String? field}) =>
      (_db.delete(_db.replacedValuesTable)..where(
            (t) =>
                t.entityId.equals(entityId) &
                t.source.equals(_held) &
                (field == null ? const Constant(true) : t.field.equals(field)),
          ))
          .go();

  /// Values replaced on [entityId], newest first.
  Future<List<ReplacedValue>> listReplacedValues(String entityId) async {
    final rows =
        await (_db.select(_db.replacedValuesTable)
              ..where(
                (t) =>
                    t.entityId.equals(entityId) & t.source.equals(_held).not(),
              )
              ..orderBy([
                (t) => OrderingTerm.desc(t.createdAt),
                (t) => OrderingTerm.desc(t.id),
              ]))
            .get();
    return rows.map(_toDomain).toList(growable: false);
  }

  /// Removes the entries older than [retention]. Returns how many. A held
  /// edit is not history: it lasts until it is released.
  Future<int> purgeExpired({DateTime? now}) {
    final cutoff = (now ?? _now()).subtract(retention);
    return (_db.delete(_db.replacedValuesTable)..where(
          (t) =>
              t.createdAt.isSmallerThanValue(cutoff) &
              t.source.equals(_held).not(),
        ))
        .go();
  }

  ReplacedValue _toDomain(ReplacedValueEntity row) => ReplacedValue(
    id: row.id,
    entityType: SyncEntityType.values.byName(row.entityType),
    entityId: row.entityId,
    field: row.field,
    value: jsonDecode(row.valueJson),
    mediaRef: row.mediaRef == null
        ? null
        : MediaRef.fromJson(jsonDecode(row.mediaRef!)),
    source: ReplacedValueSource.values.byName(row.source),
    createdAt: row.createdAt,
  );
}
