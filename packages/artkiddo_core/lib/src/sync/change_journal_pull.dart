import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../contracts/sync_protocol.dart';
import '../domain/app_failure.dart';
import '../local/database/app_database.dart';
import '../local/logging/log.dart';
import '../local/storage/local_vault.dart';
import '../local/storage/media_versions.dart';
import 'operation_receipts.dart';
import 'replaced_values.dart';
import 'sync_outbox.dart';
import 'vault_meta.dart';

/// A page could not be written locally. Nothing of it was applied and the
/// cursor did not move: the next run reads the same page again.
class PullApplyFailure implements Exception {
  final AppFailure failure;
  const PullApplyFailure(this.failure);
}

/// Reads the remote change journal and applies it (sync protocol v3).
///
/// Pages are read after the stored cursor while the remote side has more.
/// Each page is applied and its `nextCursor` stored in **one transaction**,
/// so a crash between two pages resumes exactly after the last applied one.
///
/// Rules for a change, field by field:
///
/// * a field no local operation changes takes the remote value and revision;
/// * a field a local operation still changes keeps its local value; the
///   remote value goes to `replaced_values` unless it is already known
///   locally (a revision the operation is already based on, or the same
///   value);
/// * the echo of an operation of this device whose answer has not arrived
///   acknowledges it, as its receipt would ([OutboxReceiptHandler]);
/// * a field holding an edit refused by a remote trash
///   ([ReplacedValuesRepository.hold]) keeps it; a remote restore sends it
///   again as a new operation, a remote purge drops it;
/// * a remote trash or purge moves the artwork to the local trash, keeping
///   its files and its operations (physical deletion is the local trash's
///   job); a remote child purge does the same with the child's artworks. A
///   purged artwork that holds no local file and no operation is only a
///   copy of what is gone: its row is removed;
/// * an artwork that arrives before its child waits in
///   `deferred_remote_changes` and is applied when the child arrives;
/// * a new media version is registered in `media_versions` as
///   `pendingDownload` (`missing` when the remote side reports it
///   unavailable); the download queue reads those rows.
///
/// Nothing is deleted because it is absent remotely, and an invalid cursor
/// restarts the read from the beginning with the same rules.
class ChangeJournalPull {
  final AppDatabase _db;
  final SyncProtocolBackend _backend;
  final SyncOutboxRepository _outbox;
  final ReplacedValuesRepository _replaced;
  final VaultMetaRepository _vaultMeta;
  final MediaVersionsRepository _media;
  final OutboxReceiptHandler _receipts;
  final DateTime Function() _now;

  ChangeJournalPull(
    this._db,
    this._backend,
    this._outbox,
    this._replaced,
    this._vaultMeta, {
    DateTime Function()? now,
  }) : _media = MediaVersionsRepository(_db),
       _receipts = OutboxReceiptHandler(_db, _outbox, _replaced),
       _now = now ?? DateTime.now;

  /// How many times one run restarts from the beginning after the remote
  /// side rejected its cursor.
  static const _maxRestarts = 3;

  /// Returns how many child and artwork changes were applied.
  /// [onArtworks] receives the running count of artwork changes.
  Future<(int, int)> run({void Function(int artworks)? onArtworks}) async {
    var cursor = await _vaultMeta.getChangeCursor();
    var restarts = 0;
    var children = 0;
    var artworks = 0;
    while (true) {
      final SyncChangePage page;
      try {
        page = await _backend.pullChanges(cursor);
      } on ChangeCursorInvalidException catch (e) {
        if (cursor == null || restarts++ >= _maxRestarts) rethrow;
        // Local data and pending operations stay; the whole journal is
        // applied again with the same rules.
        Log.w(
          'Curseur du journal refusé (${e.reason.name}) : relecture '
              'depuis le début',
          'Sync',
        );
        // Values held against the history that is no longer valid: the
        // local ones stay until the new history says otherwise.
        await _db.delete(_db.olderRemoteValuesTable).go();
        cursor = null;
        continue;
      }
      try {
        await _db.transaction(() async {
          for (final change in page.changes) {
            await _apply(change);
          }
          if (!page.hasMore) await _settleOlder();
          await _vaultMeta.setChangeCursor(page.nextCursor);
        });
      } catch (e, st) {
        throw PullApplyFailure(LocalWriteFailure(cause: e, stack: st));
      }
      for (final change in page.changes) {
        if (change.entityType == SyncEntityType.child) {
          children++;
        } else {
          artworks++;
        }
      }
      onArtworks?.call(artworks);
      cursor = page.nextCursor;
      if (!page.hasMore) return (children, artworks);
    }
  }

  Future<void> _apply(SyncChange change) => switch (change.entityType) {
    SyncEntityType.child => _applyChild(change),
    SyncEntityType.artwork => _applyArtwork(change),
  };

  // -------------------------------------------------------------------------
  // Children
  // -------------------------------------------------------------------------

  Future<void> _applyChild(SyncChange change) async {
    final id = change.entityId;
    await _acknowledgeEcho(change);
    final row = await _child(id);
    final local = await _LocalOps.read(_outbox, SyncEntityKind.child, id);
    final snapshot = change.snapshot;
    if (snapshot == null) return _purgeChild(id, row, local);
    final fields = snapshot.fields;
    final revisions = snapshot.revisions;

    if (row == null) {
      // Deleted here, deletion not acknowledged yet: not resurrected.
      if (local.removes) return;
      final now = _now();
      await _db
          .into(_db.childrenTable)
          .insert(
            ChildrenTableCompanion.insert(
              id: id,
              name: fields[ChildSyncFields.name] as String,
              birthDate: DateTime.parse(
                fields[ChildSyncFields.birthDate] as String,
              ),
              createdAt: now,
              updatedAt: now,
              syncState: const Value('synced'),
              nameRev: Value(revisions[ChildSyncFields.name] ?? 0),
              birthDateRev: Value(revisions[ChildSyncFields.birthDate] ?? 0),
              lifecycleRev: Value(revisions[ChildSyncFields.lifecycle] ?? 0),
            ),
          );
      return _applyDeferred(id);
    }

    Future<bool> remoteWins(String field, int localRev, Object? localValue) =>
        _remoteWins(
          change,
          local,
          field: field,
          localRev: localRev,
          localValue: localValue,
        );

    for (final field in const [
      ChildSyncFields.name,
      ChildSyncFields.birthDate,
    ]) {
      final (revision, value) = _childLocal(row, field);
      if (await remoteWins(field, revision, value)) {
        await _setChild(id, _childRemote(field, snapshot));
      }
    }
    var companion = const ChildrenTableCompanion();
    if (!local.changes(ChildSyncFields.lifecycle)) {
      companion = companion.copyWith(
        lifecycleRev: Value(revisions[ChildSyncFields.lifecycle] ?? 0),
      );
    }
    // A snapshot is an active child (a purge has none).
    if (row.deletedAt != null && !local.removes) {
      companion = companion.copyWith(deletedAt: const Value(null));
    }
    await _setChild(id, companion);
    await _applyDeferred(id);
  }

  /// Revision and protocol value of [field] on [row].
  static (int, Object?) _childLocal(ChildEntity row, String field) =>
      switch (field) {
        ChildSyncFields.name => (row.nameRev, row.name),
        _ => (row.birthDateRev, syncDateValue(row.birthDate)),
      };

  /// The columns of [field] set to its value and revision in [snapshot].
  static ChildrenTableCompanion _childRemote(
    String field,
    EntitySnapshot snapshot,
  ) {
    final value = snapshot.fields[field] as String;
    final revision = Value(snapshot.revisions[field] ?? 0);
    return switch (field) {
      ChildSyncFields.name => ChildrenTableCompanion(
        name: Value(value),
        nameRev: revision,
      ),
      _ => ChildrenTableCompanion(
        birthDate: Value(DateTime.parse(value)),
        birthDateRev: revision,
      ),
    };
  }

  /// The child's artworks go to the local trash with their files and
  /// operations. The row itself is removed only when nothing depends on it
  /// any more; otherwise it stays, hidden, as their parent.
  Future<void> _purgeChild(String id, ChildEntity? row, _LocalOps local) async {
    final dropped = await (_db.delete(
      _db.deferredRemoteChangesTable,
    )..where((t) => t.childId.equals(id))).go();
    if (dropped > 0) {
      Log.i(
        '$dropped œuvre(s) en attente d’un enfant purgé abandonnée(s)',
        'Sync',
      );
    }
    if (row == null) return;
    final now = _now();
    await (_db.update(_db.artworksTable)
          ..where((t) => t.childId.equals(id) & t.deletedAt.isNull()))
        .write(ArtworksTableCompanion(deletedAt: Value(now)));
    if (row.deletedAt == null) {
      await (_db.update(_db.childrenTable)..where((t) => t.id.equals(id)))
          .write(ChildrenTableCompanion(deletedAt: Value(now)));
    }
    await _dropHiddenChild(id);
  }

  /// Removes a child purged remotely once no artwork and no operation
  /// depends on it any more.
  Future<void> _dropHiddenChild(String id) async {
    final row = await _child(id);
    if (row == null || row.deletedAt == null) return;
    final artworks =
        await (_db.select(_db.artworksTable)
              ..where((t) => t.childId.equals(id))
              ..limit(1))
            .get();
    if (artworks.isNotEmpty) return;
    if (!(await _LocalOps.read(_outbox, SyncEntityKind.child, id)).isEmpty) {
      return;
    }
    await (_db.delete(_db.childrenTable)..where((t) => t.id.equals(id))).go();
  }

  Future<void> _applyDeferred(String childId) async {
    final waiting = await (_db.select(
      _db.deferredRemoteChangesTable,
    )..where((t) => t.childId.equals(childId))).get();
    for (final entry in waiting) {
      await _applyArtwork(SyncChange.fromJson(jsonDecode(entry.changeJson)));
    }
  }

  // -------------------------------------------------------------------------
  // Artworks
  // -------------------------------------------------------------------------

  Future<void> _applyArtwork(SyncChange change) async {
    final id = change.entityId;
    // Whatever waited for this artwork is superseded by this change.
    await (_db.delete(
      _db.deferredRemoteChangesTable,
    )..where((t) => t.artworkId.equals(id))).go();
    await _acknowledgeEcho(change);
    final row = await _artwork(id);
    final local = await _LocalOps.read(_outbox, SyncEntityKind.artwork, id);
    final snapshot = change.snapshot;
    if (snapshot == null) {
      // Purged remotely: what this device holds (files, operations) stays in
      // the local trash; a row holding neither only mirrored what is gone.
      if (row == null) return;
      // A held edit can never be sent again.
      await _replaced.release(id);
      if (local.isEmpty && !_holdsFiles(row)) {
        await _dropArtwork(row);
        return;
      }
      final now = _now();
      await _setArtwork(
        id,
        ArtworksTableCompanion(
          deletedAt: row.deletedAt == null ? Value(now) : const Value.absent(),
          remotePurgedAt: Value(row.remotePurgedAt ?? now),
        ),
      );
      return;
    }
    final fields = snapshot.fields;
    final revisions = snapshot.revisions;
    final trashed =
        (fields[ArtworkSyncFields.lifecycle] ?? SyncLifecycle.active.name) !=
        SyncLifecycle.active.name;

    if (row == null) {
      if (local.removes) return;
      final childId = fields[ArtworkSyncFields.childId] as String;
      if (await _child(childId) == null) {
        await _db
            .into(_db.deferredRemoteChangesTable)
            .insertOnConflictUpdate(
              DeferredRemoteChangesTableCompanion.insert(
                artworkId: id,
                childId: childId,
                changeJson: jsonEncode(change.toJson()),
              ),
            );
        return;
      }
      final drawnAt = fields[ArtworkSyncFields.drawnAt] as String?;
      await _db
          .into(_db.artworksTable)
          .insert(
            ArtworksTableCompanion.insert(
              id: id,
              childId: childId,
              addedAt: DateTime.parse(
                fields[ArtworkSyncFields.addedAt] as String,
              ),
              story: Value(fields[ArtworkSyncFields.story] as String?),
              drawnAt: Value(drawnAt == null ? null : DateTime.parse(drawnAt)),
              addedBy: Value(fields[ArtworkSyncFields.addedBy] as String?),
              storyRev: Value(revisions[ArtworkSyncFields.story] ?? 0),
              drawnAtRev: Value(revisions[ArtworkSyncFields.drawnAt] ?? 0),
              lifecycleRev: Value(revisions[ArtworkSyncFields.lifecycle] ?? 0),
              deletedAt: Value(trashed ? _now() : null),
              syncState: const Value('synced'),
            ),
          );
      await _applyPhoto(id, snapshot);
      await _setArtwork(id, await _remoteAudio(id, null, snapshot));
      return;
    }

    Future<bool> remoteWins(String field, int localRev, Object? localValue) =>
        _remoteWins(
          change,
          local,
          field: field,
          localRev: localRev,
          localValue: localValue,
        );

    // An edit the remote side refused while the artwork was trashed there
    // stays on the row (the contract keeps it until it is acknowledged).
    final held = {
      for (final MapEntry(:key, :value) in (await _replaced.heldValues(
        id,
      )).entries)
        if (!local.changes(key)) key: value,
    };
    final localAudio = await _localAudio(row);
    for (final field in _artworkFields) {
      if (held.containsKey(field)) continue;
      final (revision, value) = _artworkLocal(row, field, localAudio);
      if (await remoteWins(field, revision, value)) {
        await _setArtwork(
          id,
          await _artworkRemote(id, field, snapshot, localAudio),
        );
      }
    }
    var companion = ArtworksTableCompanion(
      addedBy: fields.containsKey(ArtworkSyncFields.addedBy)
          ? Value(fields[ArtworkSyncFields.addedBy] as String?)
          : const Value.absent(),
      // A snapshot means the remote side has the artwork again (its
      // history was restored).
      remotePurgedAt: row.remotePurgedAt == null
          ? const Value.absent()
          : const Value(null),
    );
    // A trash or a purge wins over local edits, which stay queued; a
    // restore does not undo a local trash still waiting to be sent.
    if (trashed) {
      if (row.deletedAt == null) {
        companion = companion.copyWith(deletedAt: Value(_now()));
      }
    } else if (row.deletedAt != null && !local.removes) {
      companion = companion.copyWith(deletedAt: const Value(null));
    }
    if (!local.changes(ArtworkSyncFields.lifecycle)) {
      companion = companion.copyWith(
        lifecycleRev: Value(revisions[ArtworkSyncFields.lifecycle] ?? 0),
      );
    }
    await _setArtwork(id, companion);
    // Restored remotely: the held edit goes out on top of the remote
    // revision, so this device and the remote side do not silently diverge.
    if (!trashed && held.isNotEmpty && !local.removes) {
      await _outbox.enqueuePatch(
        EntityPatch(
          opId: _outbox.newOpId(),
          entityType: SyncEntityType.artwork,
          entityId: id,
          baseRevisions: {
            for (final field in held.keys) field: revisions[field] ?? 0,
          },
          fields: held,
          createdAt: _now(),
        ),
      );
    }
    if (row.relativeImagePath == null && row.displayImagePath == null) {
      await _applyPhoto(id, snapshot);
    }
  }

  static const _artworkFields = [
    ArtworkSyncFields.story,
    ArtworkSyncFields.drawnAt,
    ArtworkSyncFields.audio,
  ];

  /// Revision and protocol value of [field] on [row]; [localAudio] is the
  /// version its audio file is, when known.
  static (int, Object?) _artworkLocal(
    ArtworkEntity row,
    String field,
    MediaRef? localAudio,
  ) => switch (field) {
    ArtworkSyncFields.story => (row.storyRev, row.story),
    ArtworkSyncFields.drawnAt => (
      row.drawnAtRev,
      row.drawnAt == null ? null : syncDateValue(row.drawnAt!),
    ),
    _ => (row.audioRevision, localAudio?.toJson()),
  };

  /// The columns of [field] set to its value and revision in [snapshot].
  Future<ArtworksTableCompanion> _artworkRemote(
    String id,
    String field,
    EntitySnapshot snapshot,
    MediaRef? localAudio,
  ) async {
    final revision = Value(snapshot.revisions[field] ?? 0);
    switch (field) {
      case ArtworkSyncFields.story:
        return ArtworksTableCompanion(
          story: Value(snapshot.fields[field] as String?),
          storyRev: revision,
        );
      case ArtworkSyncFields.drawnAt:
        final drawnAt = snapshot.fields[field] as String?;
        return ArtworksTableCompanion(
          drawnAt: Value(drawnAt == null ? null : DateTime.parse(drawnAt)),
          drawnAtRev: revision,
        );
      default:
        return _remoteAudio(id, localAudio, snapshot);
    }
  }

  static bool _holdsFiles(ArtworkEntity row) =>
      row.relativeImagePath != null ||
      row.displayImagePath != null ||
      row.thumbnailImagePath != null ||
      row.relativeAudioPath != null;

  /// Removes the row of an artwork purged remotely that has nothing on this
  /// device, with the downloads still waiting for it.
  Future<void> _dropArtwork(ArtworkEntity row) async {
    await (_db.delete(_db.mediaVersionsTable)..where(
          (t) =>
              t.state.equals(MediaVersionState.present.name).not() &
              (t.localPath.equals(_displayPath(row.id)) |
                  (t.mediaId.equals(row.id) &
                      t.role.equals(MediaRole.audio.name))),
        ))
        .go();
    await (_db.delete(
      _db.artworksTable,
    )..where((t) => t.id.equals(row.id))).go();
    await _dropHiddenChild(row.childId);
  }

  static String _displayPath(String artworkId) =>
      p.join(LocalVault.derivativesFolder, '${artworkId}_display.jpg');

  /// Registers the remote photo for download, to the path of the artwork's
  /// display image (a photo and an audio of one artwork cannot share a
  /// media id and version, so the path names the artwork). A device that
  /// already has an image of the artwork (its creator) does not download it.
  Future<void> _applyPhoto(String artworkId, EntitySnapshot snapshot) async {
    final value = snapshot.fields[ArtworkSyncFields.photo];
    if (value == null) return;
    final ref = MediaRef.fromJson(value);
    await _registerRemote(
      ref,
      MediaRole.optimized,
      _displayPath(artworkId),
      snapshot,
    );
  }

  /// The audio columns for the remote audio of [snapshot]. A version this
  /// device holds is pointed at directly; another one is registered for
  /// download and the row has no local file until it arrives. Versions
  /// waiting for a download that the remote side has replaced are dropped:
  /// at most one audio version of an artwork waits.
  Future<ArtworksTableCompanion> _remoteAudio(
    String artworkId,
    MediaRef? localAudio,
    EntitySnapshot snapshot,
  ) async {
    final value = snapshot.fields[ArtworkSyncFields.audio];
    final ref = value == null ? null : MediaRef.fromJson(value);
    final revision = Value(snapshot.revisions[ArtworkSyncFields.audio] ?? 0);
    await (_db.delete(_db.mediaVersionsTable)..where(
          (t) =>
              t.mediaId.isIn({artworkId, ?ref?.mediaId}) &
              t.role.equals(MediaRole.audio.name) &
              t.state.equals(MediaVersionState.pendingDownload.name) &
              (ref == null
                  ? const Constant(true)
                  : t.version.equals(ref.version).not()),
        ))
        .go();
    if (ref == null) {
      return ArtworksTableCompanion(
        relativeAudioPath: const Value(null),
        audioDurationMs: const Value(null),
        audioByteSize: const Value(0),
        audioRevision: revision,
      );
    }
    final descriptor = snapshot.media.firstWhere((m) => m.ref == ref);
    final held = await _version(ref, MediaRole.audio);
    final present = held?.state == MediaVersionState.present.name;
    if (!present) {
      await _registerRemote(
        ref,
        MediaRole.audio,
        LocalVault.audioVersionPath(ref.mediaId, ref.version),
        snapshot,
      );
    }
    return ArtworksTableCompanion(
      relativeAudioPath: Value(present ? held!.localPath : null),
      audioDurationMs: Value(descriptor.durationMs),
      audioByteSize: Value(descriptor.byteSize),
      audioRevision: revision,
    );
  }

  /// Records that [ref] exists remotely and is not on this device, unless
  /// its file is already here.
  Future<void> _registerRemote(
    MediaRef ref,
    MediaRole role,
    String localPath,
    EntitySnapshot snapshot,
  ) async {
    final held = await _version(ref, role);
    if (held?.state == MediaVersionState.present.name) return;
    final descriptor = snapshot.media.firstWhere((m) => m.ref == ref);
    await _media.record(
      mediaId: ref.mediaId,
      version: ref.version,
      role: role,
      localPath: held?.localPath ?? localPath,
      byteSize: descriptor.byteSize,
      state: snapshot.unavailableMedia.contains(ref)
          ? MediaVersionState.missing
          : MediaVersionState.pendingDownload,
    );
  }

  /// The version of the audio file the row points at, when it is known.
  Future<MediaRef?> _localAudio(ArtworkEntity row) async {
    final path = row.relativeAudioPath;
    if (path == null) return null;
    final entry =
        await (_db.select(_db.mediaVersionsTable)
              ..where(
                (t) =>
                    t.localPath.equals(path) &
                    t.role.equals(MediaRole.audio.name),
              )
              ..limit(1))
            .getSingleOrNull();
    return entry == null
        ? null
        : MediaRef(mediaId: entry.mediaId, version: entry.version);
  }

  // -------------------------------------------------------------------------
  // Shared
  // -------------------------------------------------------------------------

  /// The journal shows an operation of this device applied remotely while
  /// its answer has not arrived: the change acknowledges it, as the receipt
  /// would have. A replay would only return that old receipt, and a later
  /// remote change of the same field, met meanwhile as a conflict with the
  /// operation, would then never be applied here.
  Future<void> _acknowledgeEcho(SyncChange change) async {
    final opId = change.opId;
    if (opId == null) return;
    final ops = await _outbox.operationsOf(
      SyncEntityKind.of(change.entityType),
      change.entityId,
    );
    final entry = ops.where((op) => op.opId == opId).firstOrNull;
    final patch = entry?.patch;
    if (entry == null || !entry.isInFlight || patch == null) return;
    final snapshot = change.snapshot;
    // A purge goes through the trash first; the purge itself is its echo.
    if (snapshot != null &&
        patch.fields[_LocalOps._lifecycle] == SyncLifecycle.purged.name) {
      return;
    }
    await _receipts.apply(
      entry: entry,
      patch: patch,
      receipt: _echoReceipt(patch, snapshot),
    );
  }

  /// The receipt [patch] got remotely, read from the state right after it
  /// ([snapshot], null for a purge): a field that holds the patch value was
  /// accepted, any other one lost a conflict.
  static MutationReceipt _echoReceipt(
    EntityPatch patch,
    EntitySnapshot? snapshot,
  ) {
    final accepted = <String, int>{};
    final conflicts = <FieldConflict>[];
    for (final MapEntry(key: field, :value) in patch.fields.entries) {
      final base = patch.baseRevisions[field] ?? 0;
      if (snapshot == null) {
        accepted[field] = base + 1;
        continue;
      }
      final revision = snapshot.revisions[field] ?? 0;
      final remoteValue = snapshot.fields[field];
      if (_sameValue(remoteValue, value)) {
        // Create-only fields may have no revision.
        accepted[field] = math.max(revision, 1);
      } else {
        conflicts.add(
          FieldConflict(
            field: field,
            localValue: value,
            remoteValue: remoteValue,
            baseRevision: base,
            remoteRevision: revision,
            kind:
                patch.entityType == SyncEntityType.artwork &&
                    field == ArtworkSyncFields.audio
                ? FieldConflictKind.audio
                : FieldConflictKind.field,
          ),
        );
      }
    }
    return MutationReceipt(
      opId: patch.opId,
      accepted: accepted,
      conflicts: conflicts,
    );
  }

  /// JSON values compared whatever the order of their keys (a media
  /// reference read back from the remote side may list them differently).
  static bool _sameValue(Object? a, Object? b) =>
      jsonEncode(_canonical(a)) == jsonEncode(_canonical(b));

  static Object? _canonical(Object? value) => switch (value) {
    final Map<dynamic, dynamic> map => {
      for (final key in map.keys.map((k) => '$k').toList()..sort())
        key: _canonical(map[key]),
    },
    final List<dynamic> list => [for (final item in list) _canonical(item)],
    _ => value,
  };

  /// True when [field] takes the remote value.
  ///
  /// Without a local operation on the field, the remote value is applied
  /// unless its revision is older than the local one. That happens while a
  /// newer change of the field is still to be read (an acknowledgement
  /// arrived first), or when the remote history went back (a restore): the
  /// value is held in `older_remote_values` and settled when the read ends
  /// ([_settleOlder]). The same revision with another value can only come
  /// from a remote history that went back: the local value goes to
  /// `replaced_values`.
  ///
  /// With a local operation on the field, the local value stays and the
  /// remote one is kept in `replaced_values`, unless this device already
  /// knows it.
  Future<bool> _remoteWins(
    SyncChange change,
    _LocalOps local, {
    required String field,
    required int localRev,
    required Object? localValue,
  }) async {
    final snapshot = change.snapshot!;
    final remoteValue = snapshot.fields[field];
    if (!local.changes(field)) {
      final revision = snapshot.revisions[field] ?? 0;
      if (revision < localRev) {
        await _db
            .into(_db.olderRemoteValuesTable)
            .insertOnConflictUpdate(
              OlderRemoteValuesTableCompanion.insert(
                entityId: change.entityId,
                field: field,
                changeJson: jsonEncode(change.toJson()),
              ),
            );
        return false;
      }
      await (_db.delete(_db.olderRemoteValuesTable)..where(
            (t) => t.entityId.equals(change.entityId) & t.field.equals(field),
          ))
          .go();
      if (revision == localRev && localRev > 0) {
        await _keepLocal(change, field, localValue);
      }
      return true;
    }
    final known =
        (snapshot.revisions[field] ?? 0) <= local.baseOf(field, localRev) ||
        _sameValue(remoteValue, local.valueOf(field, localValue));
    if (!known) {
      await _replaced.record(
        entityType: change.entityType,
        entityId: change.entityId,
        field: field,
        value: remoteValue,
        mediaRef: field == ArtworkSyncFields.audio && remoteValue != null
            ? MediaRef.fromJson(remoteValue)
            : null,
        source: ReplacedValueSource.remote,
      );
    }
    return false;
  }

  /// The read reached the end of the journal. A remote value still older
  /// than the local revision is the remote state: its history went back (a
  /// restore). It is applied, as any remote value; the local value, which
  /// the remote side lost, is kept in `replaced_values`.
  Future<void> _settleOlder() async {
    final held = await _db.select(_db.olderRemoteValuesTable).get();
    if (held.isEmpty) return;
    await _db.delete(_db.olderRemoteValuesTable).go();
    Log.w(
      '${held.length} valeur(s) distante(s) plus ancienne(s) que la copie '
          'locale : historique distant revenu en arrière',
      'Sync',
    );
    for (final entry in held) {
      final change = SyncChange.fromJson(jsonDecode(entry.changeJson));
      final id = change.entityId;
      final field = entry.field;
      final snapshot = change.snapshot!;
      final kind = SyncEntityKind.of(change.entityType);
      if ((await _LocalOps.read(_outbox, kind, id)).changes(field)) continue;
      switch (change.entityType) {
        case SyncEntityType.child:
          final row = await _child(id);
          if (row == null) continue;
          await _keepLocal(change, field, _childLocal(row, field).$2);
          await _setChild(id, _childRemote(field, snapshot));
        case SyncEntityType.artwork:
          final row = await _artwork(id);
          if (row == null) continue;
          final localAudio = await _localAudio(row);
          await _keepLocal(
            change,
            field,
            _artworkLocal(row, field, localAudio).$2,
          );
          await _setArtwork(
            id,
            await _artworkRemote(id, field, snapshot, localAudio),
          );
      }
    }
  }

  /// Keeps [localValue] of [field] in `replaced_values` before the remote
  /// value of [change] replaces it. An audio without a known local version
  /// has nothing on this device to keep.
  Future<void> _keepLocal(
    SyncChange change,
    String field,
    Object? localValue,
  ) async {
    if (_sameValue(change.snapshot!.fields[field], localValue)) return;
    final audio = field == ArtworkSyncFields.audio;
    if (audio && localValue == null) return;
    await _replaced.record(
      entityType: change.entityType,
      entityId: change.entityId,
      field: field,
      value: localValue,
      mediaRef: audio ? MediaRef.fromJson(localValue) : null,
      source: ReplacedValueSource.local,
    );
  }

  Future<ChildEntity?> _child(String id) => (_db.select(
    _db.childrenTable,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<ArtworkEntity?> _artwork(String id) => (_db.select(
    _db.artworksTable,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<MediaVersionEntity?> _version(MediaRef ref, MediaRole role) =>
      (_db.select(_db.mediaVersionsTable)..where(
            (t) =>
                t.mediaId.equals(ref.mediaId) &
                t.version.equals(ref.version) &
                t.role.equals(role.name),
          ))
          .getSingleOrNull();

  Future<void> _setChild(String id, ChildrenTableCompanion companion) async {
    if (companion.toColumns(false).isEmpty) return;
    await (_db.update(
      _db.childrenTable,
    )..where((t) => t.id.equals(id))).write(companion);
  }

  Future<void> _setArtwork(String id, ArtworksTableCompanion companion) async {
    if (companion.toColumns(false).isEmpty) return;
    await (_db.update(
      _db.artworksTable,
    )..where((t) => t.id.equals(id))).write(companion);
  }
}

/// What the local operations of one entity still change.
class _LocalOps {
  final Set<String> opIds;

  /// Highest base revision per field named in an operation's patch.
  final Map<String, int> bases;

  /// Latest value per field named in an operation's patch.
  final Map<String, Object?> values;

  /// An operation without a patch reads the whole row when it is sent.
  final bool wholeRow;

  /// Lifecycle the latest lifecycle operation asks for.
  final String? lifecycle;

  const _LocalOps(
    this.opIds,
    this.bases,
    this.values,
    this.wholeRow,
    this.lifecycle,
  );

  static const _lifecycle = 'lifecycle';

  static Future<_LocalOps> read(
    SyncOutboxRepository outbox,
    SyncEntityKind entity,
    String id,
  ) async {
    final opIds = <String>{};
    final bases = <String, int>{};
    final values = <String, Object?>{};
    var wholeRow = false;
    String? lifecycle;
    for (final op in await outbox.operationsOf(entity, id)) {
      opIds.add(op.opId);
      final patch = op.patch;
      if (patch == null) {
        if (op.op == SyncOutboxOp.delete.wireName) {
          lifecycle = SyncLifecycle.purged.name;
        } else {
          wholeRow = true;
        }
        continue;
      }
      for (final MapEntry(key: field, :value) in patch.fields.entries) {
        bases[field] = math.max(
          bases[field] ?? 0,
          patch.baseRevisions[field] ?? 0,
        );
        values[field] = value;
        if (field == _lifecycle) lifecycle = value as String;
      }
    }
    return _LocalOps(opIds, bases, values, wholeRow, lifecycle);
  }

  bool get isEmpty => opIds.isEmpty;

  /// A local trash or deletion is waiting to be sent.
  bool get removes =>
      lifecycle != null && lifecycle != SyncLifecycle.active.name;

  bool changes(String field) =>
      bases.containsKey(field) || (wholeRow && field != _lifecycle);

  int baseOf(String field, int rowRevision) =>
      math.max(rowRevision, bases[field] ?? 0);

  Object? valueOf(String field, Object? rowValue) =>
      values.containsKey(field) ? values[field] : rowValue;
}
