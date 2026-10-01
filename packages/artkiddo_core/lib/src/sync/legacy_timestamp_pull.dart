import '../contracts/object_storage.dart';
import '../contracts/sync_backend.dart';
import '../domain/action_result.dart';
import '../local/logging/log.dart';
import '../local/repositories/artworks_repository.dart';
import '../local/repositories/children_repository.dart';
import '../local/storage/local_vault.dart';
import 'change_journal_pull.dart';
import 'conflict_resolution.dart';
import 'sync_engine.dart' show SyncPhase, SyncProgress;
import 'sync_outbox.dart';
import 'vault_meta.dart';

/// The pull of the deprecated [SyncBackend]: three streams paginated by
/// server timestamp. A timestamp is not a position in commit order, so a row
/// committed behind a cursor already returned is never read (loss n°2 of
/// the reliability plan). [ChangeJournalPull] replaces it; this one is kept
/// only while the private adapter has no `SyncProtocolBackend`.
@Deprecated('Use ChangeJournalPull (sync protocol v3).')
class LegacyTimestampPull {
  final SyncBackend cloudApi;
  final ObjectDownloader downloader;
  final LocalVault vault;
  final ChildrenRepository childrenRepo;
  final ArtworksRepository artworksRepo;
  final SyncOutboxRepository outbox;
  final VaultMetaRepository vaultMeta;

  LegacyTimestampPull({
    required this.cloudApi,
    required this.downloader,
    required this.vault,
    required this.childrenRepo,
    required this.artworksRepo,
    required this.outbox,
    required this.vaultMeta,
  });

  /// Returns (children applied, artworks applied).
  Future<(int, int)> run({
    required String familyId,
    void Function(SyncProgress progress)? onProgress,
  }) async {
    final cursors = await vaultMeta.getPullCursors();
    Log.d(
      'Récupération distante : enfants=${cursors.children?.toIso8601String() ?? 'epoch'}, '
          'œuvres=${cursors.artworks?.toIso8601String() ?? 'epoch'}, '
          'purges=${cursors.purged?.toIso8601String() ?? 'epoch'}',
      'Sync',
    );

    var childrenApplied = 0;
    var childCursor = cursors.children;
    while (true) {
      final page = await cloudApi.pullChildrenPage(
        familyId: familyId,
        since: childCursor,
      );
      final pendingIds = await outbox.pendingEntityIds(
        entity: SyncEntityKind.child,
      );
      final plan = planPullApply<RemoteChildRow>(
        pulled: page.items,
        idOf: (r) => r.id,
        updatedAtOf: (r) => r.updatedAt,
        pendingLocalIds: pendingIds,
      );
      for (final row in plan.toApply) {
        final result = row.deletedAt != null
            ? await childrenRepo.applyRemoteTombstone(row.id)
            : await childrenRepo.upsertFromRemote(
                id: row.id,
                name: row.name,
                birthDate: row.birthDate,
                createdAt: row.createdAt,
              );
        _throwOnPullFailure(result);
      }
      childrenApplied += plan.toApply.length;
      childCursor = _nextPageCursor(
        stream: 'children',
        current: childCursor,
        page: page,
        fallback: plan.newCursor,
      );
      if (childCursor != null) {
        await vaultMeta.setChildrenPullCursor(childCursor);
      }
      if (!page.hasMore) break;
    }

    var artworksApplied = 0;
    var artworkCursor = cursors.artworks;
    while (true) {
      final page = await cloudApi.pullArtworksPage(
        familyId: familyId,
        since: artworkCursor,
      );
      final pendingIds = await outbox.pendingEntityIds(
        entity: SyncEntityKind.artwork,
      );
      final plan = planPullApply<RemoteArtworkRow>(
        pulled: page.items,
        idOf: (r) => r.id,
        updatedAtOf: (r) => r.updatedAt,
        pendingLocalIds: pendingIds,
      );
      var receivedInPage = 0;
      for (final row in plan.toApply) {
        if (row.deletedAt != null) {
          final result = await artworksRepo.applyRemoteTombstone(row.id);
          _throwOnPullFailure(result);
          continue;
        }
        final result = await artworksRepo.upsertFromRemote(
          id: row.id,
          childId: row.childId,
          addedAt: row.addedAt,
          drawnAt: row.drawnAt,
          story: row.story,
          displayObjectKey: row.displayObjectKey,
          thumbnailObjectKey: row.thumbnailObjectKey,
          audioObjectKey: row.audioObjectKey,
          audioDurationMs: row.audioDurationMs,
          audioByteSize: row.audioByteSize,
          audioRevision: row.audioRevision,
          byteSize: row.byteSize,
          imageWidth: row.imageWidth,
          imageHeight: row.imageHeight,
          addedBy: row.addedBy,
        );
        _throwOnPullFailure(result);
        // D10: thumbnails first — eager for a row new to this device, the
        // display derivative stays deferred to [ensureDisplayImageDownloaded].
        await _downloadThumbnailIfNeeded(row);
        onProgress?.call(
          SyncProgress(
            phase: SyncPhase.receiving,
            done: artworksApplied + ++receivedInPage,
          ),
        );
      }
      artworksApplied += plan.toApply.length;
      artworkCursor = _nextPageCursor(
        stream: 'artworks',
        current: artworkCursor,
        page: page,
        fallback: plan.newCursor,
      );
      if (artworkCursor != null) {
        await vaultMeta.setArtworksPullCursor(artworkCursor);
      }
      if (!page.hasMore) break;
    }

    // C-12: a device that missed both the soft-delete and the 30-day window
    // learns about the physical removal through the purge-log stream.
    var purgedCursor = cursors.purged;
    while (true) {
      final page = await cloudApi.pullPurgedArtworkIdsPage(
        familyId: familyId,
        since: purgedCursor,
      );
      for (final row in page.items) {
        final result = await artworksRepo.applyRemoteTombstone(row.id);
        _throwOnPullFailure(result);
      }
      purgedCursor = _nextPageCursor(
        stream: 'purged',
        current: purgedCursor,
        page: page,
        fallback: page.items.isEmpty ? null : _latestPurged(page.items),
      );
      if (purgedCursor != null) {
        await vaultMeta.setPurgedPullCursor(purgedCursor);
      }
      if (!page.hasMore) break;
    }

    Log.i(
      'Récupération appliquée : $childrenApplied enfant(s), $artworksApplied œuvre(s)',
      'Sync',
    );
    return (childrenApplied, artworksApplied);
  }

  void _throwOnPullFailure(ActionResult<void> result) {
    if (result case ActionFailed(failure: final failure)) {
      throw PullApplyFailure(failure);
    }
  }

  DateTime? _nextPageCursor<T>({
    required String stream,
    required DateTime? current,
    required PullPage<T> page,
    required DateTime? fallback,
  }) {
    final next = page.nextCursor ?? fallback;
    if (page.hasMore && next == null) {
      throw StateError('pull $stream page marked hasMore without a cursor');
    }
    if (page.hasMore && next == current) {
      throw StateError('pull $stream page returned the same cursor twice');
    }
    return next;
  }

  DateTime? _latestPurged(List<PurgedArtworkRow> rows) {
    DateTime? latest;
    for (final row in rows) {
      if (latest == null || row.purgedAt.isAfter(latest)) latest = row.purgedAt;
    }
    return latest;
  }

  Future<void> _downloadThumbnailIfNeeded(RemoteArtworkRow row) async {
    final local = await artworksRepo.getById(row.id);
    if (local == null) return;
    // Already has *something* to show locally — either this device
    // authored it (has an original) or a previous pull already fetched a
    // thumbnail. D10 only concerns a row genuinely new to this device.
    if (local.relativeImagePath != null || local.thumbnailImagePath != null) {
      return;
    }
    // Remote media refactor: prioritize display download and locally regenerate thumbnail
    final displayKey = row.displayObjectKey;
    if (displayKey != null) {
      try {
        final bytes = await downloader.downloadByKey(displayKey);
        final displayPath = await vault.storeDownloadedDerivative(
          bytes: bytes,
          artworkId: row.id,
          isDisplay: true,
        );
        await artworksRepo.markDisplayDownloaded(
          id: row.id,
          displayRelativePath: displayPath,
        );

        // Regenerate local thumbnail from display
        final thumbPath = await vault.generateThumbnailFromDisplay(
          artworkId: row.id,
          displayRelativePath: displayPath,
        );
        if (thumbPath != null) {
          await artworksRepo.markThumbnailDownloaded(
            id: row.id,
            thumbnailRelativePath: thumbPath,
          );
        }
        return;
      } catch (e, st) {
        Log.e(
          'Téléchargement de display pour vignette impossible (${row.id})',
          e,
          st,
          'Sync',
        );
        if (row.thumbnailObjectKey == null) {
          await artworksRepo.markDownloadFailed(row.id);
          return;
        }
      }
    }

    // Backwards compatibility fallback if only thumbnailObjectKey exists
    final key = row.thumbnailObjectKey;
    if (key == null) return;

    try {
      final bytes = await downloader.downloadByKey(key);
      final path = await vault.storeDownloadedDerivative(
        bytes: bytes,
        artworkId: row.id,
        isDisplay: false,
      );
      await artworksRepo.markThumbnailDownloaded(
        id: row.id,
        thumbnailRelativePath: path,
      );
    } catch (e, st) {
      Log.e(
        'Téléchargement de miniature impossible (${row.id})',
        e,
        st,
        'Sync',
      );
      await artworksRepo.markDownloadFailed(row.id);
    }
  }
}
