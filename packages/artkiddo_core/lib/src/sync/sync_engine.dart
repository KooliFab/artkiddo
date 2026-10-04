import 'package:drift/drift.dart';

import '../contracts/object_storage.dart';
import '../contracts/sync_protocol.dart';
import '../debug/demo_seed.dart';
import '../domain/app_failure.dart';
import '../local/database/app_database.dart';
import '../local/logging/log.dart';
import '../local/repositories/artworks_repository.dart';
import '../local/storage/local_vault.dart';
import 'change_journal_pull.dart';
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
///   pages resumes after the last applied one.
class SyncEngine {
  final AppDatabase db;
  final LocalVault vault;
  final ArtworksRepository artworksRepo;

  /// The remote side of sync protocol v3: operations are sent as
  /// [EntityPatch]es, their receipts applied field by field, and remote
  /// changes read from its change journal.
  ///
  /// An operation that has no field snapshot and cannot get one from its row
  /// (an artwork, whose photo and audio need media descriptors) waits in the
  /// queue until its patch is stored with it, instead of being sent
  /// incomplete.
  final SyncProtocolBackend protocolBackend;

  /// The family of the signed-in account, created on the account's first
  /// call. The protocol itself resolves the family from the session; the
  /// engine only needs its id to attach this vault to it.
  final Future<String> Function() ensureMyFamily;
  final SyncOutboxRepository outbox;

  /// Values that lost a conflict, kept for 30 days.
  final ReplacedValuesRepository replacedValues;
  final VaultMetaRepository vaultMeta;
  final String? Function() currentUserId;
  late final OutboxReceiptHandler _receipts;
  late final ChangeJournalPull _journal = ChangeJournalPull(
    db,
    protocolBackend,
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
    required this.artworksRepo,
    required this.protocolBackend,
    required this.ensureMyFamily,
    required this.outbox,
    required this.vaultMeta,
    required this.currentUserId,
    this.isEntryDeferred,
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
    await ensureFamily();

    final pushResult = await _push(onProgress: onProgress);
    (int, int) pullResult;
    AppFailure? pullError;
    try {
      pullResult = await _pull(onProgress: onProgress);
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
    final familyId = await ensureMyFamily();
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
          if (!await _pushOperation(entry)) continue;
          // The operation is already removed (acknowledged, dropped or
          // replaced inside `_pushOperation`).
          succeeded++;
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
    var sent = patch;
    MutationReceipt receipt;
    try {
      receipt = await protocolBackend.applyPatch(sent);
    } on SyncAuthException catch (e) {
      if (e.failure != SyncAuthFailure.notFamilyMember ||
          !_isArtworkPurge(patch)) {
        rethrow;
      }
      // A purge is refused to anyone but an active parent. The artwork is
      // already gone here, so the operation becomes a plain trash (open to
      // every member): the server keeps it and expires it after 30 days.
      sent = EntityPatch(
        opId: outbox.newOpId(),
        entityType: SyncEntityType.artwork,
        entityId: patch.entityId,
        baseRevisions: {ArtworkSyncFields.lifecycle: 0},
        fields: {ArtworkSyncFields.lifecycle: SyncLifecycle.trashed.name},
        createdAt: patch.createdAt,
      );
      await outbox.replacePatch(entry.seq, sent);
      Log.w(
        'Entrée ${entry.seq} : purge refusée, envoyée en corbeille',
        'Sync',
      );
      receipt = await protocolBackend.applyPatch(sent);
    }
    final outcome = await _receipts.apply(
      entry: claimed,
      patch: sent,
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

  bool _isArtworkPurge(EntityPatch patch) =>
      patch.entityType == SyncEntityType.artwork &&
      patch.fields[ArtworkSyncFields.lifecycle] == SyncLifecycle.purged.name;

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

  // =====================================================================
  // Pull
  // =====================================================================

  /// Returns (children applied, artworks applied).
  Future<(int, int)> _pull({
    void Function(SyncProgress progress)? onProgress,
  }) async {
    onProgress?.call(const SyncProgress(phase: SyncPhase.receiving, done: 0));
    final (children, artworks) = await _journal.run(
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
}
