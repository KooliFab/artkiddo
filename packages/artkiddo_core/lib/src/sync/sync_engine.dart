import 'package:drift/drift.dart';

import '../contracts/object_storage.dart';
import '../contracts/sync_backend.dart';
import '../contracts/sync_protocol.dart';
import '../debug/demo_seed.dart';
import '../domain/action_result.dart';
import '../domain/app_failure.dart';
import '../local/database/app_database.dart';
import '../local/logging/log.dart';
import '../local/repositories/children_repository.dart';
import '../local/repositories/artworks_repository.dart';
import '../local/storage/local_vault.dart';
import '../local/storage/media_versions.dart';
import 'change_journal_pull.dart';
import 'legacy_timestamp_pull.dart';
import 'operation_receipts.dart';
import 'replaced_values.dart';
import 'sync_outbox.dart';
import 'vault_meta.dart';

export 'vault_meta.dart' show FamilyMismatchException;

/// Summary of one [SyncEngine.syncAll] run, for `AccountController` to fold
/// into `BackupStatus` (spec §7) without `SyncEngine` knowing about the
/// screen-facing shape.
class SyncRunSummary {
  final int pushSucceeded;
  final int pushFailed;
  final int pulledChildren;
  final int pulledArtworks;
  final AppFailure? lastError;
  const SyncRunSummary({
    required this.pushSucceeded,
    required this.pushFailed,
    required this.pulledChildren,
    required this.pulledArtworks,
    this.lastError,
  });
}

/// Which half of a [SyncEngine.syncAll] run a [SyncProgress] describes.
enum SyncPhase {
  /// Sending this device's pending outbox entries.
  sending,

  /// Receiving and applying the family's remote changes.
  receiving,
}

/// A step of a running [SyncEngine.syncAll], for a composition to render
/// progress. Sending has a known [total] (the ready outbox entries);
/// receiving does not, because pages arrive until the remote says there are
/// no more, so its [total] is null and [done] counts the artworks applied.
class SyncProgress {
  final SyncPhase phase;
  final int done;
  final int? total;
  const SyncProgress({required this.phase, required this.done, this.total});

  @override
  bool operator ==(Object other) =>
      other is SyncProgress &&
      other.phase == phase &&
      other.done == done &&
      other.total == total;

  @override
  int get hashCode => Object.hash(phase, done, total);

  @override
  String toString() => 'SyncProgress($phase, $done/${total ?? '?'})';
}

/// Thrown internally to short-circuit one outbox entry as a *terminal*
/// failure — never retried, exits the queue immediately (spec §5).
class _TerminalOutboxFailure implements Exception {
  final AppFailure failure;
  final bool preservePending;
  const _TerminalOutboxFailure(this.failure, {this.preservePending = false});
}

/// C-06's convergence engine.
///
/// Normative reference: `.scratch/family/issues/C-06-convergence-family.md`.
/// A single entry point, [syncAll], **is** `joinOrRestore` (D13: joining a
/// family and restoring a device are the same operation) — see the method's
/// own doc comment for why unifying them, rather than giving "join" and
/// "restore" separate code paths, is the actual design decision here, not
/// a simplification of one.
///
/// Every step is resilient to interruption on its own:
/// - [_push] processes one outbox entry at a time, each in isolation
///   (spec §5 — a permanently-stuck entry never blocks the others), and
///   only removes an entry from the queue once its own push is confirmed.
/// - [_pull] reads the remote change journal ([ChangeJournalPull]): a page
///   and its cursor are applied in one transaction, so an app kill between
///   pages resumes after the last applied one. Without a [protocolBackend],
///   the deprecated timestamp pull of [cloudApi] runs instead.
class SyncEngine {
  final AppDatabase db;
  final LocalVault vault;
  final ObjectUploader uploader;
  final ObjectDownloader downloader;
  final ChildrenRepository childrenRepo;
  final ArtworksRepository artworksRepo;
  final SyncBackend cloudApi;

  /// When set, operations are sent as [EntityPatch]es through this backend,
  /// their receipts applied field by field, and remote changes read from its
  /// change journal. Otherwise [cloudApi] sends the row an operation points
  /// at and the timestamp pull runs (the interface the compositions use
  /// until they move to sync protocol v3).
  ///
  /// An operation that has no field snapshot and cannot get one from its row
  /// (an artwork, whose photo and audio need media descriptors) waits in the
  /// queue instead of being sent incomplete.
  final SyncProtocolBackend? protocolBackend;
  final SyncOutboxRepository outbox;

  /// Values that lost a conflict, kept for 30 days.
  final ReplacedValuesRepository replacedValues;
  final VaultMetaRepository vaultMeta;
  final String? Function() currentUserId;
  late final OutboxReceiptHandler _receipts;
  late final ChangeJournalPull? _journal = protocolBackend == null
      ? null
      : ChangeJournalPull(
          db,
          protocolBackend!,
          outbox,
          replacedValues,
          vaultMeta,
        );

  /// Optional composition hook used by a provider-specific transport to keep
  /// an entry out of the classic drain while a durable native task owns it.
  /// The core remains unaware of the transport or its task database.
  final Future<bool> Function(SyncOutboxEntryEntity entry)? isEntryDeferred;

  SyncEngine({
    required this.db,
    required this.vault,
    required this.uploader,
    required this.downloader,
    required this.childrenRepo,
    required this.artworksRepo,
    required this.cloudApi,
    required this.outbox,
    required this.vaultMeta,
    required this.currentUserId,
    this.isEntryDeferred,
    this.protocolBackend,
    ReplacedValuesRepository? replacedValues,
  }) : replacedValues = replacedValues ?? ReplacedValuesRepository(db) {
    _receipts = OutboxReceiptHandler(db, outbox, this.replacedValues);
  }

  /// The whole convergence cycle: attach/verify the family, push every
  /// pending local change, then pull everything new since this vault's
  /// journal cursor.
  ///
  /// **This is `joinOrRestore` (D13).** There is deliberately no separate
  /// "join a family" or "restore this device" method: [ensureFamily] already
  /// returns the *same* family id whether this is the account's first ever
  /// call (creates the family) or its thousandth (reads it back), and
  /// [_pull] reads the journal from its beginning whenever the cursor is
  /// null — which is true for a family's founding member exactly as much as
  /// for a brand-new device signing into an existing account. Giving
  /// "join" its own code path would have meant it only ever ran once per
  /// account, in practice untested outside that one moment — precisely
  /// the failure mode the ticket's own rationale for merging C-07 into
  /// C-06 describes. Every call to [syncAll] *is* a join-or-restore call;
  /// most of them simply have nothing new to converge.
  ///
  /// Never throws for "nothing to do" (not signed in, or fully caught up)
  /// — returns a summary with all-zero counts. Does throw
  /// [FamilyMismatchException] when this vault is already attached to a
  /// *different* family than the authenticated account (§1's isolation
  /// rule) — the caller (`AccountController`) is responsible for turning
  /// that into a `blocked` status rather than a retryable `failed` one.
  Future<SyncRunSummary>? _activeSync;

  /// Concurrent lifecycle, trash and manual triggers share one drain. A
  /// caller with a newly queued mutation may request another run afterwards.
  Future<SyncRunSummary> syncAll({
    void Function(SyncProgress progress)? onProgress,
  }) {
    final active = _activeSync;
    if (active != null) return active;
    final run = _runSync(
      onProgress: onProgress,
    ).whenComplete(() => _activeSync = null);
    _activeSync = run;
    return run;
  }

  Future<SyncRunSummary> _runSync({
    void Function(SyncProgress progress)? onProgress,
  }) async {
    await replacedValues.purgeExpired();
    final userId = currentUserId();
    if (userId == null) {
      Log.w('Synchronisation ignorée : session absente', 'Sync');
      return const SyncRunSummary(
        pushSucceeded: 0,
        pushFailed: 0,
        pulledChildren: 0,
        pulledArtworks: 0,
      );
    }

    Log.i('Synchronisation démarrée', 'Sync');
    final familyId = await ensureFamily();

    final pushResult = await _push(
      userId: userId,
      familyId: familyId,
      onProgress: onProgress,
    );
    (int, int) pullResult;
    AppFailure? pullError;
    try {
      pullResult = await _pull(familyId: familyId, onProgress: onProgress);
    } on PullApplyFailure catch (error, stack) {
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
      pulledArtworks: pullResult.$2,
      lastError: pushResult.$3 ?? pullError,
    );
    Log.i(
      'Synchronisation terminée : ${summary.pushSucceeded} envoyés, ${summary.pushFailed} échecs, ${summary.pulledChildren} enfants et ${summary.pulledArtworks} œuvres reçus',
      'Sync',
    );
    return summary;
  }

  /// Resolves this account's family (creating it on first call — see
  /// migration `0004`'s `ensure_my_family`, not yet deployed) and checks it
  /// against this vault's own attachment record, throwing
  /// [FamilyMismatchException] if they conflict. Exposed separately from
  /// [syncAll] so a caller can probe family identity/compatibility without
  /// running a full push+pull (e.g. before showing a "this vault belongs
  /// to a different family" screen).
  Future<String> ensureFamily() async {
    final familyId = await cloudApi.ensureMyFamily();
    if (await vaultMeta.isJoinResetPending()) {
      final localFamilyId = await vaultMeta.getFamilyId();
      if (localFamilyId != null && localFamilyId != familyId) {
        await resetLocalVault();
      } else {
        await vaultMeta.clearJoinResetPending();
      }
    }
    await vaultMeta.attachFamily(familyId);
    Log.d('Family vérifié et attaché', 'Sync');
    return familyId;
  }

  /// Idempotently starts a new local vault. The database clear also removes
  /// the durable join-reset marker, so a process restart cannot replay the
  /// destructive operation after it has completed.
  Future<void> resetLocalVault() async {
    await vault.eraseEverything();
    await db.eraseAllData();
  }

  Future<void> markJoinResetPending() => vaultMeta.markJoinResetPending();

  Future<void> clearJoinResetPending() => vaultMeta.clearJoinResetPending();

  // =====================================================================
  // Push — drain the outbox
  // =====================================================================

  /// Upper bound of drain rounds in one run. A round sends the oldest
  /// operation of each entity; the next round sends the operations, queued
  /// before the run started, that the acknowledgements of the previous one
  /// unblocked. An operation queued while the run is sending waits for the
  /// next run.
  static const _maxPushRounds = 10;

  /// Returns (succeeded, failed, lastError).
  Future<(int, int, AppFailure?)> _push({
    required String userId,
    required String familyId,
    void Function(SyncProgress progress)? onProgress,
  }) async {
    var succeeded = 0;
    var failed = 0;
    AppFailure? lastError;

    final horizon = await outbox.lastSeq();
    for (var round = 1; round <= _maxPushRounds; round++) {
      final ready = [
        for (final entry in await outbox.listReady())
          if (round == 1 || entry.seq <= horizon) entry,
      ];
      if (round == 1) {
        Log.i('${ready.length} entrée(s) prêtes à envoyer', 'Sync');
      } else if (ready.isEmpty) {
        break;
      }
      final succeededBefore = succeeded;
      for (var index = 0; index < ready.length; index++) {
        final entry = ready[index];
        // Reported before each entry, so deferred and skipped entries (which
        // `continue`) still advance the count.
        onProgress?.call(
          SyncProgress(
            phase: SyncPhase.sending,
            done: index,
            total: ready.length,
          ),
        );
        if (isEntryDeferred != null && await isEntryDeferred!(entry)) {
          Log.d('Entrée ${entry.seq} différée par un job natif', 'Sync');
          continue;
        }
        if (entry.entity == SyncEntityKind.child.wireName &&
            isDebugDemoId(entry.entityId)) {
          await outbox.markSucceeded(entry.seq);
          continue;
        }
        try {
          if (protocolBackend != null) {
            if (!await _pushOperation(entry)) continue;
            // The operation is already removed (acknowledged, dropped or
            // replaced inside `_pushOperation`).
            succeeded++;
            continue;
          } else {
            // Persisted before the send: from now on this operation never
            // changes, and an edit made while it is out becomes another one.
            await outbox.markInFlight(entry.seq);
            if (entry.entity == SyncEntityKind.child.wireName) {
              await _pushChild(entry, familyId: familyId);
            } else {
              if (!await _pushArtwork(
                entry,
                familyId: familyId,
                userId: userId,
              )) {
                continue;
              }
            }
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
          if (e.preservePending) {
            await outbox.markFailed(
              entry.seq,
              error: 'audioFileMissing',
              retryAfter: const Duration(hours: 1),
            );
          } else {
            await outbox.markTerminal(entry.seq);
          }
          if (e.preservePending &&
              entry.entity == SyncEntityKind.artwork.wireName) {
            await (db.update(
              db.artworksTable,
            )..where((t) => t.id.equals(entry.entityId))).write(
              const ArtworksTableCompanion(syncState: Value('syncError')),
            );
          }
          Log.w(
            'Entrée ${entry.seq} en échec terminal : ${e.failure.runtimeType}',
            'Sync',
          );
          failed++;
          lastError = e.failure;
        } on AudioConflictException {
          await (db.update(
            db.artworksTable,
          )..where((t) => t.id.equals(entry.entityId))).write(
            const ArtworksTableCompanion(
              audioConflict: Value(true),
              syncState: Value('syncError'),
            ),
          );
          await outbox.markFailed(entry.seq, error: 'audioConflict');
          failed++;
          lastError = const NetworkFailure();
        } on RateLimitedException catch (e) {
          await outbox.markFailed(
            entry.seq,
            error: 'rate limited (429)',
            retryAfter: e.retryAfter,
          );
          Log.w('Entrée ${entry.seq} limitée par le service', 'Sync');
          failed++;
          lastError = const RateLimitedFailure();
        } on SyncRateLimitedException catch (e) {
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
          if (entry.entity == SyncEntityKind.artwork.wireName) {
            await (db.update(
              db.artworksTable,
            )..where((t) => t.id.equals(entry.entityId))).write(
              const ArtworksTableCompanion(syncState: Value('syncError')),
            );
          }
          failed++;
          lastError = NetworkFailure(cause: e, stack: st);
        }
        // Isolation: one entry's exception never stops the loop (spec §5 —
        // "échecs isolés par entrée").
      }
      onProgress?.call(
        SyncProgress(
          phase: SyncPhase.sending,
          done: ready.length,
          total: ready.length,
        ),
      );
      // Only an acknowledgement can unblock a later operation of the same
      // entity; without one, another round would find the same entries.
      if (succeeded == succeededBefore) break;
    }

    return (succeeded, failed, lastError);
  }

  /// Sends one operation as an [EntityPatch] and applies its receipt.
  /// Returns false when the operation cannot be sent yet and stays queued.
  Future<bool> _pushOperation(SyncOutboxEntryEntity entry) async {
    if (entry.entity == SyncEntityKind.artwork.wireName) {
      final artwork = await artworksRepo.getById(entry.entityId);
      if (artwork != null && isDebugDemoId(artwork.childId)) {
        // Demo fixture, never uploaded.
        await outbox.markSucceeded(entry.seq);
        return true;
      }
    }
    // The listed entry may be stale (an edit can have been merged into it
    // since): claim re-reads it, builds the snapshot patch from the current
    // row when it has none, and persists patch + `in_flight` in one
    // transaction, so a crash replays the same `opId` with the same patch.
    final claimed = await outbox.claim(entry.seq, buildPatch: _snapshotPatch);
    final patch = claimed?.patch;
    if (claimed == null || patch == null) {
      final current = await outbox.entryBySeq(entry.seq);
      if (current == null) return true; // acknowledged or dropped meanwhile
      if (entry.entity == SyncEntityKind.child.wireName) {
        // Deleted locally before this upsert ever went out.
        await outbox.markSucceeded(entry.seq);
        return true;
      }
      Log.w(
        'Entrée ${entry.seq} en attente : les médias de l’œuvre ne sont pas '
            'décrits',
        'Sync',
      );
      return false;
    }
    final receipt = await protocolBackend!.applyPatch(patch);
    final outcome = await _receipts.apply(
      entry: claimed,
      patch: patch,
      receipt: receipt,
    );
    if (outcome.conflicts > 0) {
      Log.w(
        'Entrée ${entry.seq} : ${outcome.conflicts} champ(s) en conflit, '
            'valeurs remplacées conservées',
        'Sync',
      );
    }
    return true;
  }

  /// The patch of an operation queued without one, built from its row, or
  /// null when the row is gone or the operation needs media descriptors.
  Future<EntityPatch?> _snapshotPatch(SyncOutboxEntryEntity entry) async {
    if (entry.entity != SyncEntityKind.child.wireName) {
      // A purge needs no row; an artwork edit is not expressible without its
      // media descriptors.
      return entry.op == SyncOutboxOp.delete.wireName
          ? _purgePatch(entry, SyncEntityType.artwork)
          : null;
    }
    if (entry.op == SyncOutboxOp.delete.wireName) {
      return _purgePatch(entry, SyncEntityType.child);
    }
    final row = await (db.select(
      db.childrenTable,
    )..where((t) => t.id.equals(entry.entityId))).getSingleOrNull();
    if (row == null) return null;
    return EntityPatch(
      opId: entry.opId,
      entityType: SyncEntityType.child,
      entityId: row.id,
      baseRevisions: {
        ChildSyncFields.name: row.nameRev,
        ChildSyncFields.birthDate: row.birthDateRev,
      },
      fields: {
        ChildSyncFields.name: row.name,
        ChildSyncFields.birthDate: syncDateValue(row.birthDate),
      },
      createdAt: entry.createdAt,
    );
  }

  EntityPatch _purgePatch(SyncOutboxEntryEntity entry, SyncEntityType type) {
    final lifecycle = type == SyncEntityType.child
        ? ChildSyncFields.lifecycle
        : ArtworkSyncFields.lifecycle;
    return EntityPatch(
      opId: entry.opId,
      entityType: type,
      entityId: entry.entityId,
      baseRevisions: {lifecycle: 0},
      fields: {lifecycle: SyncLifecycle.purged.name},
      createdAt: entry.createdAt,
    );
  }

  Future<void> _pushChild(
    SyncOutboxEntryEntity entry, {
    required String familyId,
  }) async {
    if (entry.op == SyncOutboxOp.delete.wireName) {
      await cloudApi.softDeleteChild(entry.entityId);
      // D18/ADR 0006: cascade the tombstone to every artwork of this
      // child server-side — never `ON DELETE CASCADE` (spec §6), so each
      // artwork keeps its own tombstone other devices can converge on.
      await cloudApi.softDeleteArtworksForChild(entry.entityId);
      return;
    }

    final child = await childrenRepo.getById(entry.entityId);
    if (child == null) {
      return; // deleted locally before this upsert ever went out
    }

    await cloudApi.upsertChild(
      id: child.id,
      familyId: familyId,
      name: child.name,
      birthDate: child.birthDate,
      createdAt: child.createdAt,
    );
    // Acknowledge this operation only. The row is `synced` only when no
    // other operation of the child is left: an edit made while this one was
    // in flight is another operation, still queued.
    await db.transaction(() async {
      await outbox.markSucceeded(entry.seq);
      if (!await outbox.hasOperations(SyncEntityKind.child, child.id)) {
        await childrenRepo.markSynced(child.id);
      }
    });
  }

  Future<bool> _pushArtwork(
    SyncOutboxEntryEntity entry, {
    required String familyId,
    required String userId,
  }) async {
    if (entry.op == SyncOutboxOp.delete.wireName) {
      await cloudApi.softDeleteArtwork(entry.entityId);
      return true;
    }

    final m = await artworksRepo.getById(entry.entityId);
    if (m == null) {
      return true; // already gone locally (e.g. cascaded away with its child)
    }
    if (isDebugDemoId(m.childId)) return true; // demo fixture, never uploaded

    final row = await (db.select(
      db.artworksTable,
    )..where((t) => t.id.equals(m.id))).getSingleOrNull();

    if (row?.audioConflict == true) return false;
    final intent = AudioSyncIntent.values.byName(
      row?.audioSyncIntent ?? 'keep',
    );
    final revision = row?.audioRevision ?? 0;
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
        'artwork ${m.id} has no local original and no recorded object keys to reuse',
      );
    } else {
      final originalFile = await vault.resolveFile(m.relativeImagePath!);
      if (!await originalFile.exists()) {
        await artworksRepo.markDownloadFailed(m.id);
        throw const _TerminalOutboxFailure(FileMissingFailure());
      }

      if (current.displayImagePath == null ||
          current.thumbnailImagePath == null) {
        await artworksRepo.ensureDerivatives(current.id);
        current = await artworksRepo.getById(current.id) ?? current;
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
        artworkId: current.id,
        variant: ObjectVariant.display,
        childId: current.childId,
        fileName: displayFile.path,
      );
      // No thumbnail uploaded to remote storage; kept locally only
      thumbnailKey = null;
      imageByteSize = displayBytes.length;
    }

    // Audio reservations require an existing remote artwork. Commit the
    // confirmed photo first, keeping the pending audio edit in the outbox.
    if (!hasExistingImages && intent == AudioSyncIntent.replace) {
      await cloudApi.upsertArtwork(
        id: current.id,
        familyId: familyId,
        childId: current.childId,
        displayObjectKey: displayKey,
        thumbnailObjectKey: thumbnailKey,
        addedAt: current.addedAt,
        drawnAt: current.drawnAt,
        story: current.story,
        addedBy: userId,
        byteSize: imageByteSize,
        imageWidth: current.imageWidth,
        imageHeight: current.imageHeight,
        audioWrite: AudioWrite(
          intent: AudioSyncIntent.keep,
          expectedRevision: revision,
        ),
      );
      await (db.update(
        db.artworksTable,
      )..where((t) => t.id.equals(current.id))).write(
        ArtworksTableCompanion(
          displayObjectKey: Value(displayKey),
          byteSize: Value(imageByteSize),
        ),
      );
    }

    // Audio track handling
    String? audioKey = row?.audioObjectKey;
    int audioByteSize = row?.audioByteSize ?? 0;

    if (intent == AudioSyncIntent.replace) {
      if (current.relativeAudioPath == null) {
        throw const _TerminalOutboxFailure(
          FileMissingFailure(),
          preservePending: true,
        );
      }
      final audioFile = await vault.resolveFile(current.relativeAudioPath!);
      if (!await audioFile.exists()) {
        throw const _TerminalOutboxFailure(
          FileMissingFailure(),
          preservePending: true,
        );
      }
      final audioBytes = await audioFile.readAsBytes();
      audioKey = await uploader.uploadDerivative(
        bytes: audioBytes,
        artworkId: current.id,
        variant: ObjectVariant.audio,
        childId: current.childId,
        fileName: audioFile.path,
      );
      audioByteSize = audioBytes.length;
    } else if (intent == AudioSyncIntent.delete) {
      audioKey = null;
      audioByteSize = 0;
    }

    await cloudApi.upsertArtwork(
      id: current.id,
      familyId: familyId,
      childId: current.childId,
      displayObjectKey: displayKey,
      thumbnailObjectKey: thumbnailKey,
      audioObjectKey: audioKey,
      audioDurationMs: current.audioDurationMs,
      audioByteSize: audioByteSize,
      audioWrite: AudioWrite(intent: intent, expectedRevision: revision),
      addedAt: current.addedAt,
      drawnAt: current.drawnAt,
      story: current.story,
      byteSize: imageByteSize,
      imageWidth: current.imageWidth,
      imageHeight: current.imageHeight,
      addedBy: userId,
    );

    // A user can edit again while bytes are in flight. Advance the baseline
    // but only acknowledge the exact content that was sent.
    return db.transaction(() async {
      final latest = await (db.select(
        db.artworksTable,
      )..where((t) => t.id.equals(current.id))).getSingleOrNull();
      if (latest == null || latest.deletedAt != null) return false;
      final matches =
          latest.relativeAudioPath == current.relativeAudioPath &&
          latest.audioDurationMs == current.audioDurationMs &&
          latest.story == current.story &&
          latest.drawnAt == current.drawnAt &&
          latest.audioRevision == revision &&
          latest.audioSyncIntent == intent.name;
      // Acknowledge this operation only. Whatever changed while it was in
      // flight is another operation, still queued; if the row moved without
      // one, queue a fresh one so nothing waits on a state that is never
      // sent.
      await outbox.markSucceeded(entry.seq);
      final queued = await outbox.hasOperations(
        SyncEntityKind.artwork,
        current.id,
      );
      await (db.update(
        db.artworksTable,
      )..where((t) => t.id.equals(current.id))).write(
        ArtworksTableCompanion(
          displayObjectKey: Value(displayKey),
          thumbnailObjectKey: Value(thumbnailKey),
          audioObjectKey: Value(audioKey),
          byteSize: Value(imageByteSize),
          audioByteSize: matches ? Value(audioByteSize) : const Value.absent(),
          audioRevision: Value(
            intent == AudioSyncIntent.keep ? revision : revision + 1,
          ),
          audioSyncIntent: matches ? const Value('keep') : const Value.absent(),
          syncState: Value(matches && !queued ? 'synced' : 'localOnly'),
        ),
      );
      if (!matches && !queued) {
        await outbox.enqueue(
          entity: SyncEntityKind.artwork,
          entityId: current.id,
          op: SyncOutboxOp.upsert,
        );
      }
      return true;
    });
  }

  // =====================================================================
  // Pull
  // =====================================================================

  /// Returns (children applied, artworks applied).
  Future<(int, int)> _pull({
    required String familyId,
    void Function(SyncProgress progress)? onProgress,
  }) async {
    onProgress?.call(const SyncProgress(phase: SyncPhase.receiving, done: 0));
    final journal = _journal;
    if (journal == null) {
      return LegacyTimestampPull(
        cloudApi: cloudApi,
        downloader: downloader,
        vault: vault,
        childrenRepo: childrenRepo,
        artworksRepo: artworksRepo,
        outbox: outbox,
        vaultMeta: vaultMeta,
      ).run(familyId: familyId, onProgress: onProgress);
    }
    final (children, artworks) = await journal.run(
      onArtworks: (done) => onProgress?.call(
        SyncProgress(phase: SyncPhase.receiving, done: done),
      ),
    );
    Log.i(
      'Journal appliqué : $children changement(s) d’enfant, '
          '$artworks d’œuvre',
      'Sync',
    );
    return (children, artworks);
  }

  /// D10's other half — the display derivative, deferred until the
  /// artwork is actually opened (or a future background low-priority
  /// task).
  Future<ActionResultLike> ensureDisplayImageDownloaded(
    String artworkId,
  ) async {
    final local = await artworksRepo.getById(artworkId);
    if (local == null) return ActionResultLike.notFound;
    if (local.displayImagePath != null || local.relativeImagePath != null) {
      return ActionResultLike.alreadyHave;
    }

    // The object key isn't on the domain model (a cache concern, like the
    // paths themselves) — read it straight from the row.
    final row = await (db.select(
      db.artworksTable,
    )..where((t) => t.id.equals(artworkId))).getSingleOrNull();
    final key = row?.displayObjectKey;
    if (key == null) return ActionResultLike.noKeyAvailable;

    try {
      final bytes = await downloader.downloadByKey(key);
      final path = await vault.storeDownloadedDerivative(
        bytes: bytes,
        artworkId: artworkId,
        isDisplay: true,
      );
      await artworksRepo.markDisplayDownloaded(
        id: artworkId,
        displayRelativePath: path,
      );
      return ActionResultLike.downloaded;
    } catch (e, st) {
      Log.e('Téléchargement du visuel impossible ($artworkId)', e, st, 'Sync');
      await artworksRepo.markDownloadFailed(artworkId);
      return ActionResultLike.failed;
    }
  }

  /// Resolve only the audio field; independent local text edits remain queued.
  Future<bool> resolveAudioConflict(
    String artworkId, {
    required bool keepLocal,
  }) async {
    try {
      final familyId = await ensureFamily();
      final remote = await cloudApi.readArtwork(
        id: artworkId,
        familyId: familyId,
      );
      if (remote == null || remote.deletedAt != null) return false;
      final old = await artworksRepo.getById(artworkId);
      if (old == null) return false;
      await db.transaction(() async {
        await (db.update(
          db.artworksTable,
        )..where((t) => t.id.equals(artworkId))).write(
          ArtworksTableCompanion(
            audioRevision: Value(remote.audioRevision),
            audioObjectKey: Value(remote.audioObjectKey),
            audioConflict: const Value(false),
            syncState: const Value('localOnly'),
            audioSyncIntent: keepLocal
                ? const Value.absent()
                : const Value('keep'),
            relativeAudioPath: keepLocal
                ? const Value.absent()
                : const Value(null),
            audioDurationMs: keepLocal
                ? const Value.absent()
                : Value(remote.audioDurationMs),
            audioByteSize: keepLocal
                ? const Value.absent()
                : Value(remote.audioByteSize),
          ),
        );
        await (db.update(db.syncOutboxTable)..where(
              (t) => t.entityId.equals(artworkId) & t.entity.equals('artwork'),
            ))
            .write(
              const SyncOutboxTableCompanion(
                attempts: Value(0),
                nextAttemptAt: Value(null),
                lastError: Value(null),
              ),
            );
      });
      if (!keepLocal && old.relativeAudioPath != null) {
        await vault.deleteAudioFileOrEnqueueCleanup(
          relativeAudioPath: old.relativeAudioPath,
          db: db,
        );
      }
      return true;
    } catch (e, st) {
      Log.e('Audio conflict resolution failed', e, st, 'Sync');
      return false;
    }
  }

  /// Downloads the audio track on-demand if not already present locally.
  Future<ActionResultLike> ensureAudioDownloaded(String artworkId) async {
    final local = await artworksRepo.getById(artworkId);
    if (local == null) return ActionResultLike.notFound;
    if (local.relativeAudioPath != null) {
      final file = await vault.resolveFile(local.relativeAudioPath!);
      if (await file.exists()) {
        return ActionResultLike.alreadyHave;
      }
      Log.w(
        'Fichier audio introuvable sur le disque pour $artworkId (${local.relativeAudioPath}), relance du téléchargement distant',
        'Sync',
      );
    }

    final row = await (db.select(
      db.artworksTable,
    )..where((t) => t.id.equals(artworkId))).getSingleOrNull();
    if (row?.audioSyncIntent != 'keep') return ActionResultLike.failed;
    final key = row?.audioObjectKey;
    if (key == null) return ActionResultLike.noKeyAvailable;

    try {
      final bytes = await downloader.downloadByKey(key);
      final media = MediaVersionsRepository(db);
      final version = await media.nextVersion(artworkId, MediaRole.audio);
      final path = await vault.storeDownloadedAudio(
        bytes: bytes,
        artworkId: artworkId,
        version: version,
      );
      final stored = await artworksRepo.markAudioDownloaded(
        id: artworkId,
        audioRelativePath: path,
        expectedAudioRevision: row!.audioRevision,
      );
      if (stored is ActionFailed) {
        await vault.deleteAudioFileOrEnqueueCleanup(
          relativeAudioPath: path,
          db: db,
        );
        return ActionResultLike.failed;
      }
      await media.record(
        mediaId: artworkId,
        version: version,
        role: MediaRole.audio,
        localPath: path,
        byteSize: bytes.length,
      );
      return ActionResultLike.downloaded;
    } catch (e, st) {
      Log.e('Téléchargement audio impossible ($artworkId)', e, st, 'Sync');
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
