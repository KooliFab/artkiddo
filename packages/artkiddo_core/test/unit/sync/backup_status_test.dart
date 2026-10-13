// Backup statuses: the truth table of `backupStatusFor`, and the facts
// read from real data (artwork row, outbox, vault). INV-06: "saved" needs an
// acknowledged row and nothing queued. INV-07: what waits or fails in the
// outbox is always visible, and the counters agree with the outbox.

import 'package:artkiddo_core/artkiddo_core.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';

import 'operation_sync_test.dart' show FakeProtocolBackend, Node;
import 'sync_engine_test.dart' show makeTestImage;

const _onDevice = ArtworkBackupStatus(ArtworkBackupState.onDevice);
const _inProgress = ArtworkBackupStatus(ArtworkBackupState.inProgress);
const _saved = ArtworkBackupStatus(ArtworkBackupState.saved);
const _missing = ArtworkBackupStatus(
  ArtworkBackupState.actionNeeded,
  reason: ArtworkBackupReason.missingFile,
);
const _failing = ArtworkBackupStatus(
  ArtworkBackupState.actionNeeded,
  reason: ArtworkBackupReason.repeatedFailure,
);
const _onlyHere = ArtworkBackupStatus(
  ArtworkBackupState.onDevice,
  reason: ArtworkBackupReason.remotePurged,
);

void main() {
  group('backupStatusFor', () {
    ArtworkBackupStatus status(
      SyncState syncState, {
      bool remoteBackup = true,
      bool remotePurged = false,
      int pending = 0,
      int attempts = 0,
      bool missingFile = false,
      bool audioPending = false,
      bool audioConflict = false,
    }) => backupStatusFor(
      ArtworkBackupFacts(
        remoteBackup: remoteBackup,
        syncState: syncState,
        remotePurged: remotePurged,
        pendingOperations: pending,
        maxAttempts: attempts,
        missingFile: missingFile,
        audioSyncPending: audioPending,
        audioConflict: audioConflict,
      ),
    );

    test('without an account: on this device, or action needed', () {
      for (final state in SyncState.values) {
        expect(status(state, remoteBackup: false), _onDevice, reason: '$state');
        expect(
          status(state, remoteBackup: false, missingFile: true),
          _missing,
          reason: '$state',
        );
      }
      // Whatever a row says, no account never reads "saved".
      expect(
        status(SyncState.synced, remoteBackup: false, pending: 2),
        _onDevice,
      );
    });

    test('a missing file always asks for an action', () {
      expect(status(SyncState.synced, missingFile: true), _missing);
      expect(
        status(SyncState.localOnly, pending: 1, missingFile: true),
        _missing,
      );
      expect(
        status(SyncState.synced, remotePurged: true, missingFile: true),
        _missing,
      );
    });

    test('saved needs an acknowledged row and nothing queued (INV-06)', () {
      expect(status(SyncState.synced), _saved);
      // Known through the server: its media were verified there.
      expect(status(SyncState.remoteThumbnail), _saved);
      expect(status(SyncState.synced, pending: 1), _inProgress);
      expect(status(SyncState.remoteThumbnail, pending: 1), _inProgress);
      // Voice not confirmed by the server: not saved.
      expect(status(SyncState.synced, audioPending: true), _onDevice);
      expect(status(SyncState.synced, audioConflict: true), _onDevice);
      expect(
        status(SyncState.synced, audioPending: true, pending: 1),
        _inProgress,
      );
    });

    test('a queued operation is in progress, never saved (INV-07)', () {
      for (final state in [
        SyncState.localOnly,
        SyncState.pendingUpload,
        SyncState.syncError,
        SyncState.synced,
      ]) {
        expect(status(state, pending: 1), _inProgress, reason: '$state');
        expect(
          status(state, pending: 3, attempts: repeatedFailureAttempts - 1),
          _inProgress,
          reason: '$state, failing but retried',
        );
      }
    });

    test('repeated failure, or a download that gave up, asks for action', () {
      expect(status(SyncState.syncError, pending: 1, attempts: 3), _failing);
      expect(status(SyncState.synced, pending: 1, attempts: 7), _failing);
      expect(status(SyncState.downloadFailed), _failing);
    });

    test('nothing queued and not acknowledged: on this device', () {
      for (final state in [
        SyncState.localOnly,
        SyncState.pendingUpload,
        SyncState.syncError,
      ]) {
        expect(status(state), _onDevice, reason: '$state');
      }
    });

    test('purged remotely, kept here: never saved nor in progress', () {
      for (final state in SyncState.values) {
        expect(status(state, remotePurged: true), _onlyHere, reason: '$state');
        expect(
          status(state, remotePurged: true, pending: 2),
          _onlyHere,
          reason: '$state with an operation',
        );
      }
    });

    test('BackupSummary counts each state once', () {
      final summary = BackupSummary.of([
        _saved,
        _saved,
        _inProgress,
        _failing,
        _missing,
        _onlyHere,
        _onDevice,
      ]);
      expect(summary.saved, 2);
      expect(summary.inProgress, 1);
      expect(summary.actionNeeded, 2);
      expect(summary.onDevice, 2);
      expect(summary.total, 7);
    });
  });

  group('statuses read from the data', () {
    late FakeProtocolBackend backend;
    late Node node;
    late BackupStatusRepository repo;
    late LocalTrashRepository trash;
    final now = DateTime.now();

    setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

    setUp(() async {
      backend = FakeProtocolBackend();
      node = await Node.create(backend);
      repo = BackupStatusRepository(node.db, node.vault);
      trash = LocalTrashRepository(node.db, node.vault, now: () => now);
    });

    tearDown(() => node.close());

    Future<String> newArtwork(String childId, {int seed = 0}) async {
      final source = await makeTestImage(node.root, 'src$seed.jpg', seed: seed);
      return (await node.artworks.create(
                childId: childId,
                sourceImageFile: source,
                addedAt: DateTime(2026, 1, 1),
              )
              as ActionSuccess<String>)
          .value;
    }

    Future<void> acknowledge(String id) async {
      await (node.db.delete(
        node.db.syncOutboxTable,
      )..where((t) => t.entityId.equals(id))).go();
      await (node.db.update(node.db.artworksTable)
            ..where((t) => t.id.equals(id)))
          .write(const ArtworksTableCompanion(syncState: Value('synced')));
    }

    Future<ArtworkEntity> row(String id) => (node.db.select(
      node.db.artworksTable,
    )..where((t) => t.id.equals(id))).getSingle();

    Future<ArtworkBackupStatus?> statusOf(
      String id, {
      bool remoteBackup = true,
    }) async => (await repo.statuses(remoteBackup: remoteBackup))[id];

    test('no account: on this device; the file gone, action needed, and the '
        'artwork is still listed with its other files', () async {
      final id = await newArtwork(await node.newChild());
      expect(await statusOf(id, remoteBackup: false), _onDevice);

      final entity = await row(id);
      final original = await node.vault.resolveFile(entity.relativeImagePath!);
      await original.delete();

      expect(await statusOf(id, remoteBackup: false), _missing);
      // Never a deletion: the row, the other files and the queue stay.
      expect(await node.artworks.getById(id), isNotNull);
      expect(
        await (await node.vault.resolveFile(
          entity.thumbnailImagePath!,
        )).exists(),
        isTrue,
      );
      expect(
        await node.outbox.operationsOf(SyncEntityKind.artwork, id),
        isNotEmpty,
      );
      expect((await node.artworks.watch().first).map((a) => a.id), [id]);
    });

    test('a file back on disk clears the action', () async {
      final id = await newArtwork(await node.newChild());
      final entity = await row(id);
      final original = await node.vault.resolveFile(entity.relativeImagePath!);
      final bytes = await original.readAsBytes();
      await original.delete();
      expect(await statusOf(id), _missing);

      await original.writeAsBytes(bytes);
      expect(await statusOf(id), _inProgress);
    });

    test('with an account: queued is in progress, acknowledged is saved, a '
        'later edit is in progress again', () async {
      final id = await newArtwork(await node.newChild());
      expect(
        await node.outbox.operationsOf(SyncEntityKind.artwork, id),
        isNotEmpty,
      );
      expect(await statusOf(id), _inProgress);

      await acknowledge(id);
      expect(await statusOf(id), _saved);

      await node.artworks.updateStory(id: id, story: 'Un chat');
      expect(await statusOf(id), _inProgress);
    });

    test('an operation that failed three times asks for an action; one or two '
        'failures stay in progress', () async {
      final id = await newArtwork(await node.newChild());
      final op = (await node.outbox.operationsOf(
        SyncEntityKind.artwork,
        id,
      )).single;

      await node.outbox.markFailed(op.seq, error: 'boom');
      await node.outbox.markFailed(op.seq, error: 'boom');
      expect(await statusOf(id), _inProgress);

      await node.outbox.markFailed(op.seq, error: 'boom');
      expect(await statusOf(id), _failing);
    });

    test('a trashed artwork has no status', () async {
      final id = await newArtwork(await node.newChild());
      await node.artworks.delete(id);
      expect(await statusOf(id), isNull);
    });

    test('purged remotely, then restored here: never saved, whatever the '
        'row says', () async {
      final child = await node.newChild();
      final id = await newArtwork(child);
      await node.db.delete(node.db.syncOutboxTable).go();
      await (node.db.update(
        node.db.artworksTable,
      )..where((t) => t.id.equals(id))).write(
        ArtworksTableCompanion(
          deletedAt: Value(now),
          remotePurgedAt: Value(now),
          syncState: const Value('synced'),
        ),
      );

      expect(await trash.restore(id), isA<ActionSuccess<void>>());
      expect(await statusOf(id), _onlyHere);

      // Even a row wrongly written back as acknowledged stays "on this
      // device": the purge mark decides.
      await acknowledge(id);
      expect(await statusOf(id), _onlyHere);
      expect(await statusOf(id), isNot(_saved));
    });

    test('purged with its child, restored here: on this device', () async {
      final child = await node.newChild();
      final id = await newArtwork(child);
      await node.db.delete(node.db.syncOutboxTable).go();
      await (node.db.update(
        node.db.artworksTable,
      )..where((t) => t.id.equals(id))).write(
        ArtworksTableCompanion(
          deletedAt: Value(now),
          syncState: const Value('synced'),
        ),
      );
      await (node.db.update(node.db.childrenTable)
            ..where((t) => t.id.equals(child)))
          .write(ChildrenTableCompanion(deletedAt: Value(now)));

      await trash.restore(id);

      expect(await statusOf(id), _onlyHere);
    });

    test('the counters agree with the outbox and with the unsaved count '
        '(INV-07)', () async {
      final child = await node.newChild();
      final queued = await newArtwork(child, seed: 1);
      final saved = await newArtwork(child, seed: 2);
      final editedAfterSave = await newArtwork(child, seed: 3);
      final failing = await newArtwork(child, seed: 4);
      final knownFromServer = await newArtwork(child, seed: 5);
      final localOnly = await newArtwork(child, seed: 6);
      await acknowledge(saved);
      await acknowledge(editedAfterSave);
      await node.artworks.updateStory(id: editedAfterSave, story: 'Edit');
      await acknowledge(knownFromServer);
      await (node.db.update(
        node.db.artworksTable,
      )..where((t) => t.id.equals(knownFromServer))).write(
        const ArtworksTableCompanion(syncState: Value('remoteThumbnail')),
      );
      await (node.db.delete(
        node.db.syncOutboxTable,
      )..where((t) => t.entityId.equals(localOnly))).go();
      for (var i = 0; i < repeatedFailureAttempts; i++) {
        for (final op in await node.outbox.operationsOf(
          SyncEntityKind.artwork,
          failing,
        )) {
          await node.outbox.markFailed(op.seq, error: 'boom');
        }
      }

      final statuses = await repo.statuses(remoteBackup: true);
      expect(statuses[queued], _inProgress);
      expect(statuses[saved], _saved);
      expect(statuses[editedAfterSave], _inProgress);
      expect(statuses[failing], _failing);
      expect(statuses[knownFromServer], _saved);
      expect(statuses[localOnly], _onDevice);

      // Every artwork with an operation in the outbox is visibly not saved.
      for (final entry in statuses.entries) {
        final ops = await node.outbox.operationsOf(
          SyncEntityKind.artwork,
          entry.key,
        );
        if (ops.isNotEmpty) {
          expect(entry.value, isNot(_saved), reason: entry.key);
        }
      }

      final summary = BackupSummary.of(statuses.values);
      expect(
        await countUnsavedArtworks(node.db),
        summary.total - summary.saved,
      );
    });

    test('a file missing from a pulled artwork is not an error when no path '
        'points at it', () async {
      final id = await newArtwork(await node.newChild());
      await acknowledge(id);
      // A row known through the server whose derivatives are not downloaded
      // yet has no path at all.
      await (node.db.update(
        node.db.artworksTable,
      )..where((t) => t.id.equals(id))).write(
        const ArtworksTableCompanion(
          relativeImagePath: Value(null),
          displayImagePath: Value(null),
          thumbnailImagePath: Value(null),
          syncState: Value('remoteThumbnail'),
        ),
      );
      expect(await statusOf(id), _saved);
    });

    test('the status stream follows the outbox', () async {
      final id = await newArtwork(await node.newChild());
      final seen = <ArtworkBackupStatus?>[];
      final sub = repo
          .watchStatuses(remoteBackup: true)
          .listen((all) => seen.add(all[id]));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      await acknowledge(id);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await sub.cancel();

      expect(seen.first, _inProgress);
      expect(seen.last, _saved);
    });
  });
}
