import 'package:drift/drift.dart';

import '../local/database/app_database.dart';

/// The two entity kinds the outbox (and the rest of the sync engine)
/// knows about. A plain `String` on the Drift row (`'child'` /
/// `'artwork'`), typed here so callers never hand-roll the literal.
enum SyncEntityKind {
  child('child'),
  artwork('artwork');

  final String wireName;
  const SyncEntityKind(this.wireName);
}

enum SyncOutboxOp {
  upsert('upsert'),
  delete('delete');

  final String wireName;
  const SyncOutboxOp(this.wireName);
}

/// The replayable send queue.
///
/// Every mutating repository method (`ChildrenRepository.create/update/
/// delete`, `ArtworksRepository.create/updateStory/updateDrawnAt/
/// delete`) calls [enqueue] **inside the same Drift transaction** as
/// its own write — the only way an app kill mid-write can never leave
/// a change made durable locally without a matching outbox entry (or
/// vice versa).
///
/// Deliberately *not* a queue of payloads: an entry only ever records
/// "entity X needs an upsert/delete pushed", never the content itself.
/// The content is re-read fresh from the row at drain time, so an
/// entry that sat in the queue through several further edits still
/// pushes the *latest* state, not a stale snapshot — and coalescing
/// repeated edits into one push is free instead of a
/// queue-deduplication problem.
class SyncOutboxRepository {
  final AppDatabase _db;
  SyncOutboxRepository(this._db);

  /// Records that [entityId] needs [op] pushed. Must be called from
  /// within the same `db.transaction()` as the business write it
  /// accompanies.
  ///
  /// A `delete` supersedes any still-pending `upsert` for the same
  /// entity (no point pushing content that is about to be deleted) —
  /// those are removed first. Duplicate consecutive entries of the
  /// *same* op are collapsed to one: re-editing an artwork's story
  /// five times before the first push drains queues exactly one
  /// `upsert`, not five.
  Future<void> enqueue({
    required SyncEntityKind entity,
    required String entityId,
    required SyncOutboxOp op,
  }) async {
    final existing =
        await (_db.select(_db.syncOutboxTable)..where(
              (t) =>
                  t.entity.equals(entity.wireName) &
                  t.entityId.equals(entityId),
            ))
            .get();

    if (op == SyncOutboxOp.delete) {
      // A delete wins over — and replaces — any pending upsert: a
      // deletion always applies, unconditionally.
      for (final row in existing) {
        await (_db.delete(
          _db.syncOutboxTable,
        )..where((t) => t.seq.equals(row.seq))).go();
      }
    } else if (existing.any((row) => row.op == op.wireName)) {
      // Already queued for the same op; the re-read-at-drain-time
      // design means nothing is lost by not adding a second entry.
      return;
    }

    await _db
        .into(_db.syncOutboxTable)
        .insert(
          SyncOutboxTableCompanion.insert(
            entity: entity.wireName,
            entityId: entityId,
            op: op.wireName,
            createdAt: DateTime.now(),
          ),
        );
  }

  /// Entries ready to attempt now — `nextAttemptAt` unset or in the
  /// past — ordered by insertion (`seq`), so an interrupted drain
  /// resumes exactly where it left off rather than reordering.
  Future<List<SyncOutboxEntryEntity>> listReady({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final query = _db.select(_db.syncOutboxTable)
      ..where(
        (t) =>
            t.nextAttemptAt.isNull() |
            t.nextAttemptAt.isSmallerOrEqualValue(at),
      )
      ..orderBy([(t) => OrderingTerm(expression: t.seq)]);
    return query.get();
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
