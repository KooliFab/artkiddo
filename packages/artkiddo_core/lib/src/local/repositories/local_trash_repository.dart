import 'package:drift/drift.dart';

import '../../contracts/sync_protocol.dart';
import '../../contracts/trash.dart';
import '../database/app_database.dart';
import '../../domain/app_failure.dart';
import '../logging/log.dart';
import '../../domain/action_result.dart';
import '../storage/local_vault.dart';
import '../../sync/replaced_values.dart';
import '../../sync/sync_outbox.dart';

/// The artwork trash of this device. It owns only local rows and files; it
/// has no household, auth, network, or provider dependency.
///
/// With [queueRemoteDeletions] (a composition with remote backup), a local
/// deletion wins over the remote side and reaches it through the outbox:
///
/// * "delete forever" and "empty the trash" replace the artwork's pending
///   operations by one `lifecycle: purged` operation, in the transaction
///   that removes the row, even when no row is held here (an artwork only
///   listed by the remote trash). The pull never brings back an artwork
///   whose removal is still queued, and the operation survives a restart;
/// * the 30-day expiry keeps a queued trash, so an artwork trashed here and
///   never sent cannot come back from the remote side, which expires it on
///   its own; it queues no purge.
class LocalTrashRepository implements TrashRepository {
  static const retention = Duration(days: 30);

  final AppDatabase _db;
  final LocalVault _vault;
  final DateTime Function() _now;
  final bool queueRemoteDeletions;

  LocalTrashRepository(
    this._db,
    this._vault, {
    DateTime Function()? now,
    this.queueRemoteDeletions = false,
  }) : _now = now ?? DateTime.now;

  AppFailure _mapException(Object error, StackTrace stack) =>
      LocalWriteFailure(cause: error, stack: stack);

  @override
  Future<ActionResult<List<TrashedArtwork>>> listTrash({
    String? scopeId,
  }) async {
    try {
      final rows =
          await (_db.select(_db.artworksTable)
                ..where((t) => t.deletedAt.isNotNull())
                ..orderBy([
                  (t) => OrderingTerm(
                    expression: t.deletedAt,
                    mode: OrderingMode.desc,
                  ),
                ]))
              .get();
      if (rows.isEmpty) return const ActionSuccess(<TrashedArtwork>[]);

      final childIds = rows.map((row) => row.childId).toSet();
      final children = await (_db.select(
        _db.childrenTable,
      )..where((t) => t.id.isIn(childIds))).get();
      final names = {for (final child in children) child.id: child.name};
      final hiddenChildren = {
        for (final child in children)
          if (child.deletedAt != null) child.id,
      };

      return ActionSuccess([
        for (final row in rows)
          TrashedArtwork(
            id: row.id,
            childId: row.childId,
            childName: names[row.childId] ?? '',
            deletedAt: row.deletedAt!,
            purgeAt: row.deletedAt!.add(retention),
            story: row.story,
            previewPath:
                row.thumbnailImagePath ??
                row.displayImagePath ??
                row.relativeImagePath,
            existsOnlyHere:
                row.remotePurgedAt != null ||
                hiddenChildren.contains(row.childId),
          ),
      ]);
    } catch (e, st) {
      Log.e('Chargement de la Corbeille locale impossible', e, st, 'Trash');
      return ActionFailed(_mapException(e, st));
    }
  }

  @override
  Future<ActionResult<void>> restore(String artworkId) async {
    try {
      final row = await (_db.select(
        _db.artworksTable,
      )..where((t) => t.id.equals(artworkId))).getSingleOrNull();
      // Restoring an already-restored or already-purged item is an
      // idempotent no-op, as required by the local trash contract.
      if (row == null || row.deletedAt == null) {
        return const ActionSuccess(null);
      }
      // An artwork the remote side purged (or whose child it purged) comes
      // back active on this phone only: it is marked so, its hidden child is
      // shown again, and nothing is queued for the server, which refuses
      // `lifecycle: active` for a purged artwork.
      final restored = await _db.transaction(() async {
        final child = await (_db.select(
          _db.childrenTable,
        )..where((t) => t.id.equals(row.childId))).getSingleOrNull();
        final onlyHere = row.remotePurgedAt != null || child?.deletedAt != null;
        final count =
            await (_db.update(_db.artworksTable)..where(
                  (t) => t.id.equals(artworkId) & t.deletedAt.isNotNull(),
                ))
                .write(
                  ArtworksTableCompanion(
                    deletedAt: const Value(null),
                    syncState: const Value('localOnly'),
                    remotePurgedAt: onlyHere
                        ? Value(row.remotePurgedAt ?? _now())
                        : const Value.absent(),
                  ),
                );
        if (count > 0 && child?.deletedAt != null) {
          await (_db.update(_db.childrenTable)
                ..where((t) => t.id.equals(row.childId)))
              .write(const ChildrenTableCompanion(deletedAt: Value(null)));
        }
        return count;
      });
      if (restored == 0) return const ActionSuccess(null);
      final after = await (_db.select(
        _db.artworksTable,
      )..where((t) => t.id.equals(artworkId))).getSingleOrNull();
      if (after?.deletedAt != null) {
        return const ActionFailed(LocalWriteFailure());
      }
      return const ActionSuccess(null);
    } catch (e, st) {
      Log.e('Restauration locale impossible ($artworkId)', e, st, 'Trash');
      return ActionFailed(_mapException(e, st));
    }
  }

  @override
  Future<ActionResult<void>> purge(String artworkId) async {
    try {
      final row = await (_db.select(
        _db.artworksTable,
      )..where((t) => t.id.equals(artworkId))).getSingleOrNull();
      if (row == null) {
        // An artwork only the remote trash lists.
        if (queueRemoteDeletions) {
          await _db.transaction(() => _queuePurge(artworkId, 0));
        }
        return const ActionSuccess(null);
      }
      if (row.deletedAt == null) return const ActionSuccess(null);
      return await _purgeRows([row]);
    } catch (e, st) {
      Log.e('Purge locale impossible ($artworkId)', e, st, 'Trash');
      return ActionFailed(_mapException(e, st));
    }
  }

  @override
  Future<ActionResult<void>> purgeAll({String? scopeId}) async {
    try {
      final rows = await (_db.select(
        _db.artworksTable,
      )..where((t) => t.deletedAt.isNotNull())).get();
      return await _purgeRows(rows);
    } catch (e, st) {
      Log.e('Vidage de la Corbeille locale impossible', e, st, 'Trash');
      return ActionFailed(_mapException(e, st));
    }
  }

  @override
  Future<ActionResult<int>> purgeExpired({DateTime? now}) async {
    final cutoff = (now ?? _now()).subtract(retention);
    try {
      final rows =
          await (_db.select(_db.artworksTable)..where(
                (t) =>
                    t.deletedAt.isNotNull() &
                    t.deletedAt.isSmallerOrEqualValue(cutoff),
              ))
              .get();
      final result = await _purgeRows(rows, expiry: true);
      return switch (result) {
        ActionSuccess() => ActionSuccess(rows.length),
        ActionFailed(failure: final failure) => ActionFailed(failure),
        ActionCancelled() => const ActionCancelled(),
      };
    } catch (e, st) {
      Log.e('Purge automatique locale impossible', e, st, 'Trash');
      return ActionFailed(_mapException(e, st));
    }
  }

  /// The trash purge: the 30-day expiry, "delete forever" and "empty the
  /// trash". The rows go first, in one transaction with the operations that
  /// only described them; the files follow through
  /// [LocalVault.deleteArtworkFilesOrEnqueueCleanup], which asks
  /// `isMediaReferenced` for each one. A child hidden after a remote purge
  /// goes with its last artwork.
  Future<ActionResult<void>> _purgeRows(
    List<ArtworkEntity> rows, {
    bool expiry = false,
  }) async {
    if (rows.isEmpty) return await _dropChildlessHiddenChildren();
    try {
      await _db.transaction(() async {
        final ids = rows.map((row) => row.id).toList();
        await (_db.delete(
          _db.artworksTable,
        )..where((t) => t.id.isIn(ids))).go();
        if (queueRemoteDeletions && !expiry) {
          // The purge replaces whatever was still pending and goes out.
          for (final row in rows) {
            await _queuePurge(row.id, row.lifecycleRev);
          }
        } else {
          // What was still queued for an artwork that no longer exists could
          // never be sent: it would only show as "waiting" for ever. A trash
          // still waiting to be sent is kept with an account, so the remote
          // side cannot bring the artwork back.
          final outbox = SyncOutboxRepository(_db);
          for (final id in ids) {
            for (final op in await outbox.operationsOf(
              SyncEntityKind.artwork,
              id,
            )) {
              if (queueRemoteDeletions && _removes(op)) continue;
              await (_db.delete(
                _db.syncOutboxTable,
              )..where((t) => t.seq.equals(op.seq))).go();
            }
          }
        }
        await (_db.delete(
          _db.deferredRemoteChangesTable,
        )..where((t) => t.artworkId.isIn(ids))).go();
        // An edit held after a remote trash can never be sent any more.
        for (final id in ids) {
          await ReplacedValuesRepository(_db).release(id);
        }
      });
    } catch (e, st) {
      Log.e('Suppression des lignes de Corbeille impossible', e, st, 'Trash');
      return ActionFailed(_mapException(e, st));
    }

    // Database truth is durable before file work starts. Any failed or
    // still-referenced file is journaled by LocalVault and retried at the
    // next startup.
    for (final row in rows) {
      await _vault.deleteArtworkFilesOrEnqueueCleanup(row, db: _db);
    }
    return await _dropChildlessHiddenChildren();
  }

  /// Queues `lifecycle: purged` for [artworkId], superseding its pending
  /// operations. The remote side applies a purge whatever its base revision.
  Future<void> _queuePurge(String artworkId, int lifecycleRev) async {
    final outbox = SyncOutboxRepository(_db);
    await outbox.enqueuePatch(
      EntityPatch(
        opId: outbox.newOpId(),
        entityType: SyncEntityType.artwork,
        entityId: artworkId,
        baseRevisions: {ArtworkSyncFields.lifecycle: lifecycleRev},
        fields: {ArtworkSyncFields.lifecycle: SyncLifecycle.purged.name},
        createdAt: _now(),
      ),
    );
    await (_db.delete(
      _db.deferredRemoteChangesTable,
    )..where((t) => t.artworkId.equals(artworkId))).go();
    await ReplacedValuesRepository(_db).release(artworkId);
  }

  /// The operation moves the artwork to the trash or deletes it.
  static bool _removes(SyncOutboxEntryEntity op) {
    if (op.op == SyncOutboxOp.delete.wireName) return true;
    final lifecycle = op.patch?.fields[ArtworkSyncFields.lifecycle];
    return lifecycle != null && lifecycle != SyncLifecycle.active.name;
  }

  /// A child hidden because the remote side purged it stays only while an
  /// artwork or an operation depends on it.
  Future<ActionResult<void>> _dropChildlessHiddenChildren() async {
    try {
      final hidden = await (_db.select(
        _db.childrenTable,
      )..where((t) => t.deletedAt.isNotNull())).get();
      for (final child in hidden) {
        final artworks =
            await (_db.select(_db.artworksTable)
                  ..where((t) => t.childId.equals(child.id))
                  ..limit(1))
                .get();
        if (artworks.isNotEmpty) continue;
        final ops =
            await (_db.select(_db.syncOutboxTable)
                  ..where(
                    (t) =>
                        t.entity.equals(SyncEntityKind.child.wireName) &
                        t.entityId.equals(child.id),
                  )
                  ..limit(1))
                .get();
        if (ops.isNotEmpty) continue;
        await (_db.delete(
          _db.childrenTable,
        )..where((t) => t.id.equals(child.id))).go();
      }
      return const ActionSuccess(null);
    } catch (e, st) {
      Log.e('Nettoyage des enfants masqués impossible', e, st, 'Trash');
      return ActionFailed(_mapException(e, st));
    }
  }
}
