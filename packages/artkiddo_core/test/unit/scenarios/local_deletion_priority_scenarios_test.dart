// Local deletions win over the remote side (2026-10-04): a trash, a purge or
// a child deletion made on this device works offline, survives a restart, is
// applied remotely once the network is back, and is never undone by a
// concurrent remote edit or restore pulled in the meantime.

import 'dart:io';

import 'package:artkiddo_core/artkiddo_core.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';

import '../sync/operation_sync_test.dart' show Node;
import 'scenario_harness.dart';

const _child = '00000000-0000-4000-8000-0000000000a1';
const _artwork = '00000000-0000-4000-8000-0000000000b1';
const _photo = '00000000-0000-4000-8000-0000000000c1';

const _offline = SocketException('offline');

void main() {
  late World world;
  late ScenarioBackend backend;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() {
    world = World();
    backend = world.backend;
  });

  tearDown(() => world.dispose());

  LocalTrashRepository trashOf(Node node, {DateTime Function()? now}) =>
      LocalTrashRepository(
        node.db,
        node.vault,
        now: now,
        queueRemoteDeletions: true,
      );

  /// A run that may fail because the remote side is unreachable.
  Future<void> offlineSync(Node node) async {
    try {
      await node.sync();
    } on SocketException {
      // Expected while offline.
    }
  }

  /// Two devices holding one remote artwork.
  Future<(Node, Node)> twoDevices() async {
    remoteChild(backend, _child);
    remoteArtwork(
      backend,
      _child,
      id: _artwork,
      mediaId: _photo,
      extra: {'story': 'Avant'},
    );
    final a = await world.device();
    final b = await world.device();
    await world.settle([a, b]);
    return (a, b);
  }

  group('trash', () {
    test('D01 an artwork trashed offline is trashed remotely after a restart '
        'and the reconnection', () async {
      final (a, b) = await twoDevices();
      world.goDown(_offline);

      expect(await a.artworks.delete(_artwork), isA<ActionSuccess<void>>());
      await offlineSync(a);
      await a.restart();
      expect(await a.artworkOps(_artwork), hasLength(1), reason: 'durable');

      world.recover();
      await world.settle([a, b]);

      expect(backend.artwork(_artwork).lifecycle, 'trashed');
      for (final node in [a, b]) {
        expect((await node.artworkRow(_artwork))!.deletedAt, isNotNull);
        expect(await node.artworkOps(_artwork), isEmpty);
      }
    });

    test('D02 a trash waiting to be sent wins over a remote restore pulled '
        'meanwhile', () async {
      final (a, b) = await twoDevices();
      // Another device trashes then restores the artwork while this one,
      // unable to send, trashes it too.
      backend.outage = _offline;
      expect(await a.artworks.delete(_artwork), isA<ActionSuccess<void>>());
      backend.remoteLifecycle(SyncEntityType.artwork, _artwork, 'trashed');
      backend.remoteLifecycle(SyncEntityType.artwork, _artwork, 'active');

      await a.sync(); // pulls the restore, cannot send
      expect(
        (await a.artworkRow(_artwork))!.deletedAt,
        isNotNull,
        reason: 'the pull does not take the artwork out of the trash',
      );

      world.recover();
      await world.settle([a, b]);
      expect(backend.artwork(_artwork).lifecycle, 'trashed');
      for (final node in [a, b]) {
        expect((await node.artworkRow(_artwork))!.deletedAt, isNotNull);
      }
    });

    test('D03 a trash waiting to be sent wins over a concurrent remote edit, '
        'which stays on the trashed artwork', () async {
      final (a, b) = await twoDevices();
      backend.outage = _offline;
      expect(await a.artworks.delete(_artwork), isA<ActionSuccess<void>>());
      await b.artworks.updateStory(id: _artwork, story: 'Ailleurs');
      backend.outage = null;
      await b.sync();
      backend.outage = _offline;
      await a.sync();
      expect((await a.artworkRow(_artwork))!.deletedAt, isNotNull);

      world.recover();
      await world.settle([a, b]);
      final server = backend.artwork(_artwork);
      expect(server.lifecycle, 'trashed');
      expect(server.values['story'], 'Ailleurs');
      for (final node in [a, b]) {
        final row = (await node.artworkRow(_artwork))!;
        expect((row.deletedAt != null, row.story), (true, 'Ailleurs'));
      }
    });

    test('D04 the 30-day expiry keeps a trash never sent, so the remote side '
        'never brings the artwork back', () async {
      final (a, _) = await twoDevices();
      world.goDown(_offline);
      expect(await a.artworks.delete(_artwork), isA<ActionSuccess<void>>());

      final later = DateTime.now().add(const Duration(days: 31));
      final expired = await trashOf(a, now: () => later).purgeExpired();
      expect(expired, isA<ActionSuccess<int>>());
      expect(await a.artworkRow(_artwork), isNull);
      expect(await a.artworkOps(_artwork), hasLength(1));

      world.recover();
      await world.settle([a]);
      expect(backend.artwork(_artwork).lifecycle, 'trashed');
      final row = await a.artworkRow(_artwork);
      expect(row == null || row.deletedAt != null, isTrue);
    });
  });

  group('purge', () {
    test('D05 an artwork purged offline is purged remotely after a restart '
        'and the reconnection; a remote restore pulled meanwhile does not '
        'bring it back', () async {
      final (a, b) = await twoDevices();
      backend.remoteLifecycle(SyncEntityType.artwork, _artwork, 'trashed');
      await world.settle([a, b]);
      expect((await a.artworkRow(_artwork))!.deletedAt, isNotNull);

      backend.outage = _offline;
      expect(await trashOf(a).purge(_artwork), isA<ActionSuccess<void>>());
      expect(await a.artworkRow(_artwork), isNull);
      backend.remoteLifecycle(SyncEntityType.artwork, _artwork, 'active');
      await a.sync(); // pulls the restore, cannot send
      expect(await a.artworkRow(_artwork), isNull, reason: 'not resurrected');

      await a.restart();
      expect(await a.artworkOps(_artwork), hasLength(1), reason: 'durable');

      world.recover();
      await world.settle([a, b]);
      expect(backend.artwork(_artwork).lifecycle, 'purged');
      for (final node in [a, b]) {
        expect(await node.artworkRow(_artwork), isNull);
        expect(await node.artworkOps(_artwork), isEmpty);
      }
    });

    test('D13 a purge refused to a non-parent (403) becomes a trash: the '
        'server keeps it, nothing fails, nothing retries', () async {
      final (a, _) = await twoDevices();
      backend.remoteLifecycle(SyncEntityType.artwork, _artwork, 'trashed');
      await world.settle([a]);
      var purgeAttempts = 0;
      backend.refuse = (patch) {
        if (patch.fields['lifecycle'] != 'purged') return null;
        purgeAttempts++;
        return const SyncAuthException(SyncAuthFailure.notFamilyMember);
      };

      expect(await trashOf(a).purge(_artwork), isA<ActionSuccess<void>>());
      await a.sync();
      await world.settle([a]);
      await a.sync();

      expect(purgeAttempts, 1, reason: 'no retry loop');
      expect(backend.artwork(_artwork).lifecycle, 'trashed');
      expect(await a.artworkOps(_artwork), isEmpty, reason: 'resolved');
      // The pull may list the server trash again here (metadata only, as
      // after any late trash); it is never active and has no files.
      expect((await a.artworkRow(_artwork))?.deletedAt, isNotNull);
      expect(await a.vaultBytes(), isEmpty, reason: 'files gone');
    });

    test('D06 an artwork never sent and purged offline: its files are '
        'removed, its creation is never sent, the purge is accepted', () async {
      remoteChild(backend, _child);
      final a = await world.device();
      await world.settle([a]);
      world.goDown(_offline);
      final id = await a.newLocalArtwork(_child, story: 'Ici');
      expect(await a.vaultBytes(), isNotEmpty);
      expect(await a.artworks.delete(id), isA<ActionSuccess<void>>());

      expect(await trashOf(a).purge(id), isA<ActionSuccess<void>>());
      expect(await a.artworkRow(id), isNull);
      expect(await a.vaultBytes(), isEmpty, reason: 'files purged');
      final ops = await a.artworkOps(id);
      expect(ops.single.patch!.fields, {'lifecycle': 'purged'});

      world.recover();
      await world.settle([a]);
      expect(backend.entity(SyncEntityType.artwork, id), isNull);
      expect(await a.artworkOps(id), isEmpty);
      await a.expectNoDanglingReference();
    });

    test('D07 emptying the trash offline queues one purge per artwork and '
        'also purges an artwork only listed remotely', () async {
      final (a, b) = await twoDevices();
      backend.remoteLifecycle(SyncEntityType.artwork, _artwork, 'trashed');
      await world.settle([a, b]);
      world.goDown(_offline);

      final trash = QueuedRemoteTrashRepository(
        remote: _FakeRemoteTrash(),
        local: trashOf(a),
        db: a.db,
      );
      // Offline the list is this device's trash.
      final listed = await trash.listTrash(scopeId: 'family-a');
      expect(
        (listed as ActionSuccess<List<TrashedArtwork>>).value.single.id,
        _artwork,
      );
      expect(
        await trash.purgeAll(scopeId: 'family-a'),
        isA<ActionSuccess<void>>(),
      );
      expect(await a.artworkRow(_artwork), isNull);

      world.recover();
      await world.settle([a, b]);
      expect(backend.artwork(_artwork).lifecycle, 'purged');
      expect(await b.artworkRow(_artwork), isNull);
    });

    test('D08 the merged trash hides an artwork whose purge is queued and '
        'shows one trashed here and not sent yet', () async {
      final (a, _) = await twoDevices();
      const remoteOnly = '00000000-0000-4000-8000-0000000000b9';
      final remote = _FakeRemoteTrash(
        items: [_item(remoteOnly), _item(_artwork)],
      );
      final trash = QueuedRemoteTrashRepository(
        remote: remote,
        local: trashOf(a),
        db: a.db,
      );
      backend.outage = _offline;
      expect(await a.artworks.delete(_artwork), isA<ActionSuccess<void>>());
      expect(await trash.purge(remoteOnly), isA<ActionSuccess<void>>());

      final listed = await trash.listTrash(scopeId: 'family-a');
      expect(
        (listed as ActionSuccess<List<TrashedArtwork>>).value.map((i) => i.id),
        [_artwork],
      );
    });
  });

  group('child', () {
    test('D09 a child deleted offline is purged remotely after a restart and '
        'the reconnection, despite a concurrent remote rename', () async {
      final (a, b) = await twoDevices();
      backend.outage = _offline;
      expect(await a.children.delete(_child), isA<ActionSuccess<void>>());
      backend.remoteEdit(SyncEntityType.child, _child, 'name', 'Renommé');
      await a.sync(); // pulls the rename, cannot send
      expect(await a.childRow(_child), isNull, reason: 'not resurrected');
      expect(await a.artworkRow(_artwork), isNull);

      await a.restart();
      expect(await a.ops(_child), hasLength(1), reason: 'durable');

      world.recover();
      await world.settle([a, b]);
      expect(backend.child(_child).lifecycle, 'purged');
      expect(backend.artwork(_artwork).lifecycle, 'trashed');
      expect(await a.childRow(_child), isNull);
      expect(await a.artworkRow(_artwork), isNull);
      expect(await a.outbox.countPending(), 0);
      final hidden = await b.childRow(_child);
      expect(hidden == null || hidden.deletedAt != null, isTrue);
    });
  });
}

TrashedArtwork _item(String id) => TrashedArtwork(
  id: id,
  childId: _child,
  childName: 'Léa',
  deletedAt: DateTime(2026, 10, 1),
  purgeAt: DateTime(2026, 10, 31),
);

/// The remote trash: unreachable unless it is given its items.
class _FakeRemoteTrash implements TrashRepository {
  final List<TrashedArtwork>? items;

  _FakeRemoteTrash({this.items});

  @override
  Future<ActionResult<List<TrashedArtwork>>> listTrash({
    String? scopeId,
  }) async => items == null
      ? const ActionFailed(NetworkFailure())
      : ActionSuccess(items!);

  @override
  Future<ActionResult<void>> restore(String artworkId) async =>
      const ActionFailed(NetworkFailure());

  @override
  Future<ActionResult<void>> purge(String artworkId) =>
      throw StateError('a purge never calls the remote trash');

  @override
  Future<ActionResult<void>> purgeAll({String? scopeId}) =>
      throw StateError('a purge never calls the remote trash');

  @override
  Future<ActionResult<int>> purgeExpired({DateTime? now}) async =>
      const ActionSuccess(0);
}
