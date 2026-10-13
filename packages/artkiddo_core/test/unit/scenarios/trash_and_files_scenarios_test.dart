// Scenarios S17–S20: the trash and the files. An edit made offline against
// an artwork trashed elsewhere, an artwork that never left the phone, a write
// that dies half way and a disk that fills up: nothing is resurrected, nothing
// is lost, and the bytes of every file are the ones that were written.

import 'dart:io';

import 'package:artkiddo_core/artkiddo_core.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../local_data/safe_file_writes_test.dart' show FaultyOps;
import '../sync/operation_sync_test.dart' show Node;
import '../sync/sync_engine_test.dart' show makeTestImage;
import 'scenario_harness.dart';

const _child = '00000000-0000-4000-8000-0000000000a1';
const _artwork = '00000000-0000-4000-8000-0000000000b1';
const _photo = '00000000-0000-4000-8000-0000000000c1';

void main() {
  late World world;
  late ScenarioBackend backend;

  // The repositories under test stamp trashing with the real clock.
  final day0 = DateTime.now();

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() {
    world = World();
    backend = world.backend;
  });

  tearDown(() => world.dispose());

  group('trash against an edit', () {
    /// Another device edits the story offline while a second one trashes the
    /// artwork; the trash reaches the remote side first.
    Future<(Node, Node)> editMeetsTrash() async {
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
      await a.artworks.updateStory(id: _artwork, story: 'Modifié hors ligne');
      expect(await b.artworks.delete(_artwork), isA<ActionSuccess<void>>());
      await b.sync();
      await world.settle([a, b]);
      return (a, b);
    }

    test('S17 an artwork trashed on one device while the other edits its '
        'story offline is not resurrected, and the edit is kept in the '
        'history of replaced values (INV-11)', () async {
      final (a, b) = await editMeetsTrash();

      final server = backend.artwork(_artwork);
      expect(server.lifecycle, 'trashed', reason: 'the edit did not revive it');
      expect(server.values['story'], 'Avant');
      for (final node in [a, b]) {
        expect((await node.artworkRow(_artwork))!.deletedAt, isNotNull);
        expect(await node.artworkOps(_artwork), isEmpty, reason: 'not resent');
      }
      final kept = await a.replaced(_artwork);
      expect(kept.map((v) => (v.field, v.value, v.source)), [
        ('story', 'Modifié hors ligne', ReplacedValueSource.local),
      ]);
      await a.restart();
      expect((await a.replaced(_artwork)).single.value, 'Modifié hors ligne');

      // Restoring it within the 30 days is possible and starts no request.
      final sent = backend.received.length;
      final trash = LocalTrashRepository(a.db, a.vault, now: () => day0);
      expect(await trash.restore(_artwork), isA<ActionSuccess<void>>());
      expect((await a.artworkRow(_artwork))!.deletedAt, isNull);
      expect(backend.received, hasLength(sent));
      await a.expectNoDanglingReference();
    });

    // The pull that follows the `deleteVsEdit` refusal leaves the held edit
    // on the local row (field-conflict.json: kept until acknowledged).
    test('S17b the offline edit is still the text of the artwork the parent '
        'finds in the trash (INV-11)', () async {
      final (a, _) = await editMeetsTrash();

      expect((await a.artworkRow(_artwork))!.story, 'Modifié hors ligne');
      expect(await a.engine.replacedValues.heldValues(_artwork), {
        'story': 'Modifié hors ligne',
      });
    });

    test('S17e restored remotely, the held edit is sent again on top of the '
        'remote revision and released once acknowledged (INV-11)', () async {
      final (a, b) = await editMeetsTrash();

      backend.remoteLifecycle(SyncEntityType.artwork, _artwork, 'active');
      await world.settle([a, b]);

      final server = backend.artwork(_artwork);
      expect(server.lifecycle, 'active');
      expect(server.values['story'], 'Modifié hors ligne');
      for (final node in [a, b]) {
        final row = (await node.artworkRow(_artwork))!;
        expect((row.deletedAt, row.story), (null, 'Modifié hors ligne'));
        expect(await node.artworkOps(_artwork), isEmpty);
      }
      expect(await a.engine.replacedValues.heldValues(_artwork), isEmpty);

      // Released: a later remote edit is applied as any other.
      backend.remoteEdit(SyncEntityType.artwork, _artwork, 'story', 'Après');
      await a.sync();
      expect((await a.artworkRow(_artwork))!.story, 'Après');
    });

    test('S17f purged, the held edit is dropped and never sent', () async {
      final (a, _) = await editMeetsTrash();
      final sent = backend.received.length;

      final trash = LocalTrashRepository(a.db, a.vault, now: () => day0);
      expect(await trash.purge(_artwork), isA<ActionSuccess<void>>());

      expect(await a.engine.replacedValues.heldValues(_artwork), isEmpty);
      await a.sync();
      expect(backend.received, hasLength(sent));
      expect(backend.artwork(_artwork).lifecycle, 'trashed');
    });

    test('S17g purged remotely, the held edit is dropped', () async {
      final (a, _) = await editMeetsTrash();

      backend.remoteLifecycle(SyncEntityType.artwork, _artwork, 'purged');
      await a.sync();

      expect(await a.engine.replacedValues.heldValues(_artwork), isEmpty);
      expect(await a.artworkOps(_artwork), isEmpty);
    });
  });

  group('an artwork that never left the phone', () {
    late Node a;
    late String artwork;
    late Map<String, String> files;

    setUp(() async {
      a = await world.device();
      final child = await a.newChild('Léa');
      artwork = await a.newLocalArtwork(child, seed: 3, story: 'Jamais envoyé');
      files = await a.vaultBytes();
      expect(files, isNotEmpty);
      expect(await a.artworks.delete(artwork), isA<ActionSuccess<void>>());
    });

    test('S18 in the trash for 30 days it can be restored, with the same '
        'bytes and its creation still queued (INV-05, INV-17)', () async {
      await a.sync();
      final day29 = LocalTrashRepository(
        a.db,
        a.vault,
        now: () => day0.add(const Duration(days: 29)),
      );
      expect(await day29.purgeExpired(), isA<ActionSuccess<int>>());

      expect((await a.artworkRow(artwork))!.deletedAt, isNotNull);
      expect(await a.vaultBytes(), files, reason: 'nothing removed by day 29');
      expect(await a.artworkOps(artwork), isNotEmpty);

      final trash = LocalTrashRepository(a.db, a.vault, now: () => day0);
      expect(await trash.restore(artwork), isA<ActionSuccess<void>>());

      final row = (await a.artworkRow(artwork))!;
      expect((row.deletedAt, row.story), (null, 'Jamais envoyé'));
      expect(await a.vaultBytes(), files);
      expect(
        backend.entities.keys.where((k) => k.startsWith('artwork/')),
        isEmpty,
        reason: 'the remote side never heard of it',
      );
      await a.expectNoDanglingReference();
    });

    test('S18b after 30 days it is purged here, files and operations '
        'included, and the remote side is never involved (INV-05, '
        'INV-17)', () async {
      await a.sync();
      final day31 = LocalTrashRepository(
        a.db,
        a.vault,
        now: () => day0.add(const Duration(days: 31)),
      );

      expect(await day31.purgeExpired(), isA<ActionSuccess<int>>());

      expect(await a.artworkRow(artwork), isNull);
      expect(await a.artworkOps(artwork), isEmpty);
      final left = await a.vaultBytes();
      expect(
        left.keys.where((path) => files.containsKey(path)),
        isEmpty,
        reason: 'every file of the artwork is gone',
      );
      expect(
        backend.entities.keys.where((k) => k.startsWith('artwork/')),
        isEmpty,
        reason: 'the remote side never heard of it',
      );
      expect(backend.received, hasLength(1), reason: 'the child, only');
      await a.expectNoDanglingReference();
    });
  });

  group('a write that dies, a disk that fills', () {
    late FaultyOps disk;
    late Node a;
    late String child;

    setUp(() async {
      disk = FaultyOps();
      a = await world.device(fileOps: disk);
      child = await a.newChild('Léa');
    });

    test('S19 a kill after the temporary file and before the rename leaves '
        'no artwork and no half file; the next try writes the exact bytes '
        '(INV-08, INV-04)', () async {
      final source = await makeTestImage(a.root, 'cap.jpg', seed: 5);
      disk
        ..failRename = true
        ..failCleanup = true; // nobody removes the temporary file: a real kill

      final killed = await a.artworks.create(
        childId: child,
        sourceImageFile: source,
        addedAt: DateTime(2026, 1, 1),
      );

      expect(killed, isA<ActionFailed<String>>());
      expect(await a.artworks.count(), 0, reason: 'no row without its file');
      expect(await a.outbox.countPending(), 1, reason: 'only the child');
      expect(
        (await a.vaultBytes()).keys.where((k) => k.endsWith(kTempFileSuffix)),
        hasLength(1),
        reason: 'the unfinished write is still there until the next start',
      );

      // The next start removes it; the device is usable again.
      disk
        ..failRename = false
        ..failCleanup = false;
      await a.restart();
      expect(await a.vault.removeStaleTempFiles(), 1);
      final id = await a.artworks
          .create(
            childId: child,
            sourceImageFile: source,
            addedAt: DateTime(2026, 1, 1),
          )
          .then((r) => (r as ActionSuccess<String>).value);

      final row = (await a.artworkRow(id))!;
      final original = await a.vault.resolveFile(row.relativeImagePath!);
      expect(await original.readAsBytes(), await source.readAsBytes());
      await a.expectNoDanglingReference();
    });

    test('S20 a full disk refuses a new artwork cleanly and leaves the '
        'others, byte for byte (INV-04)', () async {
      final first = await a.newLocalArtwork(child, seed: 1);
      final before = await a.vaultBytes();
      disk.failCopy = true;
      final source = await makeTestImage(a.root, 'second.jpg', seed: 2);

      final result = await a.artworks.create(
        childId: child,
        sourceImageFile: source,
        addedAt: DateTime(2026, 1, 2),
      );

      expect(
        (result as ActionFailed<String>).failure,
        isA<StorageFullFailure>(),
      );
      expect(await a.artworks.count(), 1);
      expect(await a.vaultBytes(), before);
      expect(await a.artworkRow(first), isNotNull);

      disk.failCopy = false; // space was freed
      expect(
        await a.artworks.create(
          childId: child,
          sourceImageFile: source,
          addedAt: DateTime(2026, 1, 2),
        ),
        isA<ActionSuccess<String>>(),
      );
      await a.expectNoDanglingReference();
    });

    test('S20b a full disk during a new recording keeps the current one, '
        'byte for byte, and its queued operation (INV-04)', () async {
      final voice = File(p.join(a.root.path, 'one.m4a'))
        ..writeAsBytesSync(List.generate(600, (i) => (i * 5) % 251));
      final image = await makeTestImage(a.root, 'with_voice.jpg', seed: 6);
      final id =
          ((await a.artworks.create(
                    childId: child,
                    sourceImageFile: image,
                    addedAt: DateTime(2026, 1, 1),
                    sourceAudioFile: voice,
                    audioDurationMs: 2000,
                  ))
                  as ActionSuccess<String>)
              .value;
      final before = await a.vaultBytes();
      final opsBefore = (await a.artworkOps(id)).length;
      disk.failCopy = true;
      final second = File(p.join(a.root.path, 'two.m4a'))
        ..writeAsBytesSync(List.filled(900, 7));

      final result = await a.artworks.updateAudio(
        id: id,
        sourceAudioFile: second,
        durationMs: 3000,
      );

      expect((result as ActionFailed<void>).failure, isA<StorageFullFailure>());
      final row = (await a.artworkRow(id))!;
      final kept = await a.vault.resolveFile(row.relativeAudioPath!);
      expect(await kept.readAsBytes(), await voice.readAsBytes());
      expect(await a.vaultBytes(), before);
      expect((await a.artworkOps(id)).length, opsBefore);
      await a.expectNoDanglingReference();
    });
  });
}
