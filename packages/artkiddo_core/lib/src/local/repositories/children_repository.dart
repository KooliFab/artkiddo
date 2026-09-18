import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../storage/local_vault.dart';
import '../../domain/app_failure.dart';
import '../logging/log.dart';
import '../../domain/action_result.dart';
import '../../sync/sync_outbox.dart';
import '../../domain/child.dart';

/// Local-first persistence for children.
///
/// `delete` removes the child row and every masterpiece row for that
/// child in a single transaction (explicit deletion, not relying
/// solely on the SQLite foreign-key cascade, even though
/// `PRAGMA foreign_keys = ON` is set on every connection), then
/// attempts to delete each masterpiece's file — and its
/// `display`/`thumbnail` derivatives, if any were generated —
/// recording deferred cleanup entries for any that fail without
/// failing the overall operation.
abstract class ChildrenRepository {
  Stream<List<Child>> watchAll(); // sorted by name, case-insensitive
  Future<Child?> getById(String id);
  Future<Map<String, int>> countArtworksByChild();
  Future<ActionResult<String>> create({
    required String name,
    required DateTime birthDate,
  });
  Future<ActionResult<void>> update({
    required String id,
    required String name,
    required DateTime birthDate,
  });
  Future<ActionResult<void>> delete(String id); // cascades masterpieces + files

  /// Marks the local row as synchronized after a successful remote
  /// send.
  ///
  /// Separate from [update]: that one expresses a change made by the
  /// parent, while this only changes sync state. Without this method,
  /// an already-sent row would stay `localOnly` and would be
  /// re-uploaded on every sync.
  Future<ActionResult<void>> markSynced(String id);

  /// Writes a `pull`-derived row by its own id — never a fresh UUID.
  Future<ActionResult<void>> upsertFromRemote({
    required String id,
    required String name,
    required DateTime birthDate,
    required DateTime createdAt,
  });

  /// Applies a tombstone seen on `pull` by hard-deleting the local row
  /// (and cascading to its masterpieces exactly like [delete] does).
  /// Idempotent: a no-op success if the row is already absent.
  Future<ActionResult<void>> applyRemoteTombstone(String id);
}

class DriftChildrenRepository implements ChildrenRepository {
  final AppDatabase _db;
  final LocalVault _vault;
  final Uuid _uuid;
  final SyncOutboxRepository _outbox;

  DriftChildrenRepository(
    this._db,
    this._vault, {
    Uuid? uuid,
    SyncOutboxRepository? outbox,
  }) : _uuid = uuid ?? const Uuid(),
       _outbox = outbox ?? SyncOutboxRepository(_db);

  Child _toDomain(ChildEntity entity) {
    return Child(
      id: entity.id,
      name: entity.name,
      birthDate: entity.birthDate,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      syncState: SyncState.values.firstWhere(
        (s) => s.name == entity.syncState,
        orElse: () => SyncState.localOnly,
      ),
    );
  }

  @override
  Stream<List<Child>> watchAll() {
    return _db.select(_db.childrenTable).watch().map((rows) {
      final list = rows.map(_toDomain).toList();
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  @override
  Future<Child?> getById(String id) async {
    final row = await (_db.select(
      _db.childrenTable,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row != null ? _toDomain(row) : null;
  }

  @override
  Future<Map<String, int>> countArtworksByChild() async {
    final query = _db.selectOnly(_db.masterpiecesTable)
      ..addColumns([
        _db.masterpiecesTable.childId,
        _db.masterpiecesTable.id.count(),
      ])
      ..where(_db.masterpiecesTable.deletedAt.isNull())
      ..groupBy([_db.masterpiecesTable.childId]);
    final rows = await query.get();
    final result = <String, int>{};
    for (final row in rows) {
      final childId = row.read(_db.masterpiecesTable.childId);
      final count = row.read(_db.masterpiecesTable.id.count());
      if (childId != null) {
        result[childId] = count ?? 0;
      }
    }
    return result;
  }

  @override
  Future<ActionResult<String>> create({
    required String name,
    required DateTime birthDate,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    try {
      // The outbox entry is written in the same transaction as the
      // row.
      await _db.transaction(() async {
        await _db
            .into(_db.childrenTable)
            .insert(
              ChildrenTableCompanion.insert(
                id: id,
                name: name,
                birthDate: birthDate,
                createdAt: now,
                updatedAt: now,
                syncState: const Value('localOnly'),
              ),
            );
        // A single outbox entry for the child. The sync engine
        // cascades the server-side tombstone to every masterpiece of
        // this child itself — the logical deletion of a child
        // logically marks its artworks too, never a database
        // cascade — so enqueueing one entry per orphaned masterpiece
        // here would be redundant, and wrong for any masterpiece
        // never pushed at all.
        await _outbox.enqueue(
          entity: SyncEntityKind.child,
          entityId: id,
          op: SyncOutboxOp.upsert,
        );
      });
    } catch (e, st) {
      Log.e('Création locale de l’enfant impossible', e, st, 'ChildrenRepo');
      return ActionFailed(LocalWriteFailure(cause: e, stack: st));
    }
    return ActionSuccess(id);
  }

  @override
  Future<ActionResult<void>> update({
    required String id,
    required String name,
    required DateTime birthDate,
  }) async {
    final existing = await getById(id);
    if (existing == null) {
      return const ActionFailed(NotFoundFailure());
    }
    try {
      await _db.transaction(() async {
        final rows =
            await (_db.update(
              _db.childrenTable,
            )..where((t) => t.id.equals(id))).write(
              ChildrenTableCompanion(
                name: Value(name),
                birthDate: Value(birthDate),
                updatedAt: Value(DateTime.now()),
              ),
            );
        if (rows == 0) {
          throw StateError('child row disappeared during update transaction');
        }
        await _outbox.enqueue(
          entity: SyncEntityKind.child,
          entityId: id,
          op: SyncOutboxOp.upsert,
        );
      });
    } catch (e, st) {
      Log.e(
        'Mise à jour locale de l’enfant impossible ($id)',
        e,
        st,
        'ChildrenRepo',
      );
      return ActionFailed(LocalWriteFailure(cause: e, stack: st));
    }
    return const ActionSuccess(null);
  }

  @override
  Future<ActionResult<void>> markSynced(String id) async {
    try {
      final rows =
          await (_db.update(_db.childrenTable)..where((t) => t.id.equals(id)))
              .write(const ChildrenTableCompanion(syncState: Value('synced')));
      if (rows == 0) {
        return const ActionFailed(NotFoundFailure());
      }
    } catch (e, st) {
      Log.e(
        'Mise à jour de l’état de synchronisation impossible ($id)',
        e,
        st,
        'ChildrenRepo',
      );
      return ActionFailed(LocalWriteFailure(cause: e, stack: st));
    }
    return const ActionSuccess(null);
  }

  @override
  Future<ActionResult<void>> delete(String id) async {
    final existing = await getById(id);
    if (existing == null) {
      return const ActionFailed(NotFoundFailure());
    }

    List<MasterpieceEntity> orphaned = [];
    try {
      await _db.transaction(() async {
        orphaned = await (_db.select(
          _db.masterpiecesTable,
        )..where((t) => t.childId.equals(id))).get();
        await (_db.delete(
          _db.masterpiecesTable,
        )..where((t) => t.childId.equals(id))).go();
        final rows = await (_db.delete(
          _db.childrenTable,
        )..where((t) => t.id.equals(id))).go();
        if (rows == 0) {
          throw StateError('child row disappeared during delete transaction');
        }
        await _outbox.enqueue(
          entity: SyncEntityKind.child,
          entityId: id,
          op: SyncOutboxOp.delete,
        );
      });
    } catch (e, st) {
      Log.e(
        'Suppression locale de l’enfant impossible ($id)',
        e,
        st,
        'ChildrenRepo',
      );
      return ActionFailed(LocalWriteFailure(cause: e, stack: st));
    }

    for (final masterpiece in orphaned) {
      if (masterpiece.relativeImagePath != null) {
        await _vault.deleteFileOrEnqueueCleanup(
          relativePath: masterpiece.relativeImagePath!,
          db: _db,
        );
      }
      // The cascade must also take each masterpiece's derivatives
      // with it — otherwise they survive as orphans with no row
      // left to reference them, exactly the leak
      // `DriftMasterpiecesRepository.delete` already avoids for a
      // single masterpiece.
      await _vault.deleteDerivativeFilesOrEnqueueCleanup(
        displayRelativePath: masterpiece.displayImagePath,
        thumbnailRelativePath: masterpiece.thumbnailImagePath,
        db: _db,
      );
    }
    return const ActionSuccess(null);
  }

  @override
  Future<ActionResult<void>> upsertFromRemote({
    required String id,
    required String name,
    required DateTime birthDate,
    required DateTime createdAt,
  }) async {
    try {
      await _db
          .into(_db.childrenTable)
          .insertOnConflictUpdate(
            ChildrenTableCompanion.insert(
              id: id,
              name: name,
              birthDate: birthDate,
              createdAt: createdAt,
              updatedAt: DateTime.now(),
              syncState: const Value('synced'),
            ),
          );
    } catch (e, st) {
      Log.e(
        'Application d’enfant distant impossible ($id)',
        e,
        st,
        'ChildrenRepo',
      );
      return ActionFailed(LocalWriteFailure(cause: e, stack: st));
    }
    return const ActionSuccess(null);
  }

  @override
  Future<ActionResult<void>> applyRemoteTombstone(String id) async {
    final existing = await getById(id);
    if (existing == null) {
      // Idempotent: already applied, or never pulled. Either way the
      // desired end state holds — restoring twice in a row must never
      // create a duplicate.
      return const ActionSuccess(null);
    }

    List<MasterpieceEntity> orphaned = [];
    try {
      await _db.transaction(() async {
        orphaned = await (_db.select(
          _db.masterpiecesTable,
        )..where((t) => t.childId.equals(id))).get();
        await (_db.delete(
          _db.masterpiecesTable,
        )..where((t) => t.childId.equals(id))).go();
        await (_db.delete(
          _db.childrenTable,
        )..where((t) => t.id.equals(id))).go();
      });
    } catch (e, st) {
      Log.e(
        'Application du tombstone enfant impossible ($id)',
        e,
        st,
        'ChildrenRepo',
      );
      return ActionFailed(LocalWriteFailure(cause: e, stack: st));
    }

    for (final masterpiece in orphaned) {
      if (masterpiece.relativeImagePath != null) {
        await _vault.deleteFileOrEnqueueCleanup(
          relativePath: masterpiece.relativeImagePath!,
          db: _db,
        );
      }
      await _vault.deleteDerivativeFilesOrEnqueueCleanup(
        displayRelativePath: masterpiece.displayImagePath,
        thumbnailRelativePath: masterpiece.thumbnailImagePath,
        db: _db,
      );
    }
    return const ActionSuccess(null);
  }
}
