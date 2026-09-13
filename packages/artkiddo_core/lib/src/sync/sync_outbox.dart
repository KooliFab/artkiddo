import 'package:drift/drift.dart';

import '../local/database/app_database.dart';

enum SyncEntityKind {
  child('child'),
  masterpiece('masterpiece');

  final String wireName;
  const SyncEntityKind(this.wireName);
}

enum SyncOutboxOp {
  upsert('upsert'),
  delete('delete');

  final String wireName;
  const SyncOutboxOp(this.wireName);
}

class SyncOutboxRepository {
  final AppDatabase _db;
  SyncOutboxRepository(this._db);

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
      for (final row in existing) {
        await (_db.delete(
          _db.syncOutboxTable,
        )..where((t) => t.seq.equals(row.seq))).go();
      }
    } else if (existing.any((row) => row.op == op.wireName)) {
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

  Future<int> countFailed() async {
    final query = _db.selectOnly(_db.syncOutboxTable)
      ..addColumns([_db.syncOutboxTable.seq.count()])
      ..where(_db.syncOutboxTable.attempts.isBiggerThanValue(0));
    final row = await query.getSingle();
    return row.read(_db.syncOutboxTable.seq.count()) ?? 0;
  }

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

  Future<void> markTerminal(int seq) async {
    await (_db.delete(
      _db.syncOutboxTable,
    )..where((t) => t.seq.equals(seq))).go();
  }

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
