// Change journal pull (L07): the device reads the ordered journal page by
// page, never loses an incoming change, and never lets one overwrite a local
// edit that is still waiting to be sent.

import 'dart:io';

import 'package:artkiddo_core/artkiddo_core.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'operation_sync_test.dart' show FakeProtocolBackend, Node;
import 'sync_engine_test.dart' show makeTestImage;

const _uuid = Uuid();

MediaDescriptor _photo(String mediaId) => MediaDescriptor(
  mediaId: mediaId,
  version: 1,
  role: MediaRole.optimized,
  format: MediaFormat.jpeg,
  byteSize: 1000,
  sha256: 'a' * 64,
  widthPx: 800,
  heightPx: 600,
);

MediaDescriptor _voice(String mediaId, int version) => MediaDescriptor(
  mediaId: mediaId,
  version: version,
  role: MediaRole.audio,
  format: MediaFormat.m4a,
  byteSize: 2000 + version,
  sha256: 'b' * 64,
  durationMs: 1500 * version,
);

void main() {
  late FakeProtocolBackend backend;
  late Node node;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() async {
    backend = FakeProtocolBackend();
    node = await Node.create(backend);
  });

  tearDown(() => node.close());

  String remoteChild([String name = 'Distant']) {
    final id = _uuid.v4();
    backend.remoteCreate(SyncEntityType.child, id, {
      'name': name,
      'birthDate': '2019-03-01',
    });
    return id;
  }

  Map<String, Object?> artworkFields(String childId) => {
    'childId': childId,
    'addedAt': syncInstantValue(DateTime.utc(2026, 1, 1)),
  };

  /// Keeps every queued operation out of the next pushes: they are still
  /// pending when the pull runs.
  Future<void> holdOperations() => node.db
      .update(node.db.syncOutboxTable)
      .write(
        SyncOutboxTableCompanion(
          nextAttemptAt: Value(DateTime.now().add(const Duration(days: 1))),
        ),
      );

  Future<void> releaseOperations() => node.db
      .update(node.db.syncOutboxTable)
      .write(const SyncOutboxTableCompanion(nextAttemptAt: Value(null)));

  Future<ChildEntity?> childRow(String id) => (node.db.select(
    node.db.childrenTable,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<ArtworkEntity?> artworkRow(String id) => (node.db.select(
    node.db.artworksTable,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<String> localArtwork(String childId) async {
    final source = await makeTestImage(node.root, 'src.jpg');
    return (await node.artworks.create(
              childId: childId,
              sourceImageFile: source,
              addedAt: DateTime(2026, 1, 1),
            )
            as ActionSuccess<String>)
        .value;
  }

  group('reading', () {
    test('a new device reads more than 1 000 changes from the beginning, '
        'page by page', () async {
      for (var i = 0; i < 1050; i++) {
        remoteChild('Enfant $i');
      }

      final summary = await node.sync();

      expect(summary.pulledChildren, 1050);
      expect(await node.children.count(), 1050);
      expect(backend.pulledAfter, [null, '200', '400', '600', '800', '1000']);
      expect(
        await VaultMetaRepository(node.db).getChangeCursor(),
        ChangeCursor(value: '1050', generation: 1),
      );

      final again = await node.sync();

      expect(again.pulledChildren, 0);
      expect(backend.pulledAfter.last, '1050');
    });

    test('a crash between two pages resumes after the last applied page, '
        'without a gap', () async {
      backend.pageSize = 2;
      for (var i = 0; i < 5; i++) {
        remoteChild('Enfant $i');
      }
      backend.onPageServed = (index) {
        if (index == 1) backend.failNextPull = const SocketException('kill');
      };

      await expectLater(node.sync(), throwsA(isA<SocketException>()));
      await node.restart();

      expect(await node.children.count(), 4, reason: 'two whole pages');
      expect(backend.pulledAfter, [null, '2', '4']);

      await node.sync();

      expect(backend.pulledAfter.skip(3).first, '4');
      expect(await node.children.count(), 5);
    });

    test('a page that cannot be written is not applied at all and is read '
        'again', () async {
      remoteChild('Correct');
      remoteChild('x' * 101); // longer than the local column allows

      final summary = await node.sync();

      expect(summary.lastError, isA<LocalWriteFailure>());
      expect(await node.children.count(), 0, reason: 'one transaction');
      expect(await VaultMetaRepository(node.db).getChangeCursor(), isNull);

      await node.sync();

      expect(backend.pulledAfter, [null, null]);
    });

    test('without a session nothing is read', () async {
      remoteChild();
      node.engine = node.newEngine(currentUserId: () => null);

      await node.sync();

      expect(backend.pulledAfter, isEmpty);
      expect(await node.children.count(), 0);
    });
  });

  group('incoming change against a pending local operation', () {
    test('a field no operation changes takes the remote value and revision; '
        'the local one stays queued', () async {
      final id = await node.newChild();
      await node.sync();
      backend.remoteEdit(SyncEntityType.child, id, 'birthDate', '2018-02-02');
      await node.children.update(
        id: id,
        name: 'Local',
        birthDate: DateTime(2019, 3, 1),
      );
      await holdOperations();

      await node.sync();

      final row = (await childRow(id))!;
      expect(row.name, 'Local');
      expect(row.birthDate, DateTime(2018, 2, 2));
      expect((row.nameRev, row.birthDateRev, row.lifecycleRev), (1, 2, 1));
      expect((await node.ops(id)).single.patch!.fields, {'name': 'Local'});
      expect(await node.engine.replacedValues.listReplacedValues(id), isEmpty);
    });

    test('the same field keeps the local value and records the remote one, '
        'once', () async {
      final id = await node.newChild();
      await node.sync();
      backend.remoteEdit(SyncEntityType.child, id, 'name', 'Distant');
      await node.children.update(
        id: id,
        name: 'Local',
        birthDate: DateTime(2019, 3, 1),
      );
      await holdOperations();

      await node.sync();

      expect((await childRow(id))!.name, 'Local');
      var history = await node.engine.replacedValues.listReplacedValues(id);
      expect(history.single.value, 'Distant');
      expect(history.single.source, ReplacedValueSource.remote);
      expect(await node.ops(id), hasLength(1));

      await releaseOperations();
      await node.sync(); // conflict: the local value is sent again
      await node.sync();

      expect(backend.entity(SyncEntityType.child, id)!.values['name'], 'Local');
      expect((await childRow(id))!.name, 'Local');
      expect(await node.ops(id), isEmpty);
      history = await node.engine.replacedValues.listReplacedValues(id);
      expect(history, hasLength(1), reason: 'met twice, kept once');
    });

    test('the echo of an own operation whose answer was lost is not a '
        'replaced value', () async {
      final id = await node.newChild();
      await node.sync();
      await node.children.update(
        id: id,
        name: 'Nouveau',
        birthDate: DateTime(2019, 3, 1),
      );
      // Applied remotely; the device edits again, then the answer is lost.
      backend.beforeReply = (_) async {
        backend.beforeReply = null;
        await node.children.update(
          id: id,
          name: 'Encore',
          birthDate: DateTime(2019, 3, 1),
        );
      };
      backend.loseNextResponse = true;

      await node.sync();

      expect((await childRow(id))!.name, 'Encore');
      // The echo acknowledged the first operation; the second one now
      // builds on the revision it produced.
      final ops = await node.ops(id);
      expect(ops.single.patch!.fields, {'name': 'Encore'});
      expect(ops.single.patch!.baseRevisions, {'name': 2});
      expect(await node.engine.replacedValues.listReplacedValues(id), isEmpty);

      await releaseOperations();
      await node.sync();
      await node.sync();

      expect(
        backend.entity(SyncEntityType.child, id)!.values['name'],
        'Encore',
      );
      expect(await node.ops(id), isEmpty);
      expect(await node.engine.replacedValues.listReplacedValues(id), isEmpty);
    });

    test('the echo of an own operation acknowledges it: a later remote edit '
        'of the same field wins, as it does remotely', () async {
      final id = await node.newChild();
      await node.sync();
      await node.children.update(
        id: id,
        name: 'Ici',
        birthDate: DateTime(2019, 3, 1),
      );
      // Applied remotely, renamed elsewhere right after; the answer is lost.
      backend.beforeReply = (_) async {
        backend.beforeReply = null;
        backend.remoteEdit(SyncEntityType.child, id, 'name', 'Ailleurs');
      };
      backend.loseNextResponse = true;

      await node.sync();
      await releaseOperations();
      await node.sync();

      expect(
        backend.entity(SyncEntityType.child, id)!.values['name'],
        'Ailleurs',
      );
      final row = (await childRow(id))!;
      expect((row.name, row.nameRev, row.syncState), ('Ailleurs', 3, 'synced'));
      expect(await node.ops(id), isEmpty);
      expect(backend.received, hasLength(2), reason: 'never replayed');
    });

    test('the echo of an own operation that lost a field remotely keeps the '
        'local value and sends it again', () async {
      final id = await node.newChild();
      await node.sync();
      await node.children.update(
        id: id,
        name: 'Ici',
        birthDate: DateTime(2017, 7, 7),
      );
      // Renamed elsewhere first: the birth date is accepted, the name is in
      // conflict; then the answer is lost.
      final pending = (await node.ops(id)).single.opId;
      backend.remoteEdit(SyncEntityType.child, id, 'name', 'Ailleurs');
      backend.loseNextResponse = true;

      await node.sync();

      var row = (await childRow(id))!;
      expect((row.name, row.birthDate), ('Ici', DateTime(2017, 7, 7)));
      expect(row.birthDateRev, 2);
      final ops = await node.ops(id);
      expect(ops.single.opId, isNot(pending), reason: 'acknowledged by echo');
      expect(ops.single.patch!.fields, {'name': 'Ici'});
      expect(ops.single.patch!.baseRevisions, {'name': 2});
      final history = await node.engine.replacedValues.listReplacedValues(id);
      expect(history.single.value, 'Ailleurs');

      await node.sync();

      expect(backend.entity(SyncEntityType.child, id)!.values['name'], 'Ici');
      row = (await childRow(id))!;
      expect((row.name, row.nameRev), ('Ici', 3));
      expect(await node.ops(id), isEmpty);
    });

    test('a child deleted here is not brought back by a remote edit', () async {
      final id = await node.newChild();
      await node.sync();
      backend.remoteEdit(SyncEntityType.child, id, 'name', 'Distant');
      await node.children.delete(id);
      await holdOperations();

      await node.sync();

      expect(await childRow(id), isNull);
      expect((await node.ops(id)).single.patch!.fields, {
        'lifecycle': 'purged',
      });
    });
  });

  group('trash and purge', () {
    test('a remote trash then purge keep the original and the pending '
        'operation', () async {
      final childId = await node.newChild();
      await node.sync();
      final id = await localArtwork(childId);
      await node.artworks.updateStory(id: id, story: 'Local');
      // The remote side knows the artwork (its upload is L08's job).
      backend.remoteCreate(SyncEntityType.artwork, id, artworkFields(childId));
      backend.remoteLifecycle(SyncEntityType.artwork, id, 'trashed');

      await node.sync();

      var row = (await artworkRow(id))!;
      expect(row.deletedAt, isNotNull);
      expect(row.story, 'Local');
      final original = await node.vault.resolveFile(row.relativeImagePath!);
      expect(await original.exists(), isTrue);
      final ops = await node.outbox.operationsOf(SyncEntityKind.artwork, id);
      expect(ops, hasLength(1));

      backend.remoteLifecycle(SyncEntityType.artwork, id, 'purged');
      await node.sync();

      row = (await artworkRow(id))!;
      expect(row.deletedAt, isNotNull);
      expect(row.remotePurgedAt, isNotNull);
      expect(await original.exists(), isTrue);
      expect(
        await node.outbox.operationsOf(SyncEntityKind.artwork, id),
        hasLength(1),
      );
    });

    test('an artwork kept here after a remote purge is marked as existing '
        'here only, until the remote side has it again', () async {
      final childId = await node.newChild();
      await node.sync();
      final id = await localArtwork(childId);
      backend.remoteCreate(SyncEntityType.artwork, id, artworkFields(childId));
      backend.remoteLifecycle(SyncEntityType.artwork, id, 'trashed');
      await node.sync();
      expect((await artworkRow(id))!.remotePurgedAt, isNull, reason: 'trash');

      backend.remoteLifecycle(SyncEntityType.artwork, id, 'purged');
      await node.sync();

      final row = (await artworkRow(id))!;
      expect(row.deletedAt, isNotNull);
      expect(row.remotePurgedAt, isNotNull);
      final original = await node.vault.resolveFile(row.relativeImagePath!);
      expect(await original.exists(), isTrue);

      // The remote history is restored to before the purge.
      final remote = backend.entity(SyncEntityType.artwork, id)!
        ..lifecycle = 'trashed';
      backend.commit(remote, from: 'purged');
      await node.sync();

      expect((await artworkRow(id))!.remotePurgedAt, isNull);
    });

    test(
      'a new device keeps nothing of what was purged before it joined',
      () async {
        final childId = remoteChild();
        final purged = _uuid.v4();
        final photo = _photo(_uuid.v4());
        backend.remoteCreate(
          SyncEntityType.artwork,
          purged,
          {...artworkFields(childId), 'photo': photo.ref.toJson()},
          media: [photo],
        );
        backend.remoteLifecycle(SyncEntityType.artwork, purged, 'trashed');
        backend.remoteLifecycle(SyncEntityType.artwork, purged, 'purged');
        // A child purged with its artwork, which leaves the trash later.
        final goneChild = remoteChild('Parti');
        final orphan = _uuid.v4();
        backend.remoteCreate(
          SyncEntityType.artwork,
          orphan,
          artworkFields(goneChild),
        );
        backend.remoteLifecycle(SyncEntityType.child, goneChild, 'purged');
        backend.remoteLifecycle(SyncEntityType.artwork, orphan, 'purged');

        await node.sync();

        expect(await artworkRow(purged), isNull);
        expect(await artworkRow(orphan), isNull);
        expect(await childRow(goneChild), isNull);
        expect(await childRow(childId), isNotNull);
        expect(
          await MediaVersionsRepository(node.db).versionsOf(photo.mediaId),
          isEmpty,
          reason: 'nothing left to download',
        );
      },
    );

    test('a remote restore takes the artwork out of the local trash', () async {
      final childId = remoteChild();
      final id = _uuid.v4();
      backend.remoteCreate(SyncEntityType.artwork, id, artworkFields(childId));
      backend.remoteLifecycle(SyncEntityType.artwork, id, 'trashed');
      await node.sync();
      expect((await artworkRow(id))!.deletedAt, isNotNull);

      backend.remoteLifecycle(SyncEntityType.artwork, id, 'active');
      await node.sync();

      final row = (await artworkRow(id))!;
      expect(row.deletedAt, isNull);
      expect(row.lifecycleRev, 3);
    });

    test('a remote child purge moves its artworks to the local trash and '
        'hides the child', () async {
      final kept = await node.newChild('Avec dessin');
      final empty = await node.newChild('Sans dessin');
      await node.sync();
      final artworkId = await localArtwork(kept);
      backend.remoteCreate(
        SyncEntityType.artwork,
        artworkId,
        artworkFields(kept),
      );
      backend.remoteLifecycle(SyncEntityType.child, kept, 'purged');
      backend.remoteLifecycle(SyncEntityType.child, empty, 'purged');

      await node.sync();

      expect(await node.children.watchAll().first, isEmpty);
      expect((await childRow(kept))!.deletedAt, isNotNull);
      expect(await childRow(empty), isNull, reason: 'nothing depends on it');
      final artwork = (await artworkRow(artworkId))!;
      expect(artwork.deletedAt, isNotNull);
      final original = await node.vault.resolveFile(artwork.relativeImagePath!);
      expect(await original.exists(), isTrue);
    });
  });

  group('media', () {
    test('a new artwork registers its photo and audio for download', () async {
      final childId = remoteChild();
      final id = _uuid.v4();
      final photo = _photo(_uuid.v4());
      backend.remoteCreate(
        SyncEntityType.artwork,
        id,
        {
          ...artworkFields(childId),
          'photo': photo.ref.toJson(),
          'story': 'Un dragon',
          'audio': _voice(id, 1).ref.toJson(),
        },
        media: [photo, _voice(id, 1)],
      );

      await node.sync();

      var row = (await artworkRow(id))!;
      expect(row.story, 'Un dragon');
      expect(row.displayImagePath, isNull);
      expect(row.relativeAudioPath, isNull, reason: 'not downloaded yet');
      expect(row.audioDurationMs, 1500);
      final media = MediaVersionsRepository(node.db);
      final photoVersion = (await media.versionsOf(photo.mediaId)).single;
      expect(
        (photoVersion.role, photoVersion.state, photoVersion.localPath),
        (
          MediaRole.optimized,
          MediaVersionState.pendingDownload,
          '${LocalVault.derivativesFolder}/${id}_display.jpg',
        ),
      );
      var versions = await media.versionsOf(id);
      expect(versions.map((v) => (v.role, v.version, v.state, v.localPath)), [
        (
          MediaRole.audio,
          1,
          MediaVersionState.pendingDownload,
          'audio/$id/v1.m4a',
        ),
      ]);

      // A new recording elsewhere replaces the version waiting here.
      final unavailable = _voice(id, 2);
      backend
          .entity(SyncEntityType.artwork, id)!
          .unavailable
          .add(unavailable.ref);
      backend.remoteEdit(
        SyncEntityType.artwork,
        id,
        'audio',
        unavailable.ref.toJson(),
        media: [unavailable],
      );
      await node.sync();

      row = (await artworkRow(id))!;
      expect((row.audioDurationMs, row.audioRevision), (3000, 2));
      versions = await media.versionsOf(id);
      expect(
        versions
            .where((v) => v.role == MediaRole.audio)
            .map((v) => (v.version, v.state)),
        [(2, MediaVersionState.missing)],
      );
    });
  });

  test(
    'an artwork served before its child waits for it, across a restart',
    () async {
      backend.pageSize = 1;
      final childId = _uuid.v4();
      final id = _uuid.v4();
      // Out of order on purpose: the artwork reaches the journal first.
      backend.remoteCreate(SyncEntityType.artwork, id, {
        ...artworkFields(childId),
        'story': 'Patient',
      });
      backend.remoteCreate(SyncEntityType.child, childId, {
        'name': 'Parent',
        'birthDate': '2019-03-01',
      });
      backend.onPageServed = (index) {
        if (index == 0) backend.failNextPull = const SocketException('kill');
      };

      await expectLater(node.sync(), throwsA(isA<SocketException>()));
      await node.restart();

      expect(await artworkRow(id), isNull);
      expect(
        await node.db.select(node.db.deferredRemoteChangesTable).get(),
        hasLength(1),
      );

      await node.sync();

      expect((await artworkRow(id))!.story, 'Patient');
      expect(
        await node.db.select(node.db.deferredRemoteChangesTable).get(),
        isEmpty,
      );
    },
  );

  test('a remote history that went back is applied; the local value it lost '
      'is kept in the history of replaced values', () async {
    final id = await node.newChild('Avant');
    await node.sync();
    await node.children.update(
      id: id,
      name: 'Après',
      birthDate: DateTime(2019, 3, 1),
    );
    await node.sync();
    expect((await childRow(id))!.nameRev, 2);
    // The remote side is restored to before the rename.
    final remote = backend.entity(SyncEntityType.child, id)!;
    remote.values['name'] = 'Avant';
    remote.revisions['name'] = 1;
    backend.rebuildHistory();

    await node.sync();

    final row = (await childRow(id))!;
    expect((row.name, row.nameRev), ('Avant', 1));
    final history = await node.engine.replacedValues.listReplacedValues(id);
    expect(history.single.value, 'Après');
    expect(history.single.source, ReplacedValueSource.local);
    expect(await node.db.select(node.db.olderRemoteValuesTable).get(), isEmpty);
  });

  test('an older revision read after a newer acknowledgement is neither '
      'applied nor kept in the history', () async {
    final id = await node.newChild('Un');
    await node.sync();
    await node.children.update(
      id: id,
      name: 'Deux',
      birthDate: DateTime(2019, 3, 1),
    );
    backend.failNextPull = const SocketException('offline');
    await expectLater(node.sync(), throwsA(isA<SocketException>()));
    await node.children.update(
      id: id,
      name: 'Trois',
      birthDate: DateTime(2019, 3, 1),
    );
    backend.pageSize = 1; // the older revision ends a page of its own

    await node.sync();

    final row = (await childRow(id))!;
    expect((row.name, row.nameRev), ('Trois', 3));
    expect(await node.engine.replacedValues.listReplacedValues(id), isEmpty);
    expect(await node.db.select(node.db.olderRemoteValuesTable).get(), isEmpty);
  });

  test('an invalid cursor reads again from the beginning; local data and '
      'pending operations are kept', () async {
    final kept = await node.newChild('Ici');
    final gone = await node.newChild('Disparu');
    await node.sync();
    backend.remoteEdit(SyncEntityType.child, kept, 'birthDate', '2018-02-02');
    await node.children.update(
      id: kept,
      name: 'Local',
      birthDate: DateTime(2019, 3, 1),
    );
    await holdOperations();
    // The remote history is restored without one of the children.
    backend.rebuildHistory(keep: (e) => e.id != gone);

    await node.sync();

    expect(backend.pulledAfter.reversed.take(2), [null, isNotNull]);
    final row = (await childRow(kept))!;
    expect((row.name, row.birthDate), ('Local', DateTime(2018, 2, 2)));
    expect(await node.ops(kept), hasLength(1));
    expect((await childRow(gone))!.name, 'Disparu', reason: 'no purge seen');
    expect(
      (await VaultMetaRepository(node.db).getChangeCursor())!.generation,
      2,
    );
  });
}
