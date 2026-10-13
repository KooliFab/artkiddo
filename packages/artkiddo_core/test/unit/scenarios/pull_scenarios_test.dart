// Scenarios S11–S16: reading the remote journal. A device that reads page
// by page, is killed between pages, meets a write that lands between two
// pages, a journal that was rebuilt, or an artwork served before its child
// never misses a row and never loses what it holds locally.

import 'dart:io';

import 'package:artkiddo_core/artkiddo_core.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';

import '../sync/operation_sync_test.dart' show Node;
import 'scenario_harness.dart';

String _id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

void main() {
  late World world;
  late ScenarioBackend backend;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() {
    world = World();
    backend = world.backend;
  });

  tearDown(() => world.dispose());

  /// What the remote side says every active child is called.
  Map<String, String> serverChildren() => {
    for (final e in backend.entities.values)
      if (e.type == SyncEntityType.child && !e.purged)
        e.id: '${e.values['name']}|${e.values['birthDate']}',
  };

  group('a long journal', () {
    test('S11 a new device reads more than 1 000 changes, 1 250 here, with '
        'nothing missing and nothing read twice (INV-12)', () async {
      for (var i = 0; i < 1250; i++) {
        remoteChild(backend, _id(i), 'Enfant $i');
      }
      final fresh = await world.device();

      final summary = await fresh.sync();

      expect(summary.pulledChildren, 1250);
      expect(await fresh.childrenView(), serverChildren());
      expect(backend.pulledAfter, [
        null, '200', '400', '600', '800', '1000', '1200', //
      ]);
      final again = await fresh.sync();
      expect(again.pulledChildren, 0);
      expect(backend.pulledAfter.last, '1250');
    });

    test('S11b pages of one change each, with several entities changed '
        'several times, end on the same state (INV-12)', () async {
      backend.pageSize = 1;
      for (var i = 0; i < 12; i++) {
        remoteChild(backend, _id(i), 'Enfant $i');
      }
      for (var i = 0; i < 12; i += 3) {
        backend.remoteEdit(SyncEntityType.child, _id(i), 'name', 'Renommé $i');
      }
      final fresh = await world.device();

      await fresh.sync();

      expect(await fresh.childrenView(), serverChildren());
      expect(
        backend.pulledAfter,
        hasLength(16),
        reason: '16 changes, 1 a page',
      );
    });
  });

  group('writes during a read', () {
    test('S12 a child created and a child renamed while the device is between '
        'two pages both arrive (INV-12)', () async {
      backend.pageSize = 2;
      for (var i = 0; i < 6; i++) {
        remoteChild(backend, _id(i), 'Enfant $i');
      }
      backend.onPageServed = (index) {
        if (index != 0) return;
        // The first page is out: its two children were already read.
        remoteChild(backend, _id(100), 'Arrivé pendant la lecture');
        backend.remoteEdit(
          SyncEntityType.child,
          _id(0),
          'name',
          'Renommé pendant la lecture',
        );
      };
      final fresh = await world.device();

      await fresh.sync();
      await world.settle([fresh]);

      expect(await fresh.childrenView(), serverChildren());
      expect(await fresh.childrenView(), hasLength(7));
      expect(
        (await fresh.childRow(_id(0)))!.name,
        'Renommé pendant la lecture',
      );
    });

    test('S13 a kill at every page boundary resumes without a gap or a '
        'duplicate (INV-08, INV-12)', () async {
      backend.pageSize = 2;
      for (var i = 0; i < 7; i++) {
        remoteChild(backend, _id(i), 'Enfant $i');
      }
      final pages = 4;
      for (var killAfter = 0; killAfter < pages - 1; killAfter++) {
        final device = await world.device();
        final reads = backend.pulledAfter.length;
        backend.onPageServed = (_) {
          if (backend.pulledAfter.length - reads == killAfter + 1) {
            backend.failNextPull = const SocketException('killed');
          }
        };

        await expectLater(device.sync(), throwsA(isA<SocketException>()));
        backend.onPageServed = null;
        await device.restart();
        expect(
          (await device.childrenView()).length,
          (killAfter + 1) * 2,
          reason: 'only whole pages are applied (kill after page $killAfter)',
        );

        await world.settle([device]);

        expect(
          await device.childrenView(),
          serverChildren(),
          reason: 'kill after page $killAfter',
        );
      }
    });
  });

  group('a journal that changed under the device', () {
    test('S14 a refused cursor with an operation waiting and a local file: '
        'everything is read again, nothing local is lost or erased '
        '(INV-02, INV-03, INV-04)', () async {
      final a = await world.device();
      final kept = await a.newChild('Ici');
      final gone = await a.newChild('Disparu');
      final artwork = await a.newLocalArtwork(kept, seed: 4);
      await a.sync();
      final before = await a.vaultBytes();
      expect(before, isNotEmpty, reason: 'the original photo is on disk');
      backend.remoteEdit(SyncEntityType.child, kept, 'birthDate', '2018-02-02');
      await a.children.update(
        id: kept,
        name: 'Local',
        birthDate: DateTime(2019, 3, 1),
      );
      await a.holdOperations();
      // The remote history is rebuilt (a restore) without one child.
      backend.rebuildHistory(keep: (e) => e.id != gone);

      await a.sync();

      expect(backend.pulledAfter.reversed.take(2), [null, isNotNull]);
      final row = (await a.childRow(kept))!;
      expect((row.name, row.birthDate), ('Local', DateTime(2018, 2, 2)));
      expect(await a.ops(kept), hasLength(1), reason: 'still waiting');
      expect((await a.childRow(gone))!.name, 'Disparu');
      expect(await a.artworkRow(artwork), isNotNull);
      expect(await a.vaultBytes(), before, reason: 'no file touched');
      await a.expectNoDanglingReference();

      // The artwork's creation waits for its media descriptors (the cloud
      // composition builds them), so the device never goes fully quiet here.
      await a.releaseBackoff();
      await a.sync();
      await a.sync();

      expect(backend.child(kept).values['name'], 'Local');
      expect(await a.ops(kept), isEmpty);
      expect(await a.vaultBytes(), before);
    });

    test('S15 a new device joining a family with live, trashed and purged '
        'artworks keeps the first two and nothing of the third (INV-12, '
        'INV-13)', () async {
      remoteChild(backend, _id(1), 'Léa');
      remoteChild(backend, _id(2), 'Noé');
      remoteChild(backend, _id(3), 'Zoé');
      for (var i = 0; i < 4; i++) {
        remoteArtwork(
          backend,
          _id(i < 2 ? 1 : 2),
          id: _id(10 + i),
          mediaId: _id(20 + i),
          extra: {'story': 'Dessin $i'},
        );
      }
      backend.remoteLifecycle(SyncEntityType.artwork, _id(12), 'trashed');
      backend.remoteLifecycle(SyncEntityType.artwork, _id(13), 'trashed');
      backend.remoteLifecycle(SyncEntityType.artwork, _id(13), 'purged');
      final fresh = await world.device();

      await fresh.sync();

      expect(await fresh.childrenView(), serverChildren());
      expect((await fresh.artworkRow(_id(10)))!.deletedAt, isNull);
      expect((await fresh.artworkRow(_id(11)))!.deletedAt, isNull);
      expect(
        (await fresh.artworkRow(_id(12)))!.deletedAt,
        isNotNull,
        reason: 'in the trash, restorable',
      );
      expect(await fresh.artworkRow(_id(13)), isNull);
      // Every photo it will show is recoverable on demand: a row waits for it.
      final media = MediaVersionsRepository(fresh.db);
      for (final photo in [_id(20), _id(21), _id(22)]) {
        final versions = await media.versionsOf(photo);
        expect(versions.map((v) => v.state), [
          MediaVersionState.pendingDownload,
        ], reason: 'photo $photo');
      }
      expect(await media.versionsOf(_id(23)), isEmpty, reason: 'purged');
      await fresh.expectNoDanglingReference();
    });

    test('S16 two artworks served before their child wait for it across a '
        'kill, then appear whole (INV-14)', () async {
      backend.pageSize = 1;
      final child = _id(1);
      for (var i = 0; i < 2; i++) {
        remoteArtwork(
          backend,
          child,
          id: _id(10 + i),
          mediaId: _id(20 + i),
          extra: {'story': 'Patient $i'},
        );
      }
      remoteChild(backend, child, 'Parent');
      backend.onPageServed = (index) {
        if (index == 1) backend.failNextPull = const SocketException('killed');
      };
      final fresh = await world.device();

      await expectLater(fresh.sync(), throwsA(isA<SocketException>()));
      await fresh.restart();
      expect(await fresh.artworkRow(_id(10)), isNull);
      expect(await fresh.artworkRow(_id(11)), isNull);
      expect(
        await fresh.db.select(fresh.db.deferredRemoteChangesTable).get(),
        hasLength(2),
        reason: 'waiting, not dropped',
      );

      await world.settle([fresh]);

      expect((await fresh.artworkRow(_id(10)))!.story, 'Patient 0');
      expect((await fresh.artworkRow(_id(11)))!.story, 'Patient 1');
      expect(
        await fresh.db.select(fresh.db.deferredRemoteChangesTable).get(),
        isEmpty,
      );
      expect(await fresh.childrenView(), serverChildren());
    });
  });
}

extension on Node {
  /// Keeps every queued operation out of the next pushes.
  Future<void> holdOperations() => db
      .update(db.syncOutboxTable)
      .write(
        SyncOutboxTableCompanion(
          nextAttemptAt: Value(DateTime.now().add(const Duration(days: 1))),
        ),
      );
}
