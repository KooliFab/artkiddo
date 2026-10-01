import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../contracts/sync_protocol.dart';
import '../local/database/app_database.dart';

/// The two entity kinds the outbox (and the rest of the sync engine)
/// knows about. A plain `String` on the Drift row (`'child'` /
/// `'artwork'`), typed here so callers never hand-roll the literal.
enum SyncEntityKind {
  child('child'),
  artwork('artwork');

  final String wireName;
  const SyncEntityKind(this.wireName);

  static SyncEntityKind of(SyncEntityType type) => switch (type) {
    SyncEntityType.child => SyncEntityKind.child,
    SyncEntityType.artwork => SyncEntityKind.artwork,
  };
}

enum SyncOutboxOp {
  upsert('upsert'),
  delete('delete');

  final String wireName;
  const SyncOutboxOp(this.wireName);
}

/// Where an operation is in its life.
enum SyncOutboxState {
  /// Never sent. May still be merged with a later edit of the same entity.
  pending('pending'),

  /// Persisted as sent (or about to be). Immutable: the outcome of the send
  /// may be unknown, so a replay must carry the same identifier and content.
  inFlight('in_flight');

  final String wireName;
  const SyncOutboxState(this.wireName);
}

extension SyncOutboxEntryX on SyncOutboxEntryEntity {
  bool get isInFlight => state == SyncOutboxState.inFlight.wireName;

  /// The operation's patch, or null while it has no field snapshot.
  EntityPatch? get patch =>
      patchJson == null ? null : EntityPatch.fromJson(jsonDecode(patchJson!));
}

/// The replayable operation queue.
///
/// Every mutating repository method calls [enqueue] or [enqueuePatch]
/// **inside the same Drift transaction** as its own write — the only way an
/// app kill mid-write can never leave a change made durable locally without
/// a matching operation (or vice versa).
///
/// An operation has its own identifier ([SyncOutboxEntryEntity.opId]) and,
/// when the change is expressible as fields, an immutable-once-sent
/// [EntityPatch]. Acknowledging an operation removes that operation only: an
/// edit made while it was in flight is another operation and survives.
class SyncOutboxRepository {
  final AppDatabase _db;
  final Uuid _uuid;
  SyncOutboxRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  /// A fresh operation identifier (UUID v4).
  String newOpId() => _uuid.v4();

  Future<List<SyncOutboxEntryEntity>> operationsOf(
    SyncEntityKind entity,
    String entityId,
  ) =>
      (_db.select(_db.syncOutboxTable)
            ..where(
              (t) =>
                  t.entity.equals(entity.wireName) &
                  t.entityId.equals(entityId),
            )
            ..orderBy([(t) => OrderingTerm(expression: t.seq)]))
          .get();

  /// Records that [entityId] needs [op] pushed, **without a field snapshot**:
  /// the content is read from the row when the operation is sent. Must be
  /// called from within the same `db.transaction()` as the business write it
  /// accompanies.
  ///
  /// A `delete` supersedes the still-`pending` operations of the entity (no
  /// point pushing content that is about to be deleted); an `in_flight`
  /// operation is never touched. An `upsert` is absorbed by a still-`pending`
  /// snapshot-less `upsert` queued last, because that one reads the row when
  /// it is sent; otherwise it is a new operation, so an edit made while an
  /// earlier operation is in flight is never lost.
  Future<void> enqueue({
    required SyncEntityKind entity,
    required String entityId,
    required SyncOutboxOp op,
  }) async {
    final existing = await operationsOf(entity, entityId);

    if (op == SyncOutboxOp.delete) {
      await _deletePending(entity, entityId);
    } else {
      final last = existing.isEmpty ? null : existing.last;
      if (last != null &&
          !last.isInFlight &&
          last.patchJson == null &&
          last.op == SyncOutboxOp.upsert.wireName) {
        return;
      }
    }

    await _insert(entity: entity, entityId: entityId, op: op);
  }

  /// Records [patch] as an operation. Must be called from within the same
  /// `db.transaction()` as the business write it describes. Returns the
  /// identifier of the operation that now carries the change.
  ///
  /// * A `lifecycle` patch that is not a restore supersedes the entity's
  ///   `pending` operations, like a delete.
  /// * A patch is merged into the entity's last operation when that one is
  ///   still `pending` and has a patch of its own (a later value of the same
  ///   field wins; the earlier base revision is kept). It is absorbed by a
  ///   `pending` snapshot-less `upsert`, which reads the row when it is sent.
  /// * Otherwise, in particular when the last operation is `in_flight`, it is
  ///   a new operation.
  ///
  /// With [supersedePending] false, a trash patch leaves the operations
  /// already queued where they are and follows them: used when the entity is
  /// trashed (kept for 30 days) rather than deleted, so a creation that never
  /// went out still goes out.
  Future<String> enqueuePatch(
    EntityPatch patch, {
    bool supersedePending = true,
  }) async {
    final entity = SyncEntityKind.of(patch.entityType);
    final existing = await operationsOf(entity, patch.entityId);
    final isLifecycle = patch.fields.containsKey(_lifecycle);

    if (isLifecycle) {
      if (supersedePending &&
          patch.fields[_lifecycle] != SyncLifecycle.active.name) {
        await _deletePending(entity, patch.entityId);
      }
    } else if (existing.isNotEmpty && !existing.last.isInFlight) {
      final last = existing.last;
      final lastPatch = last.patch;
      if (lastPatch == null) {
        if (last.op == SyncOutboxOp.upsert.wireName) return last.opId;
      } else if (!lastPatch.fields.containsKey(_lifecycle)) {
        final merged = mergePatches(lastPatch, patch);
        await (_db.update(_db.syncOutboxTable)
              ..where((t) => t.seq.equals(last.seq)))
            .write(SyncOutboxTableCompanion(patchJson: Value(_encode(merged))));
        return last.opId;
      }
    }

    await _insert(
      entity: entity,
      entityId: patch.entityId,
      op: isLifecycle && patch.fields[_lifecycle] != SyncLifecycle.active.name
          ? SyncOutboxOp.delete
          : SyncOutboxOp.upsert,
      patch: patch,
    );
    return patch.opId;
  }

  /// The patch a still-`pending` operation would send if it were merged with
  /// [newer]: [newer]'s values win, the base revision of a field already in
  /// [older] stays the one [older] was based on.
  static EntityPatch mergePatches(EntityPatch older, EntityPatch newer) {
    assert(older.entityType == newer.entityType);
    assert(older.entityId == newer.entityId);
    final fields = {...older.fields, ...newer.fields};
    final specs = syncFieldSpecs(older.entityType);
    final referenced = <MediaRef>{
      for (final entry in fields.entries)
        if (specs[entry.key]!.type == SyncValueType.mediaRef &&
            entry.value != null)
          MediaRef.fromJson(entry.value),
    };
    final media = <MediaRef, MediaDescriptor>{
      for (final descriptor in [...older.media, ...newer.media])
        descriptor.ref: descriptor,
    };
    return EntityPatch(
      opId: older.opId,
      entityType: older.entityType,
      entityId: older.entityId,
      baseRevisions: {
        for (final field in fields.keys)
          field: older.baseRevisions[field] ?? newer.baseRevisions[field]!,
      },
      fields: fields,
      media: [
        for (final ref in referenced)
          if (media[ref] != null) media[ref]!,
      ],
      createdAt: older.createdAt,
    );
  }

  Future<void> _insert({
    required SyncEntityKind entity,
    required String entityId,
    required SyncOutboxOp op,
    EntityPatch? patch,
  }) async {
    await _db
        .into(_db.syncOutboxTable)
        .insert(
          SyncOutboxTableCompanion.insert(
            opId: Value(patch?.opId ?? newOpId()),
            entity: entity.wireName,
            entityId: entityId,
            op: op.wireName,
            patchJson: Value(patch == null ? null : _encode(patch)),
            createdAt: DateTime.now(),
          ),
        );
  }

  Future<void> _deletePending(SyncEntityKind entity, String entityId) async {
    await (_db.delete(_db.syncOutboxTable)..where(
          (t) =>
              t.entity.equals(entity.wireName) &
              t.entityId.equals(entityId) &
              t.state.equals(SyncOutboxState.pending.wireName),
        ))
        .go();
  }

  static String _encode(EntityPatch patch) => jsonEncode(patch.toJson());

  static const _lifecycle = 'lifecycle';

  /// Entries ready to attempt now, ordered by insertion (`seq`), so an
  /// interrupted drain resumes exactly where it left off rather than
  /// reordering.
  ///
  /// The operations of one entity are sent strictly in order: only the oldest
  /// operation of each entity can be ready, and only once its own
  /// `nextAttemptAt` is unset or in the past.
  Future<List<SyncOutboxEntryEntity>> listReady({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final all = await (_db.select(
      _db.syncOutboxTable,
    )..orderBy([(t) => OrderingTerm(expression: t.seq)])).get();
    final seen = <String>{};
    final ready = <SyncOutboxEntryEntity>[];
    for (final entry in all) {
      if (!seen.add('${entry.entity}/${entry.entityId}')) continue;
      final next = entry.nextAttemptAt;
      if (next == null || !next.isAfter(at)) ready.add(entry);
    }
    return ready;
  }

  /// The highest `seq` in the queue, `0` when it is empty.
  Future<int> lastSeq() async {
    final max = _db.syncOutboxTable.seq.max();
    final row = await (_db.selectOnly(
      _db.syncOutboxTable,
    )..addColumns([max])).getSingle();
    return row.read(max) ?? 0;
  }

  Future<int> countPending() async {
    final query = _db.selectOnly(_db.syncOutboxTable)
      ..addColumns([_db.syncOutboxTable.seq.count()]);
    final row = await query.getSingle();
    return row.read(_db.syncOutboxTable.seq.count()) ?? 0;
  }

  /// Entries that have failed at least once and are sitting out a
  /// backoff — distinguishes "N items still queued, none in trouble"
  /// from "N items stuck retrying".
  Future<int> countFailed() async {
    final query = _db.selectOnly(_db.syncOutboxTable)
      ..addColumns([_db.syncOutboxTable.seq.count()])
      ..where(_db.syncOutboxTable.attempts.isBiggerThanValue(0));
    final row = await query.getSingle();
    return row.read(_db.syncOutboxTable.seq.count()) ?? 0;
  }

  /// The full set of entity ids with at least one pending entry for
  /// [entity] — used by the pull step to never let a `pull` overwrite
  /// (or resurrect) a row whose local change has not reached the
  /// server yet.
  Future<Set<String>> pendingEntityIds({required SyncEntityKind entity}) async {
    final rows =
        await (_db.selectOnly(_db.syncOutboxTable)
              ..addColumns([_db.syncOutboxTable.entityId])
              ..where(_db.syncOutboxTable.entity.equals(entity.wireName)))
            .get();
    return rows.map((r) => r.read(_db.syncOutboxTable.entityId)!).toSet();
  }

  /// True when [entityId] still has an operation queued.
  Future<bool> hasOperations(SyncEntityKind entity, String entityId) async =>
      (await operationsOf(entity, entityId)).isNotEmpty;

  /// Persists that [seq] is being sent, **before** the send. From now on the
  /// operation never changes: a send whose outcome is unknown is replayed
  /// with the same identifier and the same patch.
  ///
  /// [patch] is stored first when the operation had no field snapshot
  /// (it must carry the operation's own `opId`). Does nothing when the
  /// operation is already `in_flight`.
  Future<void> markInFlight(int seq, {EntityPatch? patch}) async {
    await (_db.update(_db.syncOutboxTable)..where(
          (t) =>
              t.seq.equals(seq) &
              t.state.equals(SyncOutboxState.pending.wireName),
        ))
        .write(
          SyncOutboxTableCompanion(
            state: Value(SyncOutboxState.inFlight.wireName),
            patchJson: patch == null
                ? const Value.absent()
                : Value(_encode(patch)),
          ),
        );
  }

  /// Claims the operation [seq] for a send, atomically: in **one transaction**
  /// the row is re-read (an edit merged into a still-`pending` operation after
  /// the caller listed it is therefore never missed), its patch is built by
  /// [buildPatch] when it has none, and patch and `in_flight` state are
  /// persisted. Returns the operation as persisted — the patch to send is its
  /// [SyncOutboxEntryEntity.patch] — or null when it is gone or [buildPatch]
  /// yields no patch (the operation is then left untouched).
  ///
  /// An operation that is already `in_flight` keeps its patch; one that is
  /// `in_flight` without a patch (marked by the legacy path) gets the built
  /// patch persisted once, and later attempts reuse it.
  Future<SyncOutboxEntryEntity?> claim(
    int seq, {
    required Future<EntityPatch?> Function(SyncOutboxEntryEntity current)
    buildPatch,
  }) => _db.transaction(() async {
    final current = await entryBySeq(seq);
    if (current == null) return null;
    final String? patchJson;
    if (current.patchJson != null) {
      patchJson = current.patchJson;
    } else {
      final built = await buildPatch(current);
      if (built == null) return null;
      patchJson = _encode(built);
    }
    await (_db.update(
      _db.syncOutboxTable,
    )..where((t) => t.seq.equals(seq))).write(
      SyncOutboxTableCompanion(
        state: Value(SyncOutboxState.inFlight.wireName),
        patchJson: Value(patchJson),
      ),
    );
    return entryBySeq(seq);
  });

  /// The operation [seq], or null when it is gone.
  Future<SyncOutboxEntryEntity?> entryBySeq(int seq) => (_db.select(
    _db.syncOutboxTable,
  )..where((t) => t.seq.equals(seq))).getSingleOrNull();

  /// Acknowledges the operation [seq] — and only that one — by removing it.
  Future<void> markSucceeded(int seq) async {
    await (_db.delete(
      _db.syncOutboxTable,
    )..where((t) => t.seq.equals(seq))).go();
  }

  /// A terminal failure (e.g. `missingFile`) exits the queue without
  /// being retried — retrying can never succeed on its own; the item
  /// needs a member's action.
  Future<void> markTerminal(int seq) async {
    await (_db.delete(
      _db.syncOutboxTable,
    )..where((t) => t.seq.equals(seq))).go();
  }

  /// Exponential backoff, 1 minute -> 1 hour, doubling per attempt.
  /// [retryAfter], when the server sent one (`429 Retry-After`), takes
  /// precedence over the computed delay.
  static Duration backoffFor(
    int attemptsAfterThisFailure, {
    Duration? retryAfter,
  }) {
    if (retryAfter != null) return retryAfter;
    final minutes = (1 << (attemptsAfterThisFailure - 1)).clamp(1, 60);
    return Duration(minutes: minutes);
  }

  /// Records a failed attempt. The state does not change: an operation that
  /// reached `in_flight` stays there, because its send may have been
  /// applied.
  Future<void> markFailed(
    int seq, {
    required String error,
    Duration? retryAfter,
  }) async {
    final row = await (_db.select(
      _db.syncOutboxTable,
    )..where((t) => t.seq.equals(seq))).getSingleOrNull();
    if (row == null) return;
    final attempts = row.attempts + 1;
    final delay = backoffFor(attempts, retryAfter: retryAfter);
    await (_db.update(
      _db.syncOutboxTable,
    )..where((t) => t.seq.equals(seq))).write(
      SyncOutboxTableCompanion(
        attempts: Value(attempts),
        nextAttemptAt: Value(DateTime.now().add(delay)),
        lastError: Value(error),
      ),
    );
  }
}
