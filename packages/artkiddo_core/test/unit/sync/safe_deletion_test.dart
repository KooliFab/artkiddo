// Safe trash and deletions: a trashed artwork keeps its row, files and
// operations for 30 days; the one physical deletion asks `isMediaReferenced`
// first; an artwork purged remotely comes back on this phone only, with its
// owner told so; and no error path of the sync engine deletes anything.

import 'dart:io';

import 'package:artkiddo_core/artkiddo_core.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'operation_sync_test.dart' show FakeProtocolBackend, Node;
import 'sync_engine_test.dart' show makeTestImage;

void main() {
  late FakeProtocolBackend backend;
  late Node node;
  late LocalTrashRepository trash;

  // The repositories under test stamp trashing with the real clock.
  final day0 = DateTime.now();

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() async {
    backend = FakeProtocolBackend();
    node = await Node.create(backend);
    trash = LocalTrashRepository(node.db, node.vault, now: () => day0);
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

  Future<ArtworkEntity?> row(String id) => (node.db.select(
    node.db.artworksTable,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<bool> fileExists(String? relativePath) async =>
      relativePath != null &&
      await (await node.vault.resolveFile(relativePath)).exists();

  Future<List<SyncOutboxEntryEntity>> artworkOps(String id) =>
      node.outbox.operationsOf(SyncEntityKind.artwork, id);

  Future<void> addAudio(String id, int n) async {
    final source = File(p.join(node.root.path, 'rec$n.m4a'))
      ..writeAsBytesSync([n, n, n]);
    expect(
      await node.artworks.updateAudio(
        id: id,
        sourceAudioFile: source,
        durationMs: 1000 * n,
      ),
      isA<ActionSuccess<void>>(),
    );
  }

  group('trash', () {
    test('an artwork never sent stays in the trash for 30 days, restorable, '
        'with its pending creation', () async {
      final child = await node.newChild();
      final id = await newArtwork(child);
      final original = (await row(id))!.relativeImagePath;
      final queuedBefore = (await artworkOps(id)).length;
      expect(queuedBefore, 1, reason: 'the creation was never sent');

      expect(await node.artworks.delete(id), isA<ActionSuccess<void>>());

      expect((await row(id))!.deletedAt, isNotNull);
      expect(await fileExists(original), isTrue);
      final ops = await artworkOps(id);
      expect(ops.length, 2, reason: 'creation kept, trash patch behind it');
      expect(ops.first.patchJson, isNull);
      expect(ops.last.patch!.fields['lifecycle'], 'trashed');

      // Day 29: still there. Day 31: purged.
      final day29 = LocalTrashRepository(
        node.db,
        node.vault,
        now: () => day0.add(const Duration(days: 29)),
      );
      expect(await day29.purgeExpired(), isA<ActionSuccess<int>>());
      expect(await row(id), isNotNull);

      expect(await trash.restore(id), isA<ActionSuccess<void>>());
      expect((await row(id))!.deletedAt, isNull);
      expect(await fileExists(original), isTrue);
    });

    test('the purge after 30 days removes the row, its files and the '
        'operations that only described it', () async {
      final child = await node.newChild();
      final id = await newArtwork(child);
      await addAudio(id, 1);
      final before = (await row(id))!;
      await node.artworks.delete(id);

      final day31 = LocalTrashRepository(
        node.db,
        node.vault,
        now: () => day0.add(const Duration(days: 31)),
      );
      final result = await day31.purgeExpired();

      expect((result as ActionSuccess<int>).value, 1);
      expect(await row(id), isNull);
      expect(await fileExists(before.relativeImagePath), isFalse);
      expect(await fileExists(before.relativeAudioPath), isFalse);
      expect(await artworkOps(id), isEmpty);
    });

    test('a version still in the conflict history survives the purge, and is '
        'deleted once the history lets go', () async {
      final child = await node.newChild();
      final id = await newArtwork(child);
      await addAudio(id, 1);
      final v1 = (await row(id))!.relativeAudioPath!;
      await addAudio(id, 2);
      final v2 = (await row(id))!.relativeAudioPath!;
      expect(v1, isNot(v2));
      await ReplacedValuesRepository(node.db).record(
        entityType: SyncEntityType.artwork,
        entityId: id,
        field: 'audio',
        value: {'mediaId': id, 'version': 1},
        mediaRef: MediaRef(mediaId: id, version: 1),
        source: ReplacedValueSource.remote,
      );
      await node.artworks.delete(id);

      await LocalTrashRepository(
        node.db,
        node.vault,
        now: () => day0.add(const Duration(days: 31)),
      ).purgeExpired();

      expect(await row(id), isNull);
      expect(await fileExists(v2), isFalse);
      expect(await fileExists(v1), isTrue, reason: 'v1 is still referenced');
      // (The original photo is held too: the history names `(id, 1)` without
      // a role, so the answer errs on the side of "referenced".)
      expect(
        (await node.db.select(node.db.pendingFileCleanupsTable).get()).map(
          (e) => e.relativePath,
        ),
        contains(v1),
      );

      await node.vault.retryPendingCleanups(node.db);
      expect(await fileExists(v1), isTrue, reason: 'the history still has it');

      await node.db.delete(node.db.replacedValuesTable).go();
      await node.vault.retryPendingCleanups(node.db);
      expect(await fileExists(v1), isFalse);
      expect(
        await node.db.select(node.db.pendingFileCleanupsTable).get(),
        isEmpty,
      );
    });

    test('a file an operation still names is not deleted by a purge', () async {
      final child = await node.newChild();
      final id = await newArtwork(child);
      await addAudio(id, 1);
      final audio = (await row(id))!.relativeAudioPath!;
      final descriptor = MediaDescriptor(
        mediaId: id,
        version: 1,
        role: MediaRole.audio,
        format: MediaFormat.m4a,
        byteSize: 3,
        sha256: 'c' * 64,
        durationMs: 1000,
      );
      // A pending operation of another entity that carries the version.
      await node.outbox.enqueuePatch(
        EntityPatch(
          opId: '3f2c1a4e-8b7d-4c6e-9f10-2a3b4c5d6e11',
          entityType: SyncEntityType.artwork,
          entityId: '00000000-0000-4000-8000-000000000001',
          baseRevisions: {'audio': 0},
          fields: {'audio': descriptor.ref.toJson()},
          media: [descriptor],
          createdAt: DateTime.utc(2026, 10, 1),
        ),
      );
      await node.artworks.delete(id);

      await LocalTrashRepository(
        node.db,
        node.vault,
        now: () => day0.add(const Duration(days: 31)),
      ).purgeExpired();

      expect(await fileExists(audio), isTrue);
    });
  });

  group('an artwork purged remotely', () {
    Future<String> trashedAfterRemotePurge({bool hideChild = false}) async {
      final child = await node.newChild();
      final id = await newArtwork(child);
      await node.db.delete(node.db.syncOutboxTable).go();
      await (node.db.update(
        node.db.artworksTable,
      )..where((t) => t.id.equals(id))).write(
        ArtworksTableCompanion(
          deletedAt: Value(day0),
          remotePurgedAt: hideChild ? const Value(null) : Value(day0),
          syncState: const Value('synced'),
        ),
      );
      if (hideChild) {
        await (node.db.update(node.db.childrenTable)
              ..where((t) => t.id.equals(child)))
            .write(ChildrenTableCompanion(deletedAt: Value(day0)));
      }
      return id;
    }

    test('restored here: active on this phone, flagged as existing only '
        'here, nothing sent', () async {
      final id = await trashedAfterRemotePurge();
      final listed =
          ((await trash.listTrash()) as ActionSuccess<List<TrashedArtwork>>)
              .value;
      expect(listed.single.existsOnlyHere, isTrue);

      expect(await trash.restore(id), isA<ActionSuccess<void>>());

      final restored = (await row(id))!;
      expect(restored.deletedAt, isNull);
      expect(restored.remotePurgedAt, isNotNull);
      expect(restored.syncState, 'localOnly');
      expect(await artworkOps(id), isEmpty, reason: 'no lifecycle: active');
      expect(await node.artworks.getById(id), isNotNull);
      expect(await fileExists(restored.relativeImagePath), isTrue);
    });

    test('a purged child comes back with its restored artwork', () async {
      final id = await trashedAfterRemotePurge(hideChild: true);
      final listed =
          ((await trash.listTrash()) as ActionSuccess<List<TrashedArtwork>>)
              .value;
      expect(listed.single.existsOnlyHere, isTrue);
      expect(await node.children.count(), 0);

      await trash.restore(id);

      expect(await node.children.count(), 1);
      expect((await row(id))!.remotePurgedAt, isNotNull);
      expect(await artworkOps(id), isEmpty);
    });

    test('a hidden child goes with its last purged artwork', () async {
      final id = await trashedAfterRemotePurge(hideChild: true);
      final childId = (await row(id))!.childId;

      expect(await trash.purge(id), isA<ActionSuccess<void>>());

      expect(await row(id), isNull);
      expect(
        await (node.db.select(
          node.db.childrenTable,
        )..where((t) => t.id.equals(childId))).getSingleOrNull(),
        isNull,
      );
    });
  });

  group('no sync error deletes anything', () {
    Future<(String, String?, String?)> seeded() async {
      final child = await node.newChild();
      final id = await newArtwork(child);
      await addAudio(id, 1);
      final entity = (await row(id))!;
      return (id, entity.relativeImagePath, entity.relativeAudioPath);
    }

    Future<void> expectIntact(
      String id,
      String? image,
      String? audio,
      int ops,
    ) async {
      expect(await row(id), isNotNull);
      expect((await row(id))!.deletedAt, isNull);
      expect(await fileExists(image), isTrue);
      expect(await fileExists(audio), isTrue);
      expect((await artworkOps(id)).length, ops);
    }

    test('a network error while pulling', () async {
      final (id, image, audio) = await seeded();
      final ops = (await artworkOps(id)).length;
      backend.failNextPull = const SocketException('offline');

      await expectLater(node.sync(), throwsA(isA<SocketException>()));

      await expectIntact(id, image, audio, ops);
    });

    test('a refused cursor (CURSOR_INVALID)', () async {
      final (id, image, audio) = await seeded();
      await node.sync();
      backend.rebuildHistory();
      final ops = (await artworkOps(id)).length;

      await node.sync();

      await expectIntact(id, image, audio, ops);
    });

    test('a signed-out engine', () async {
      final (id, image, audio) = await seeded();
      final ops = (await artworkOps(id)).length;

      await node.newEngine(currentUserId: () => null).syncAll();

      await expectIntact(id, image, audio, ops);
    });

    test('no code of the sync engine reaches a physical deletion, except the '
        'explicit reset of a vault joining another family', () {
      final offenders = <String>[];
      for (final file in Directory('lib/src/sync').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        final source = file.readAsStringSync();
        for (final call in const [
          'deleteFileOrEnqueueCleanup',
          'deleteArtworkFilesOrEnqueueCleanup',
          'deleteVaultFileIfUnreferenced',
          'eraseAllArtworkPhotos',
        ]) {
          if (source.contains(call) &&
              !file.path.endsWith('replaced_values.dart')) {
            offenders.add('${file.path}: $call');
          }
        }
        if (source.contains('eraseEverything') &&
            !file.path.endsWith('sync_engine.dart')) {
          offenders.add('${file.path}: eraseEverything');
        }
      }
      expect(offenders, isEmpty);
      expect(
        'eraseEverything'
            .allMatches(
              File('lib/src/sync/sync_engine.dart').readAsStringSync(),
            )
            .length,
        1,
      );
    });
  });
}
