import '../../contracts/sync_protocol.dart';
import '../../contracts/trash.dart';
import '../../domain/action_result.dart';
import '../../domain/app_failure.dart';
import '../../sync/sync_outbox.dart';
import '../database/app_database.dart';
import 'local_trash_repository.dart';

/// The trash of a composition with remote backup, where a local deletion
/// wins over the remote side.
///
/// * Listing merges the remote trash with this device's trash: an artwork
///   trashed here and not sent yet, or kept here after a remote purge, is
///   listed; an artwork whose purge is queued is not. Offline, the list is
///   this device's trash.
/// * "Delete forever" and "empty the trash" never call the remote side:
///   [LocalTrashRepository] (with `queueRemoteDeletions`) removes the rows
///   and files and queues `lifecycle: purged`, which the sync sends now or
///   once the remote side is reachable again.
/// * Restoring stays a remote action ([remote]); an artwork the remote side
///   does not know any more is restored on this device only.
class QueuedRemoteTrashRepository implements TrashRepository {
  final TrashRepository remote;
  final LocalTrashRepository local;
  final AppDatabase db;

  QueuedRemoteTrashRepository({
    required this.remote,
    required this.local,
    required this.db,
  });

  @override
  Future<ActionResult<List<TrashedArtwork>>> listTrash({
    String? scopeId,
  }) async {
    final localResult = await local.listTrash();
    final remoteResult = scopeId == null
        ? null
        : await remote.listTrash(scopeId: scopeId);
    final localItems = switch (localResult) {
      ActionSuccess(value: final items) => items,
      _ => null,
    };
    final remoteItems = switch (remoteResult) {
      ActionSuccess(value: final items) => items,
      _ => null,
    };
    if (localItems == null && remoteItems == null) {
      return remoteResult ?? localResult;
    }
    final byId = <String, TrashedArtwork>{
      for (final item in localItems ?? const <TrashedArtwork>[]) item.id: item,
    };
    final outbox = SyncOutboxRepository(db);
    for (final item in remoteItems ?? const <TrashedArtwork>[]) {
      final held = byId[item.id];
      if (held != null) {
        if (held.previewPath == null && item.previewUri != null) {
          byId[item.id] = TrashedArtwork(
            id: held.id,
            childId: held.childId,
            childName: held.childName.isEmpty ? item.childName : held.childName,
            deletedAt: held.deletedAt,
            purgeAt: held.purgeAt,
            story: held.story,
            previewUri: item.previewUri,
            existsOnlyHere: held.existsOnlyHere,
          );
        }
        continue;
      }
      if (await _purgeQueued(outbox, item.id)) continue;
      byId[item.id] = item;
    }
    final items = byId.values.toList()
      ..sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
    return ActionSuccess(items);
  }

  static Future<bool> _purgeQueued(
    SyncOutboxRepository outbox,
    String artworkId,
  ) async {
    for (final op in await outbox.operationsOf(
      SyncEntityKind.artwork,
      artworkId,
    )) {
      if (op.op == SyncOutboxOp.delete.wireName &&
          op.patch?.fields[ArtworkSyncFields.lifecycle] !=
              SyncLifecycle.trashed.name) {
        return true;
      }
    }
    return false;
  }

  @override
  Future<ActionResult<void>> restore(String artworkId) async {
    final result = await remote.restore(artworkId);
    if (result case ActionFailed(failure: NotFoundFailure())) {
      // Unknown remotely (never sent, or purged there): on this device only.
      return local.restore(artworkId);
    }
    return result;
  }

  @override
  Future<ActionResult<void>> purge(String artworkId) => local.purge(artworkId);

  /// Purges this device's trash and queues a purge for every artwork the
  /// remote trash lists, when it can be read; offline, an artwork trashed
  /// remotely and not pulled yet stays in the remote trash.
  @override
  Future<ActionResult<void>> purgeAll({String? scopeId}) async {
    final remoteResult = scopeId == null
        ? null
        : await remote.listTrash(scopeId: scopeId);
    if (remoteResult case ActionSuccess(value: final items)) {
      for (final item in items) {
        final result = await local.purge(item.id);
        if (result is ActionFailed) return result;
      }
    }
    return local.purgeAll();
  }

  @override
  Future<ActionResult<int>> purgeExpired({DateTime? now}) =>
      local.purgeExpired(now: now);
}
