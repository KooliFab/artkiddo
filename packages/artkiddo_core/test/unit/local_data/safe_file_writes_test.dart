// Safe file writes and media versions (L03): a crash or a full disk never
// leaves a truncated file, a reference to a missing file, or a deleted file
// that is still needed.

import 'dart:io';

import 'package:artkiddo_core/artkiddo_core.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../sync/sync_engine_test.dart' show makeTestImage;

/// Disk primitives that fail on demand.
class FaultyOps extends DiskVaultFileOps {
  bool failCopy = false;
  bool failWrite = false;
  bool failRename = false;
  bool failCleanup = false;
  bool shortWrite = false;

  static FileSystemException get diskFull => FileSystemException(
    'writeFrom failed',
    '/vault',
    const OSError('No space left on device', 28),
  );

  @override
  Future<void> copy(File source, File dest) async {
    if (failCopy) {
      await dest.writeAsBytes([1]); // the partial file a full disk leaves
      throw diskFull;
    }
    await super.copy(source, dest);
  }

  @override
  Future<void> writeBytes(File file, List<int> bytes) async {
    if (failWrite) throw diskFull;
    if (shortWrite) return super.writeBytes(file, bytes.take(1).toList());
    await super.writeBytes(file, bytes);
  }

  @override
  Future<void> rename(File from, String to) async {
    if (failRename) throw const FileSystemException('killed before rename');
    await super.rename(from, to);
  }

  @override
  Future<void> deleteIfExists(File file) async {
    if (failCleanup) throw const FileSystemException('cannot clean up');
    await super.deleteIfExists(file);
  }
}

void main() {
  late Directory root;
  late Directory docs;
  late AppDatabase db;
  late FaultyOps ops;
  late LocalVault vault;
  late DriftArtworksRepository artworks;
  late DriftChildrenRepository children;
  late MediaVersionsRepository media;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('artkiddo_safe_write_');
    docs = Directory(p.join(root.path, 'docs'))..createSync();
    db = AppDatabase.forTesting(
      NativeDatabase(File(p.join(root.path, 'test.sqlite'))),
    );
    ops = FaultyOps();
    vault = LocalVault(documentsDirProvider: () async => docs, fileOps: ops);
    children = DriftChildrenRepository(db, vault);
    artworks = DriftArtworksRepository(db, vault);
    media = MediaVersionsRepository(db);
  });

  tearDown(() async {
    await db.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  List<File> filesUnder(String folder) {
    final dir = Directory(p.join(docs.path, folder));
    if (!dir.existsSync()) return const [];
    return dir.listSync(recursive: true).whereType<File>().toList();
  }

  Future<String> newChild() async =>
      (await children.create(name: 'Léa', birthDate: DateTime(2019, 3, 1))
              as ActionSuccess<String>)
          .value;

  Future<File> audioFile(String name, List<int> bytes) async =>
      File(p.join(root.path, name))..writeAsBytesSync(bytes);

  Future<String> newArtwork(
    String childId, {
    File? audio,
    int durationMs = 1000,
  }) async {
    final image = await makeTestImage(root, 'src.jpg');
    return (await artworks.create(
              childId: childId,
              sourceImageFile: image,
              addedAt: DateTime(2026, 1, 1),
              sourceAudioFile: audio,
              audioDurationMs: audio == null ? null : durationMs,
            )
            as ActionSuccess<String>)
        .value;
  }

  group('writeFileAtomically', () {
    test('writes the content, leaves no temporary file', () async {
      final dest = File(p.join(root.path, 'a', 'b', 'file.bin'));

      await writeFileAtomically(dest, bytes: [1, 2, 3]);

      expect(dest.readAsBytesSync(), [1, 2, 3]);
      expect(dest.parent.listSync().map((e) => p.basename(e.path)), [
        'file.bin',
      ]);
    });

    test('a failure before the rename leaves the previous content', () async {
      final dest = File(p.join(root.path, 'file.bin'))
        ..writeAsBytesSync([9, 9]);
      ops.failRename = true;

      await expectLater(
        writeFileAtomically(dest, bytes: [1, 2, 3], ops: ops),
        throwsA(isA<FileSystemException>()),
      );

      expect(dest.readAsBytesSync(), [9, 9]);
      expect(root.listSync().whereType<File>().map((f) => p.basename(f.path)), [
        'file.bin',
      ]);
    });

    test('a truncated write is refused and never becomes the file', () async {
      final dest = File(p.join(root.path, 'file.bin'));
      ops.shortWrite = true;

      await expectLater(
        writeFileAtomically(dest, bytes: [1, 2, 3], ops: ops),
        throwsA(isA<FileSystemException>()),
      );

      expect(dest.existsSync(), isFalse);
    });
  });

  group('crash recovery at start-up', () {
    test(
      'removes unfinished writes, keeps an unreferenced final file',
      () async {
        // Killed after the temporary file, and killed after the rename but
        // before the row was written.
        final id = '00000000-0000-4000-8000-000000000009';
        ops
          ..failRename = true
          ..failCleanup = true;
        await expectLater(
          vault.storeArtworkAudio(
            sourceFile: await audioFile('rec.m4a', [1, 2]),
            artworkId: id,
          ),
          throwsA(isA<FileSystemException>()),
        );
        ops
          ..failRename = false
          ..failCleanup = false;
        final orphan = await vault.storeArtworkAudio(
          sourceFile: await audioFile('rec2.m4a', [3, 4]),
          artworkId: id,
          version: 2,
        );
        expect(filesUnder('audio').map((f) => f.path), hasLength(2));

        final removed = await vault.removeStaleTempFiles();

        expect(removed, 1);
        final left = filesUnder('audio');
        expect(left.map((f) => p.relative(f.path, from: docs.path)), [orphan]);
        expect(left.single.readAsBytesSync(), [3, 4]);
        // Nothing references it, and nothing deleted it.
        expect(await media.reconcile(vault), 0);
        expect(left.single.existsSync(), isTrue);
      },
    );
  });

  group('creating an artwork', () {
    test('a full disk is a clean failure and leaves nothing behind', () async {
      final childId = await newChild();
      ops.failCopy = true;
      final image = await makeTestImage(root, 'src.jpg');

      final result = await artworks.create(
        childId: childId,
        sourceImageFile: image,
        addedAt: DateTime(2026, 1, 1),
      );

      expect(result, isA<ActionFailed<String>>());
      expect(
        (result as ActionFailed<String>).failure,
        isA<StorageFullFailure>(),
      );
      expect(await artworks.count(), 0);
      expect(filesUnder('artworks'), isEmpty);
      expect(await db.select(db.mediaVersionsTable).get(), isEmpty);
    });

    test(
      'an announced recording that is not there fails the whole save',
      () async {
        final childId = await newChild();
        final image = await makeTestImage(root, 'src.jpg');

        final result = await artworks.create(
          childId: childId,
          sourceImageFile: image,
          addedAt: DateTime(2026, 1, 1),
          sourceAudioFile: File(p.join(root.path, 'vanished.m4a')),
          audioDurationMs: 1000,
        );

        expect(
          (result as ActionFailed<String>).failure,
          isA<FileMissingFailure>(),
        );
        expect(await artworks.count(), 0);
        expect(filesUnder('artworks'), isEmpty);
      },
    );

    test(
      'the files are final before the row and the registry are written',
      () async {
        final childId = await newChild();
        final id = await newArtwork(
          childId,
          audio: await audioFile('rec.m4a', [1, 2, 3]),
        );

        final row = (await artworks.getById(id))!;
        expect(
          (await vault.resolveFile(row.relativeAudioPath!)).readAsBytesSync(),
          [1, 2, 3],
        );
        expect(row.relativeAudioPath, 'audio/$id/v1.m4a');
        final versions = await media.versionsOf(id);
        expect(
          versions.map((v) => (v.role, v.version, v.state, v.localPath)),
          unorderedEquals([
            (
              MediaRole.original,
              1,
              MediaVersionState.present,
              row.relativeImagePath,
            ),
            (MediaRole.audio, 1, MediaVersionState.present, 'audio/$id/v1.m4a'),
          ]),
        );
        expect(versions.every((v) => v.byteSize > 0), isTrue);
      },
    );
  });

  group('audio versions', () {
    test('a new recording is a new version, the old file stays', () async {
      final childId = await newChild();
      final id = await newArtwork(
        childId,
        audio: await audioFile('one.m4a', [1]),
      );

      await artworks.updateAudio(
        id: id,
        sourceAudioFile: await audioFile('two.m4a', [2, 2]),
        durationMs: 2000,
      );
      await artworks.updateAudio(
        id: id,
        sourceAudioFile: await audioFile('three.m4a', [3, 3, 3]),
        durationMs: 3000,
      );

      expect(
        filesUnder('audio').map((f) => p.relative(f.path, from: docs.path)),
        unorderedEquals([
          'audio/$id/v1.m4a',
          'audio/$id/v2.m4a',
          'audio/$id/v3.m4a',
        ]),
      );
      expect(
        (await artworks.getById(id))!.relativeAudioPath,
        'audio/$id/v3.m4a',
      );
      final audio = (await media.versionsOf(
        id,
      )).where((v) => v.role == MediaRole.audio);
      expect(audio.map((v) => v.version), [1, 2, 3]);
    });

    test('a full disk keeps the current recording', () async {
      final childId = await newChild();
      final id = await newArtwork(
        childId,
        audio: await audioFile('one.m4a', [1]),
      );
      ops.failCopy = true;

      final result = await artworks.updateAudio(
        id: id,
        sourceAudioFile: await audioFile('two.m4a', [2, 2]),
        durationMs: 2000,
      );

      expect((result as ActionFailed<void>).failure, isA<StorageFullFailure>());
      final row = (await artworks.getById(id))!;
      expect(row.relativeAudioPath, 'audio/$id/v1.m4a');
      expect(filesUnder('audio'), hasLength(1));
    });

    test('a missing source recording is a typed failure', () async {
      final childId = await newChild();
      final id = await newArtwork(childId);

      final result = await artworks.updateAudio(
        id: id,
        sourceAudioFile: File(p.join(root.path, 'gone.m4a')),
        durationMs: 1000,
      );

      expect((result as ActionFailed<void>).failure, isA<FileMissingFailure>());
      expect((await artworks.getById(id))!.relativeAudioPath, isNull);
    });
  });

  group('isMediaReferenced', () {
    test(
      'counts artworks, the trash, kept values and queued operations',
      () async {
        final childId = await newChild();
        final id = await newArtwork(
          childId,
          audio: await audioFile('one.m4a', [1]),
        );
        for (final n in [2, 3, 4]) {
          await artworks.updateAudio(
            id: id,
            sourceAudioFile: await audioFile('r$n.m4a', [n]),
            durationMs: 1000 * n,
          );
        }

        // v4 is the current recording; v1..v3 are replaced versions.
        expect(
          await media.isMediaReferenced(id, 4, role: MediaRole.audio),
          isTrue,
        );
        for (final v in [1, 2, 3]) {
          expect(
            await media.isMediaReferenced(id, v, role: MediaRole.audio),
            isFalse,
            reason: 'v$v is replaced and nothing points at it',
          );
        }

        // A value kept in the conflict history.
        await ReplacedValuesRepository(db).record(
          entityType: SyncEntityType.artwork,
          entityId: id,
          field: 'audio',
          value: {'mediaId': id, 'version': 1},
          mediaRef: MediaRef(mediaId: id, version: 1),
          source: ReplacedValueSource.remote,
        );
        expect(
          await media.isMediaReferenced(id, 1, role: MediaRole.audio),
          isTrue,
        );

        // An operation still in the outbox.
        final descriptor = MediaDescriptor(
          mediaId: id,
          version: 2,
          role: MediaRole.audio,
          format: MediaFormat.m4a,
          byteSize: 1,
          sha256: 'ab' * 32,
          durationMs: 2000,
        );
        // The creation operation (no patch) would absorb the new one.
        await db.delete(db.syncOutboxTable).go();
        await SyncOutboxRepository(db).enqueuePatch(
          EntityPatch(
            opId: '3f2c1a4e-8b7d-4c6e-9f10-2a3b4c5d6e11',
            entityType: SyncEntityType.artwork,
            entityId: id,
            baseRevisions: {'audio': 0},
            fields: {'audio': descriptor.ref.toJson()},
            media: [descriptor],
            createdAt: DateTime.utc(2026, 10, 1),
          ),
        );
        expect(
          await media.isMediaReferenced(id, 2, role: MediaRole.audio),
          isTrue,
        );
        expect(
          await media.isMediaReferenced(id, 3, role: MediaRole.audio),
          isFalse,
        );

        // The trash still holds its files.
        await DriftArtworksRepository(
          db,
          vault,
          deletionStrategy: ArtworkDeletionStrategy.localRecoverable,
        ).delete(id);
        final trashed = await db.select(db.artworksTable).getSingle();
        expect(trashed.deletedAt, isNotNull);
        expect(
          await media.isMediaReferenced(id, 4, role: MediaRole.audio),
          isTrue,
        );
        expect(
          await media.isMediaReferenced(id, 1, role: MediaRole.original),
          isTrue,
        );
      },
    );
  });

  group('reconcile', () {
    test('marks an absent file missing without touching the artwork', () async {
      final childId = await newChild();
      final id = await newArtwork(
        childId,
        audio: await audioFile('one.m4a', [1, 2]),
      );
      final before = (await artworks.getById(id))!;
      await File(p.join(docs.path, 'audio', id, 'v1.m4a')).delete();

      expect(await media.reconcile(vault), 1);

      final audio = (await media.versionsOf(
        id,
      )).singleWhere((v) => v.role == MediaRole.audio);
      expect(audio.state, MediaVersionState.missing);
      final after = (await artworks.getById(id))!;
      expect(after.relativeAudioPath, before.relativeAudioPath);
      expect(after.audioDurationMs, before.audioDurationMs);
      expect(await artworks.count(), 1);

      // The file comes back (restored backup): present again.
      File(p.join(docs.path, 'audio', id, 'v1.m4a')).writeAsBytesSync([1, 2]);
      expect(await media.reconcile(vault), 1);
      expect(
        (await media.versionsOf(
          id,
        )).singleWhere((v) => v.role == MediaRole.audio).state,
        MediaVersionState.present,
      );
    });
  });
}
