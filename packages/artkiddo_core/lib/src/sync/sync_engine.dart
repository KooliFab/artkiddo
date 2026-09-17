import 'package:drift/drift.dart' show Value;

import '../contracts/object_storage.dart';
import '../contracts/sync_backend.dart';
import '../domain/action_result.dart';
import '../domain/app_failure.dart';
import '../local/database/app_database.dart';
import '../local/logging/log.dart';
import '../local/repositories/children_repository.dart';
import '../local/repositories/masterpieces_repository.dart';
import '../local/storage/local_vault.dart';
import 'conflict_resolution.dart';
import 'sync_outbox.dart';
import 'vault_meta.dart';

export 'vault_meta.dart' show FoyerMismatchException;

/// Summary of one [SyncEngine.syncAll] run, for `AccountController` to fold
/// into `BackupStatus` (spec §7) without `SyncEngine` knowing about the
/// screen-facing shape.
class SyncRunSummary {
  final int pushSucceeded;
  final int pushFailed;
  final int pulledChildren;
  final int pulledMasterpieces;
  final AppFailure? lastError;
  const SyncRunSummary({
    required this.pushSucceeded,
    required this.pushFailed,
    required this.pulledChildren,
    required this.pulledMasterpieces,
    this.lastError,
  });
}

/// Thrown internally to short-circuit one outbox entry as a *terminal*
/// failure — never retried, exits the queue immediately (spec §5).
class _TerminalOutboxFailure implements Exception {
  final AppFailure failure;
  const _TerminalOutboxFailure(this.failure);
}

/// A pull page is not acknowledged until every local write in that page has
/// succeeded. The caller can retry the stream from its previous cursor when a
/// local database write fails.
class _PullApplyFailure implements Exception {
  final AppFailure failure;
  const _PullApplyFailure(this.failure);
}

/// C-06's convergence engine.
///
/// Normative reference: `.scratch/foyer/issues/C-06-convergence-foyer.md`.
/// A single entry point, [syncAll], **is** `joinOrRestore` (D13: joining a
/// foyer and restoring a device are the same operation) — see the method's
/// own doc comment for why unifying them, rather than giving "join" and
/// "restore" separate code paths, is the actual design decision here, not
/// a simplification of one.
///
/// Every step is resilient to interruption on its own:
/// - [_push] processes one outbox entry at a time, each in isolation
///   (spec §5 — a permanently-stuck entry never blocks the others), and
///   only removes an entry from the queue once its own push is confirmed.
/// - [_pull] advances each of the three v10 stream cursors only after its
///   own page has been applied; an app kill mid-page simply re-fetches that
///   page next time, and `INSERT ... ON CONFLICT(id) DO UPDATE`
///   (`upsertFromRemote`) makes replay idempotent.
class SyncEngine {
  final AppDatabase db;
  final LocalVault vault;
  final ObjectUploader uploader;
  final ObjectDownloader downloader;
  final ChildrenRepository childrenRepo;
  final MasterpiecesRepository masterpiecesRepo;
  final SyncBackend cloudApi;
  final SyncOutboxRepository outbox;
  final VaultMetaRepository vaultMeta;
  final String? Function() currentUserId;

  SyncEngine({
    required this.db,
    required this.vault,
    required this.uploader,
    required this.downloader,
    required this.childrenRepo,
    required this.masterpiecesRepo,
    required this.cloudApi,
    required this.outbox,
    required this.vaultMeta,
    required this.currentUserId,
  });

  /// The whole convergence cycle: attach/verify the foyer, push every
  /// pending local change, then pull everything new since this vault's
  /// three independent stream cursors.
  ///
  /// **This is `joinOrRestore` (D13).** There is deliberately no separate
  /// "join a foyer" or "restore this device" method: [ensureFoyer] already
  /// returns the *same* foyer id whether this is the account's first ever
  /// call (creates the foyer) or its thousandth (reads it back), and
  /// [_pull] starts each stream from `epoch` whenever its v10 cursor is
  /// null — which is true for a foyer's founding member exactly as much as
  /// for a brand-new device signing into an existing account. Giving
  /// "join" its own code path would have meant it only ever ran once per
  /// account, in practice untested outside that one moment — precisely
  /// the failure mode the ticket's own rationale for merging C-07 into
  /// C-06 describes. Every call to [syncAll] *is* a join-or-restore call;
  /// most of them simply have nothing new to converge.
  ///
  /// Never throws for "nothing to do" (not signed in, or fully caught up)
  /// — returns a summary with all-zero counts. Does throw
  /// [FoyerMismatchException] when this vault is already attached to a
  /// *different* foyer than the authenticated account (§1's isolation
  /// rule) — the caller (`AccountController`) is responsible for turning
  /// that into a `blocked` status rather than a retryable `failed` one.
  Future<SyncRunSummary> syncAll() async {
    final userId = currentUserId();
    if (userId == null) {
      Log.w('Synchronisation ignorée : session absente', 'Sync');
      return const SyncRunSummary(
        pushSucceeded: 0,
        pushFailed: 0,
        pulledChildren: 0,
        pulledMasterpieces: 0,
      );
    }

    Log.i('Synchronisation démarrée', 'Sync');
    final foyerId = await ensureFoyer();

    final pushResult = await _push(userId: userId, foyerId: foyerId);
    (int, int) pullResult;
    AppFailure? pullError;
    try {
      pullResult = await _pull(foyerId: foyerId);
    } on _PullApplyFailure catch (error, stack) {
      pullResult = (0, 0);
      pullError = error.failure;
      Log.e(
        'Échec d’écriture locale pendant la récupération',
        error,
        stack,
        'Sync',
      );
    }

    final summary = SyncRunSummary(
      pushSucceeded: pushResult.$1,
      pushFailed: pushResult.$2,
      pulledChildren: pullResult.$1,
      pulledMasterpieces: pullResult.$2,
      lastError: pushResult.$3 ?? pullError,
    );
    Log.i(
      'Synchronisation terminée : ${summary.pushSucceeded} envoyés, ${summary.pushFailed} échecs, ${summary.pulledChildren} enfants et ${summary.pulledMasterpieces} œuvres reçus',
      'Sync',
    );
    return summary;
  }

  /// Resolves this account's foyer (creating it on first call — see
  /// migration `0004`'s `ensure_my_foyer`, not yet deployed) and checks it
  /// against this vault's own attachment record, throwing
  /// [FoyerMismatchException] if they conflict. Exposed separately from
  /// [syncAll] so a caller can probe foyer identity/compatibility without
  /// running a full push+pull (e.g. before showing a "this vault belongs
  /// to a different foyer" screen).
  Future<String> ensureFoyer() async {
    final foyerId = await cloudApi.ensureMyFoyer();
    await vaultMeta.attachFoyer(foyerId);
    Log.d('Foyer vérifié et attaché', 'Sync');
    return foyerId;
  }

  // =====================================================================
  // Push — drain the outbox
  // =====================================================================

  /// Returns (succeeded, failed, lastError).
  Future<(int, int, AppFailure?)> _push({
    required String userId,
    required String foyerId,
  }) async {
    final ready = await outbox.listReady();
    Log.i('${ready.length} entrée(s) prêtes à envoyer', 'Sync');
    var succeeded = 0;
    var failed = 0;
    AppFailure? lastError;

    for (final entry in ready) {
      try {
        if (entry.entity == SyncEntityKind.child.wireName) {
          await _pushChild(entry, foyerId: foyerId);
        } else {
          await _pushMasterpiece(entry, foyerId: foyerId, userId: userId);
        }
        await outbox.markSucceeded(entry.seq);
        succeeded++;
      } on DeletedRowUpdateRejectedException {
        // D9: a delete already won elsewhere. This upsert is moot, not a
        // failure — drop it rather than retrying something that can never
        // succeed differently.
        await outbox.markSucceeded(entry.seq);
        Log.w(
          'Entrée ${entry.seq} abandonnée : suppression déjà gagnante',
          'Sync',
        );
      } on _TerminalOutboxFailure catch (e) {
        await outbox.markTerminal(entry.seq);
        Log.w(
          'Entrée ${entry.seq} en échec terminal : ${e.failure.runtimeType}',
          'Sync',
        );
        failed++;
        lastError = e.failure;
      } on RateLimitedException catch (e) {
        await outbox.markFailed(
          entry.seq,
          error: 'rate limited (429)',
          retryAfter: e.retryAfter,
        );
        Log.w('Entrée ${entry.seq} limitée par le service', 'Sync');
        failed++;
        lastError = const RateLimitedFailure();
      } on QuotaExceededException catch (e) {
        // C-08: never terminal — a purge or an expiry (C-12) frees space
        // without any other change, so the next retry of this same entry
        // can simply succeed. The local write already happened; only the
        // send is refused (spec's own "l'enregistrement local réussit").
        final retryAfter = e.resetsAt != null
            ? (e.resetsAt!.isAfter(DateTime.now())
                  ? e.resetsAt!.difference(DateTime.now())
                  : Duration.zero)
            : null;
        await outbox.markFailed(
          entry.seq,
          error: 'quotaExceeded',
          retryAfter: retryAfter,
        );
        Log.w(
          'Entrée ${entry.seq} refusée : quota atteint (reset: ${e.resetsAt})',
          'Sync',
        );
        failed++;
        lastError = QuotaExceededFailure(resetsAt: e.resetsAt);
      } on GlobalUploadsSuspendedException catch (e) {
        await outbox.markFailed(entry.seq, error: 'globalUploadsSuspended');
        Log.w(
          'Entrée ${entry.seq} refusée : sauvegardes globales suspendues',
          'Sync',
        );
        failed++;
        lastError = GlobalUploadsSuspendedFailure(message: e.message);
      } catch (e, st) {
        Log.e('Échec de l’envoi de l’entrée ${entry.seq}', e, st, 'Sync');
        await outbox.markFailed(entry.seq, error: e.toString());
        failed++;
        lastError = NetworkFailure(cause: e, stack: st);
      }
      // Isolation: one entry's exception never stops the loop (spec §5 —
      // "échecs isolés par entrée").
    }

    return (succeeded, failed, lastError);
  }

  Future<void> _pushChild(
    SyncOutboxEntryEntity entry, {
    required String foyerId,
  }) async {
    if (entry.op == SyncOutboxOp.delete.wireName) {
      await cloudApi.softDeleteChild(entry.entityId);
      // D18/ADR 0006: cascade the tombstone to every masterpiece of this
      // child server-side — never `ON DELETE CASCADE` (spec §6), so each
      // masterpiece keeps its own tombstone other devices can converge on.
      await cloudApi.softDeleteMasterpiecesForChild(entry.entityId);
      return;
    }

    final child = await childrenRepo.getById(entry.entityId);
    if (child == null) {
      return; // deleted locally before this upsert ever went out
    }

    await cloudApi.upsertChild(
      id: child.id,
      foyerId: foyerId,
      name: child.name,
      birthDate: child.birthDate,
      createdAt: child.createdAt,
    );
    await childrenRepo.markSynced(child.id);
  }

  Future<void> _pushMasterpiece(
    SyncOutboxEntryEntity entry, {
    required String foyerId,
    required String userId,
  }) async {
    if (entry.op == SyncOutboxOp.delete.wireName) {
      await cloudApi.softDeleteMasterpiece(entry.entityId);
      return;
    }

    final m = await masterpiecesRepo.getById(entry.entityId);
    if (m == null) {
      return; // already gone locally (e.g. cascaded away with its child)
    }

    final row = await (db.select(
      db.masterpiecesTable,
    )..where((t) => t.id.equals(m.id))).getSingleOrNull();

    String displayKey;
    String? thumbnailKey;
    int imageByteSize = row?.byteSize ?? 0;
    var current = m;

    final hasExistingImages = row?.displayObjectKey != null;

    if (hasExistingImages) {
      // Re-use already synced immutable images upon text/audio update
      displayKey = row!.displayObjectKey!;
      thumbnailKey = row.thumbnailObjectKey;
    } else if (m.relativeImagePath == null) {
      // A row this device only knows through `pull` without recorded keys
      throw StateError(
        'masterpiece ${m.id} has no local original and no recorded R2 keys to reuse',
      );
    } else {
      final originalFile = await vault.resolveFile(m.relativeImagePath!);
      if (!await originalFile.exists()) {
        await masterpiecesRepo.markDownloadFailed(m.id);
        throw const _TerminalOutboxFailure(FileMissingFailure());
      }

      if (current.displayImagePath == null ||
          current.thumbnailImagePath == null) {
        await masterpiecesRepo.ensureDerivatives(current.id);
        current = await masterpiecesRepo.getById(current.id) ?? current;
      }
      final displayPath = current.displayImagePath;
      final thumbnailPath = current.thumbnailImagePath;
      if (displayPath == null || thumbnailPath == null) {
        throw StateError('derivatives not ready yet for ${current.id}');
      }

      final displayFile = await vault.resolveFile(displayPath);
      final thumbnailFile = await vault.resolveFile(thumbnailPath);
      if (!await displayFile.exists() || !await thumbnailFile.exists()) {
        throw StateError('derivative files missing on disk for ${current.id}');
      }
      final displayBytes = await displayFile.readAsBytes();

      displayKey = await uploader.uploadDerivative(
        bytes: displayBytes,
        masterpieceId: current.id,
        variant: ObjectVariant.display,
        childId: current.childId,
        fileName: displayFile.path,
      );
      // R2 free tier: no thumbnail in R2, kept locally only
      thumbnailKey = null;
      imageByteSize = displayBytes.length;
    }

    // Audio track handling
    String? audioKey = row?.audioObjectKey;
    int audioByteSize = row?.audioByteSize ?? 0;

    if (current.relativeAudioPath != null) {
      if (audioKey == null) {
        final audioFile = await vault.resolveFile(current.relativeAudioPath!);
        if (await audioFile.exists()) {
          final audioBytes = await audioFile.readAsBytes();
          audioKey = await uploader.uploadDerivative(
            bytes: audioBytes,
            masterpieceId: current.id,
            variant: ObjectVariant.audio,
            fileName: audioFile.path,
          );
          audioByteSize = audioBytes.length;
        }
      }
    } else {
      // If audio was explicitly cleared, null out the key
      if (current.audioDurationMs == null) {
        audioKey = null;
        audioByteSize = 0;
      }
    }

    await cloudApi.upsertMasterpiece(
      id: current.id,
      foyerId: foyerId,
      childId: current.childId,
      displayObjectKey: displayKey,
      thumbnailObjectKey: thumbnailKey,
      audioObjectKey: audioKey,
      audioDurationMs: current.audioDurationMs,
      audioByteSize: audioByteSize,
      addedAt: current.addedAt,
      drawnAt: current.drawnAt,
      story: current.story,
      byteSize: imageByteSize,
      imageWidth: current.imageWidth,
      imageHeight: current.imageHeight,
      addedBy: userId,
    );

    // Save confirmed storage keys locally
    await (db.update(
      db.masterpiecesTable,
    )..where((t) => t.id.equals(current.id))).write(
      MasterpiecesTableCompanion(
        displayObjectKey: Value(displayKey),
        thumbnailObjectKey: Value(thumbnailKey),
        audioObjectKey: Value(audioKey),
        byteSize: Value(imageByteSize),
        audioByteSize: Value(audioByteSize),
        syncState: const Value('synced'),
      ),
    );
  }

  // =====================================================================
  // Pull — independent paginated streams, tombstones included
  // =====================================================================

  /// Returns (children applied, masterpieces applied).
  Future<(int, int)> _pull({required String foyerId}) async {
    final cursors = await vaultMeta.getPullCursors();
    Log.d(
      'Récupération distante : enfants=${cursors.children?.toIso8601String() ?? 'epoch'}, '
          'œuvres=${cursors.masterpieces?.toIso8601String() ?? 'epoch'}, '
          'purges=${cursors.purged?.toIso8601String() ?? 'epoch'}',
      'Sync',
    );

    var childrenApplied = 0;
    var childCursor = cursors.children;
    while (true) {
      final page = await cloudApi.pullChildrenPage(
        foyerId: foyerId,
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

    var masterpiecesApplied = 0;
    var masterpieceCursor = cursors.masterpieces;
    while (true) {
      final page = await cloudApi.pullMasterpiecesPage(
        foyerId: foyerId,
        since: masterpieceCursor,
      );
      final pendingIds = await outbox.pendingEntityIds(
        entity: SyncEntityKind.masterpiece,
      );
      final plan = planPullApply<RemoteMasterpieceRow>(
        pulled: page.items,
        idOf: (r) => r.id,
        updatedAtOf: (r) => r.updatedAt,
        pendingLocalIds: pendingIds,
      );
      for (final row in plan.toApply) {
        if (row.deletedAt != null) {
          final result = await masterpiecesRepo.applyRemoteTombstone(row.id);
          _throwOnPullFailure(result);
          continue;
        }
        final result = await masterpiecesRepo.upsertFromRemote(
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
          byteSize: row.byteSize,
          imageWidth: row.imageWidth,
          imageHeight: row.imageHeight,
        );
        _throwOnPullFailure(result);
        // D10: thumbnails first — eager for a row new to this device, the
        // display derivative stays deferred to [ensureDisplayImageDownloaded].
        await _downloadThumbnailIfNeeded(row);
      }
      masterpiecesApplied += plan.toApply.length;
      masterpieceCursor = _nextPageCursor(
        stream: 'masterpieces',
        current: masterpieceCursor,
        page: page,
        fallback: plan.newCursor,
      );
      if (masterpieceCursor != null) {
        await vaultMeta.setMasterpiecesPullCursor(masterpieceCursor);
      }
      if (!page.hasMore) break;
    }

    // C-12: a device that missed both the soft-delete and the 30-day window
    // learns about the physical removal through the purge-log stream.
    var purgedCursor = cursors.purged;
    while (true) {
      final page = await cloudApi.pullPurgedMasterpieceIdsPage(
        foyerId: foyerId,
        since: purgedCursor,
      );
      for (final row in page.items) {
        final result = await masterpiecesRepo.applyRemoteTombstone(row.id);
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
      'Récupération appliquée : $childrenApplied enfant(s), $masterpiecesApplied œuvre(s)',
      'Sync',
    );
    return (childrenApplied, masterpiecesApplied);
  }

  void _throwOnPullFailure(ActionResult<void> result) {
    if (result case ActionFailed(failure: final failure)) {
      throw _PullApplyFailure(failure);
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

  DateTime? _latestPurged(List<PurgedMasterpieceRow> rows) {
    DateTime? latest;
    for (final row in rows) {
      if (latest == null || row.purgedAt.isAfter(latest)) latest = row.purgedAt;
    }
    return latest;
  }

  Future<void> _downloadThumbnailIfNeeded(RemoteMasterpieceRow row) async {
    final local = await masterpiecesRepo.getById(row.id);
    if (local == null) return;
    // Already has *something* to show locally — either this device
    // authored it (has an original) or a previous pull already fetched a
    // thumbnail. D10 only concerns a row genuinely new to this device.
    if (local.relativeImagePath != null || local.thumbnailImagePath != null) {
      return;
    }
    // R2 refactor: prioritize display download and locally regenerate thumbnail
    final displayKey = row.displayObjectKey;
    if (displayKey != null) {
      try {
        final bytes = await downloader.downloadByKey(displayKey);
        final displayPath = await vault.storeDownloadedDerivative(
          bytes: bytes,
          masterpieceId: row.id,
          isDisplay: true,
        );
        await masterpiecesRepo.markDisplayDownloaded(
          id: row.id,
          displayRelativePath: displayPath,
        );

        // Regenerate local thumbnail from display
        final thumbPath = await vault.generateThumbnailFromDisplay(
          masterpieceId: row.id,
          displayRelativePath: displayPath,
        );
        if (thumbPath != null) {
          await masterpiecesRepo.markThumbnailDownloaded(
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
          await masterpiecesRepo.markDownloadFailed(row.id);
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
        masterpieceId: row.id,
        isDisplay: false,
      );
      await masterpiecesRepo.markThumbnailDownloaded(
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
      await masterpiecesRepo.markDownloadFailed(row.id);
    }
  }

  /// D10's other half — the display derivative, deferred until the
  /// artwork is actually opened (or a future background low-priority
  /// task).
  Future<ActionResultLike> ensureDisplayImageDownloaded(
    String masterpieceId,
  ) async {
    final local = await masterpiecesRepo.getById(masterpieceId);
    if (local == null) return ActionResultLike.notFound;
    if (local.displayImagePath != null || local.relativeImagePath != null) {
      return ActionResultLike.alreadyHave;
    }

    // The R2 key isn't on the domain model (a cache concern, like the
    // paths themselves) — read it straight from the row.
    final row = await (db.select(
      db.masterpiecesTable,
    )..where((t) => t.id.equals(masterpieceId))).getSingleOrNull();
    final key = row?.displayObjectKey;
    if (key == null) return ActionResultLike.noKeyAvailable;

    try {
      final bytes = await downloader.downloadByKey(key);
      final path = await vault.storeDownloadedDerivative(
        bytes: bytes,
        masterpieceId: masterpieceId,
        isDisplay: true,
      );
      await masterpiecesRepo.markDisplayDownloaded(
        id: masterpieceId,
        displayRelativePath: path,
      );
      return ActionResultLike.downloaded;
    } catch (e, st) {
      Log.e(
        'Téléchargement du visuel impossible ($masterpieceId)',
        e,
        st,
        'Sync',
      );
      await masterpiecesRepo.markDownloadFailed(masterpieceId);
      return ActionResultLike.failed;
    }
  }

  /// Downloads the audio track on-demand if not already present locally.
  Future<ActionResultLike> ensureAudioDownloaded(String masterpieceId) async {
    final local = await masterpiecesRepo.getById(masterpieceId);
    if (local == null) return ActionResultLike.notFound;
    if (local.relativeAudioPath != null) return ActionResultLike.alreadyHave;

    final row = await (db.select(
      db.masterpiecesTable,
    )..where((t) => t.id.equals(masterpieceId))).getSingleOrNull();
    final key = row?.audioObjectKey;
    if (key == null) return ActionResultLike.noKeyAvailable;

    try {
      final bytes = await downloader.downloadByKey(key);
      final path = await vault.storeDownloadedAudio(
        bytes: bytes,
        masterpieceId: masterpieceId,
      );
      await masterpiecesRepo.markAudioDownloaded(
        id: masterpieceId,
        audioRelativePath: path,
      );
      return ActionResultLike.downloaded;
    } catch (e, st) {
      Log.e('Téléchargement audio impossible ($masterpieceId)', e, st, 'Sync');
      return ActionResultLike.failed;
    }
  }
}

/// Deliberately not `ActionResult<T>` (`core/result/action_result.dart`):
/// this is an internal, best-effort cache operation on a lazily-fetched
/// derivative, never a user-triggered write whose success/failure the UI
/// must render via `ErrorPresenter` — the same distinction
/// `ensureDerivatives` already draws for the on-device resize path.
enum ActionResultLike {
  downloaded,
  alreadyHave,
  noKeyAvailable,
  notFound,
  failed,
}
