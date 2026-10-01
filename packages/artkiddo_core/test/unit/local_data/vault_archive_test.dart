// Complete export and import: `manifest.json` + `media/…`, import in a
// temporary directory first, never an overwrite (INV-13).

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:artkiddo_core/src/contracts/sync_protocol.dart';
import 'package:artkiddo_core/src/domain/action_result.dart';
import 'package:artkiddo_core/src/local/database/app_database.dart';
import 'package:artkiddo_core/src/local/repositories/artworks_repository.dart';
import 'package:artkiddo_core/src/local/repositories/children_repository.dart';
import 'package:artkiddo_core/src/local/storage/atomic_file.dart';
import 'package:artkiddo_core/src/local/storage/local_vault.dart';
import 'package:artkiddo_core/src/local/storage/media_versions.dart';
import 'package:artkiddo_core/src/local/storage/vault_archive_export.dart';
import 'package:artkiddo_core/src/local/storage/vault_archive_import.dart';
import 'package:artkiddo_core/src/local/storage/vault_archive_manifest.dart';
import 'package:artkiddo_core/src/local/storage/vault_rescue_export.dart'
    show RescueExportInsufficientSpaceException;
import 'package:artkiddo_core/src/sync/replaced_values.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../sync/sync_engine_test.dart' show makeTestImage;

/// One device: its own vault folder, database and temporary directory.
class Device {
  final Directory root;
  final Directory docs;
  final Directory tmp;
  final AppDatabase db;
  final LocalVault vault;
  final DriftChildrenRepository children;
  final DriftArtworksRepository artworks;

  Device._(
    this.root,
    this.docs,
    this.tmp,
    this.db,
    this.vault,
    this.children,
    this.artworks,
  );

  static Future<Device> create(String name, {VaultFileOps? ops}) async {
    final root = await Directory.systemTemp.createTemp('artkiddo_$name');
    final docs = Directory(p.join(root.path, 'docs'))..createSync();
    final tmp = Directory(p.join(root.path, 'tmp'))..createSync();
    final db = AppDatabase.forTesting(
      NativeDatabase(File(p.join(root.path, 'db.sqlite'))),
    );
    final vault = LocalVault(
      documentsDirProvider: () async => docs,
      fileOps: ops,
    );
    return Device._(
      root,
      docs,
      tmp,
      db,
      vault,
      DriftChildrenRepository(db, vault),
      DriftArtworksRepository(db, vault),
    );
  }

  Future<void> close() async {
    await db.close();
    if (await root.exists()) await root.delete(recursive: true);
  }

  VaultArchiveExporter exporter({
    ArchiveShare? share,
    ArchiveAvailableSpace? availableSpace,
  }) => VaultArchiveExporter(
    db,
    vault,
    appVersion: '1.0.0+test',
    now: () => DateTime.utc(2026, 10, 1, 12),
    temporaryDirectoryProvider: () async => tmp,
    availableSpace: availableSpace ?? (_) async => null,
    share: share ?? (_) async {},
  );

  VaultArchiveImporter importer() => VaultArchiveImporter(
    db,
    vault,
    temporaryDirectoryProvider: () async => tmp,
    fileOps: _ops,
  );

  VaultFileOps get _ops => const DiskVaultFileOps();

  /// Every file of the vault with its size.
  List<String> vaultFiles() {
    final files = <String>[];
    for (final entity in docs.listSync(recursive: true)) {
      if (entity is File) {
        files.add(
          '${p.relative(entity.path, from: docs.path)}:${entity.lengthSync()}',
        );
      }
    }
    return files..sort();
  }

  /// Rows of every table an import may touch, plus the vault files.
  Future<String> snapshot() async {
    final children = await db.select(db.childrenTable).get();
    final artworks = await db.select(db.artworksTable).get();
    final versions = await db.select(db.mediaVersionsTable).get();
    final replaced = await db.select(db.replacedValuesTable).get();
    final outbox = await db.select(db.syncOutboxTable).get();
    return jsonEncode({
      'children': children.map((r) => r.toJson()).toList(),
      'artworks': artworks.map((r) => r.toJson()).toList(),
      'versions': versions.map((r) => r.toJson()).toList(),
      'replaced': replaced.map((r) => r.toJson()).toList(),
      'outbox': outbox.map((r) => r.toJson()).toList(),
      'files': vaultFiles(),
    });
  }
}

/// Fails the Nth copy into the vault: a full disk in the middle of an import.
class FailingCopyOps extends DiskVaultFileOps {
  final int failOnCopy;
  int copies = 0;

  FailingCopyOps(this.failOnCopy);

  @override
  Future<void> copy(File source, File dest) async {
    copies++;
    if (copies == failOnCopy) {
      throw const FileSystemException('No space left on device');
    }
    await super.copy(source, dest);
  }
}

const _childId = '11111111-1111-4111-8111-111111111111';
const _artId = '22222222-2222-4222-8222-222222222222';

String _sha(List<int> bytes) => crypto.sha256.convert(bytes).toString();

Future<File> _archive(Directory dir, Map<String, List<int>> entries) async {
  final archive = Archive();
  entries.forEach((name, data) => archive.add(ArchiveFile.bytes(name, data)));
  final file = File(p.join(dir.path, 'crafted-${entries.length}.zip'));
  await file.writeAsBytes(ZipEncoder().encode(archive));
  return file;
}

Map<String, Object?> _manifestJson({
  int formatVersion = 1,
  List<Map<String, Object?>> media = const [],
}) => {
  'formatVersion': formatVersion,
  'exportedAt': '2026-10-01T12:00:00.000Z',
  'appVersion': '1.0.0+test',
  'partial': false,
  'missing': <Object?>[],
  'children': [
    {
      'id': _childId,
      'name': 'Léa',
      'birthDate': '2019-03-01',
      'createdAt': '2026-01-01T00:00:00.000Z',
      'updatedAt': '2026-01-01T00:00:00.000Z',
    },
  ],
  'artworks': [
    {'id': _artId, 'childId': _childId, 'addedAt': '2026-02-01T00:00:00.000Z'},
  ],
  'media': media,
};

Map<String, Object?> _mediaJson(
  List<int> bytes, {
  String path = 'media/$_artId/original-v1.jpg',
}) => {
  'mediaId': _artId,
  'version': 1,
  'role': 'original',
  'sha256': _sha(bytes),
  'byteSize': bytes.length,
  'path': path,
  'quality': 'original',
};

void main() {
  late Device source;
  late Device target;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() async {
    source = await Device.create('source');
    target = await Device.create('target');
  });

  tearDown(() async {
    await source.close();
    await target.close();
  });

  Future<String> addChild(Device d, String name, DateTime birth) async =>
      (await d.children.create(name: name, birthDate: birth)
              as ActionSuccess<String>)
          .value;

  Future<String> addArtwork(
    Device d,
    String childId,
    String imageName, {
    String? story,
    DateTime? drawnAt,
    List<int>? audio,
  }) async {
    final image = await makeTestImage(d.root, imageName);
    File? audioFile;
    if (audio != null) {
      audioFile = File(p.join(d.root.path, '$imageName.m4a'))
        ..writeAsBytesSync(audio);
    }
    final id =
        (await d.artworks.create(
                  childId: childId,
                  sourceImageFile: image,
                  addedAt: DateTime.utc(2026, 2, 1),
                  drawnAt: drawnAt,
                  story: story,
                  sourceAudioFile: audioFile,
                  audioDurationMs: audio == null ? null : 1500,
                )
                as ActionSuccess<String>)
            .value;
    await d.artworks.ensureDerivatives(id);
    return id;
  }

  /// Two children, three artworks (one with a voice, one in the trash).
  Future<({String lea, String noe, String a1, String a2, String a3})> seed(
    Device d,
  ) async {
    final lea = await addChild(d, 'Léa', DateTime(2019, 3, 1));
    final noe = await addChild(d, 'Noé', DateTime(2021, 7, 15));
    final a1 = await addArtwork(
      d,
      lea,
      'one.jpg',
      story: 'Un dragon vert',
      drawnAt: DateTime(2026, 1, 20),
      audio: List.generate(300, (i) => i % 251),
    );
    final a2 = await addArtwork(d, lea, 'two.jpg');
    final a3 = await addArtwork(d, noe, 'three.jpg', story: 'Un chat');
    await d.artworks.delete(a3);
    return (lea: lea, noe: noe, a1: a1, a2: a2, a3: a3);
  }

  Future<VaultArchiveManifest> manifestOf(File archive) async {
    final zip = ZipDecoder().decodeBytes(await archive.readAsBytes());
    final entry = zip.files.firstWhere((f) => f.name == 'manifest.json');
    return VaultArchiveManifest.decode(utf8.decode(entry.readBytes()!));
  }

  Future<List<int>> originalBytes(Device d, String artworkId) async {
    final row = await (d.db.select(
      d.db.artworksTable,
    )..where((t) => t.id.equals(artworkId))).getSingle();
    return (await d.vault.resolveFile(row.relativeImagePath!)).readAsBytes();
  }

  group('export → import on an empty vault', () {
    test('restores the data and the exact bytes', () async {
      final ids = await seed(source);
      final export = await source.exporter().exportArchive();
      expect(export.isPartial, isFalse);
      expect(export.childCount, 2);
      expect(export.artworkCount, 3);
      // Three originals and one voice.
      expect(export.mediaCount, 4);

      final manifest = await manifestOf(export.archive);
      expect(manifest.formatVersion, 1);
      expect(manifest.partial, isFalse);
      expect(manifest.missing, isEmpty);
      expect(
        manifest.artworks.firstWhere((a) => a.id == ids.a3).isTrashed,
        isTrue,
      );
      for (final entry in manifest.media) {
        expect(entry.sha256, hasLength(64));
      }

      final result = await target.importer().importArchive(export.archive);
      expect(result.addedChildren, 2);
      expect(result.addedArtworks, 3);
      expect(result.keptAside, 0);

      final names = (await target.db.select(target.db.childrenTable).get())
          .map((c) => c.name)
          .toSet();
      expect(names, {'Léa', 'Noé'});
      final lea = await target.children.getById(ids.lea);
      expect(lea!.birthDate, DateTime(2019, 3, 1));

      for (final id in [ids.a1, ids.a2, ids.a3]) {
        final fromSource = await (source.db.select(
          source.db.artworksTable,
        )..where((t) => t.id.equals(id))).getSingle();
        final fromTarget = await (target.db.select(
          target.db.artworksTable,
        )..where((t) => t.id.equals(id))).getSingle();
        expect(fromTarget.childId, fromSource.childId);
        expect(fromTarget.story, fromSource.story);
        expect(fromTarget.drawnAt, fromSource.drawnAt);
        expect(fromTarget.addedAt, fromSource.addedAt);
        expect(fromTarget.deletedAt == null, fromSource.deletedAt == null);
        expect(
          await originalBytes(target, id),
          await originalBytes(source, id),
        );
      }

      // The voice is the very same file.
      final audioSource = await (source.db.select(
        source.db.artworksTable,
      )..where((t) => t.id.equals(ids.a1))).getSingle();
      final audioTarget = await (target.db.select(
        target.db.artworksTable,
      )..where((t) => t.id.equals(ids.a1))).getSingle();
      expect(audioTarget.relativeAudioPath, isNotNull);
      expect(
        await (await target.vault.resolveFile(
          audioTarget.relativeAudioPath!,
        )).readAsBytes(),
        await (await source.vault.resolveFile(
          audioSource.relativeAudioPath!,
        )).readAsBytes(),
      );
      expect(audioTarget.audioDurationMs, audioSource.audioDurationMs);

      // INV-13: every manifest media is present locally and registered.
      for (final entry in manifest.media) {
        final versions = await MediaVersionsRepository(
          target.db,
        ).versionsOf(entry.mediaId);
        final registered = versions.where((v) => v.role == entry.role);
        expect(registered, isNotEmpty, reason: entry.path);
        expect(
          await (await target.vault.resolveFile(
            registered.first.localPath,
          )).exists(),
          isTrue,
        );
      }
      // The import left no temporary file behind.
      expect(target.tmp.listSync(), isEmpty);
      expect(target.vaultFiles().where((f) => f.contains('.tmp')), isEmpty);
    });

    test('imported rows are queued like new ones', () async {
      await seed(source);
      final export = await source.exporter().exportArchive();
      await target.importer().importArchive(export.archive);
      final entities = (await target.db.select(target.db.syncOutboxTable).get())
          .map((o) => o.entity)
          .toSet();
      expect(entities, {'child', 'artwork'});
    });

    test('re-importing the same archive changes nothing', () async {
      await seed(source);
      final export = await source.exporter().exportArchive();
      await target.importer().importArchive(export.archive);
      final before = await target.snapshot();

      final again = await target.importer().importArchive(export.archive);

      expect(again.changedAnything, isFalse);
      expect(again.unchanged, 5);
      expect(await target.snapshot(), before);
    });

    test('importing on the device that made it changes nothing', () async {
      await seed(source);
      final export = await source.exporter().exportArchive();
      final before = await source.snapshot();

      final result = await source.importer().importArchive(export.archive);

      expect(result.changedAnything, isFalse);
      expect(await source.snapshot(), before);
    });
  });

  group('partial archive', () {
    test('a missing original falls back to the optimized copy', () async {
      final ids = await seed(source);
      final row = await (source.db.select(
        source.db.artworksTable,
      )..where((t) => t.id.equals(ids.a2))).getSingle();
      await (await source.vault.resolveFile(row.relativeImagePath!)).delete();

      final export = await source.exporter().exportArchive();

      expect(export.isPartial, isTrue);
      expect(export.missing.single.mediaId, ids.a2);
      expect(export.missing.single.role, MediaRole.original);
      final manifest = await manifestOf(export.archive);
      expect(manifest.partial, isTrue);
      expect(manifest.missing.single.path, row.relativeImagePath);
      final photo = manifest.media.firstWhere(
        (m) => m.mediaId == ids.a2 && m.role != MediaRole.audio,
      );
      expect(photo.quality, ArchiveQuality.optimized);
      expect(photo.role, MediaRole.optimized);

      await target.importer().importArchive(export.archive);
      final imported = await (target.db.select(
        target.db.artworksTable,
      )..where((t) => t.id.equals(ids.a2))).getSingle();
      expect(imported.relativeImagePath, isNull);
      expect(imported.displayImagePath, isNotNull);
      expect(
        await (await target.vault.resolveFile(
          imported.displayImagePath!,
        )).exists(),
        isTrue,
      );
    });

    test(
      'a file missing everywhere is listed, the export still works',
      () async {
        final ids = await seed(source);
        final row = await (source.db.select(
          source.db.artworksTable,
        )..where((t) => t.id.equals(ids.a1))).getSingle();
        await (await source.vault.resolveFile(row.relativeAudioPath!)).delete();

        final export = await source.exporter().exportArchive();

        expect(export.isPartial, isTrue);
        expect(export.missing.single.role, MediaRole.audio);
        final result = await target.importer().importArchive(export.archive);
        expect(result.addedArtworks, 3);
      },
    );
  });

  group('a refused archive writes nothing', () {
    Future<void> expectRefused(
      File archive,
      VaultArchiveFailure failure,
    ) async {
      final before = await target.snapshot();
      await expectLater(
        target.importer().importArchive(archive),
        throwsA(
          isA<VaultArchiveImportException>().having(
            (e) => e.failure,
            'failure',
            failure,
          ),
        ),
      );
      expect(await target.snapshot(), before);
      expect(target.tmp.listSync(), isEmpty);
    }

    final bytes = utf8.encode('photo-bytes');

    test('a valid hand-made archive imports (control)', () async {
      final archive = await _archive(target.root, {
        'manifest.json': utf8.encode(
          jsonEncode(_manifestJson(media: [_mediaJson(bytes)])),
        ),
        'media/$_artId/original-v1.jpg': bytes,
      });
      final result = await target.importer().importArchive(archive);
      expect(result.addedArtworks, 1);
      expect(await originalBytes(target, _artId), bytes);
    });

    test('not a ZIP', () async {
      final file = File(p.join(target.root.path, 'notes.zip'))
        ..writeAsStringSync('this is not a zip');
      await expectRefused(file, VaultArchiveFailure.notAnArchive);
    });

    test('a ZIP without manifest', () async {
      final archive = await _archive(target.root, {'hello.txt': bytes});
      await expectRefused(archive, VaultArchiveFailure.notAnArchive);
    });

    test('unknown formatVersion', () async {
      final archive = await _archive(target.root, {
        'manifest.json': utf8.encode(
          jsonEncode(_manifestJson(formatVersion: 2)),
        ),
      });
      await expectRefused(archive, VaultArchiveFailure.unsupportedVersion);
    });

    test('a wrong SHA-256', () async {
      final media = _mediaJson(bytes)..['sha256'] = _sha(utf8.encode('other'));
      final archive = await _archive(target.root, {
        'manifest.json': utf8.encode(jsonEncode(_manifestJson(media: [media]))),
        'media/$_artId/original-v1.jpg': bytes,
      });
      await expectRefused(archive, VaultArchiveFailure.corruptedMedia);
    });

    test('a wrong size', () async {
      final media = _mediaJson(bytes)..['byteSize'] = bytes.length + 5;
      final archive = await _archive(target.root, {
        'manifest.json': utf8.encode(jsonEncode(_manifestJson(media: [media]))),
        'media/$_artId/original-v1.jpg': bytes,
      });
      await expectRefused(archive, VaultArchiveFailure.corruptedMedia);
    });

    test('a file listed but absent from the archive', () async {
      final archive = await _archive(target.root, {
        'manifest.json': utf8.encode(
          jsonEncode(_manifestJson(media: [_mediaJson(bytes)])),
        ),
      });
      await expectRefused(archive, VaultArchiveFailure.corruptedMedia);
    });

    test('zip-slip: an entry that climbs out of the archive', () async {
      final archive = await _archive(target.root, {
        'manifest.json': utf8.encode(jsonEncode(_manifestJson())),
        '../evil.txt': bytes,
      });
      await expectRefused(archive, VaultArchiveFailure.invalidManifest);
      expect(File(p.join(target.root.path, 'evil.txt')).existsSync(), isFalse);
      expect(
        File(p.join(target.root.parent.path, 'evil.txt')).existsSync(),
        isFalse,
      );
    });

    test('zip-slip: a manifest path with ..', () async {
      final media = _mediaJson(bytes, path: 'media/../../evil.jpg');
      final archive = await _archive(target.root, {
        'manifest.json': utf8.encode(jsonEncode(_manifestJson(media: [media]))),
        'media/x.jpg': bytes,
      });
      await expectRefused(archive, VaultArchiveFailure.invalidManifest);
    });

    test('an absolute path in the manifest or the entries', () async {
      final media = _mediaJson(bytes, path: '/etc/evil.jpg');
      await expectRefused(
        await _archive(target.root, {
          'manifest.json': utf8.encode(
            jsonEncode(_manifestJson(media: [media])),
          ),
        }),
        VaultArchiveFailure.invalidManifest,
      );
      await expectRefused(
        await _archive(target.root, {
          'manifest.json': utf8.encode(jsonEncode(_manifestJson())),
          '/abs/evil.jpg': bytes,
        }),
        VaultArchiveFailure.invalidManifest,
      );
    });

    test('an id that could build a path outside the vault', () async {
      final manifest = _manifestJson();
      ((manifest['artworks']! as List).first as Map)['id'] = '../escape';
      final archive = await _archive(target.root, {
        'manifest.json': utf8.encode(jsonEncode(manifest)),
      });
      await expectRefused(archive, VaultArchiveFailure.invalidManifest);
    });

    test('an artwork of an unknown child', () async {
      final manifest = _manifestJson();
      ((manifest['artworks']! as List).first as Map)['childId'] = 'ghost';
      final archive = await _archive(target.root, {
        'manifest.json': utf8.encode(jsonEncode(manifest)),
      });
      await expectRefused(archive, VaultArchiveFailure.invalidManifest);
    });

    test('one corrupted file among valid ones imports nothing', () async {
      await seed(source);
      final export = await source.exporter().exportArchive();
      final zip = ZipDecoder().decodeBytes(await export.archive.readAsBytes());
      final entries = <String, List<int>>{
        for (final f in zip.files) f.name: f.readBytes()!,
      };
      final victim = entries.keys.lastWhere((n) => n.startsWith('media/'));
      entries[victim] = [...entries[victim]!]..[0] ^= 0xff;
      await expectRefused(
        await _archive(target.root, entries),
        VaultArchiveFailure.corruptedMedia,
      );
    });

    test('a full disk in the middle of the application rolls back', () async {
      await seed(source);
      final export = await source.exporter().exportArchive();
      final failing = await Device.create('failing', ops: FailingCopyOps(3));
      addTearDown(failing.close);
      final importer = VaultArchiveImporter(
        failing.db,
        failing.vault,
        temporaryDirectoryProvider: () async => failing.tmp,
        fileOps: FailingCopyOps(3),
      );

      await expectLater(
        importer.importArchive(export.archive),
        throwsA(isA<FileSystemException>()),
      );

      expect(await failing.db.select(failing.db.childrenTable).get(), isEmpty);
      expect(await failing.db.select(failing.db.artworksTable).get(), isEmpty);
      expect(
        await failing.db.select(failing.db.syncOutboxTable).get(),
        isEmpty,
      );
      expect(failing.vaultFiles(), isEmpty);
    });
  });

  group('divergence: nothing local is overwritten', () {
    test('local values stay, imported ones go to replaced_values', () async {
      final ids = await seed(source);
      final export = await source.exporter().exportArchive();
      await target.importer().importArchive(export.archive);

      // The target edits while the archive keeps the earlier values.
      await target.children.update(
        id: ids.lea,
        name: 'Léa-Rose',
        birthDate: DateTime(2019, 3, 1),
      );
      await target.artworks.updateStory(id: ids.a1, story: 'Un dragon rouge');
      await target.artworks.updateDrawnAt(
        id: ids.a1,
        drawnAt: DateTime(2026, 2, 2),
      );
      final newVoice = File(p.join(target.root.path, 'new.m4a'))
        ..writeAsBytesSync(List.filled(40, 7));
      await target.artworks.updateAudio(
        id: ids.a1,
        sourceAudioFile: newVoice,
        durationMs: 900,
      );
      final localAudio = (await (target.db.select(
        target.db.artworksTable,
      )..where((t) => t.id.equals(ids.a1))).getSingle()).relativeAudioPath!;
      final localAudioBytes = await (await target.vault.resolveFile(
        localAudio,
      )).readAsBytes();

      final result = await target.importer().importArchive(export.archive);

      expect(result.addedChildren + result.addedArtworks, 0);
      // name, story, drawnAt, audio.
      expect(result.keptAside, 4);

      final lea = await target.children.getById(ids.lea);
      expect(lea!.name, 'Léa-Rose');
      final story = await (target.db.select(
        target.db.artworksTable,
      )..where((t) => t.id.equals(ids.a1))).getSingle();
      expect(story.story, 'Un dragon rouge');
      expect(story.drawnAt, DateTime(2026, 2, 2));
      expect(story.relativeAudioPath, localAudio);
      expect(
        await (await target.vault.resolveFile(localAudio)).readAsBytes(),
        localAudioBytes,
      );

      final repo = ReplacedValuesRepository(target.db);
      final childHistory = await repo.listReplacedValues(ids.lea);
      expect(childHistory.map((v) => (v.field, v.value)), [('name', 'Léa')]);
      final artworkHistory = await repo.listReplacedValues(ids.a1);
      expect(
        artworkHistory
            .where((v) => v.field != 'audio')
            .map((v) => (v.field, v.value))
            .toSet(),
        {('story', 'Un dragon vert'), ('drawnAt', '2026-01-20')},
      );

      // The imported voice is kept as a version of its own and cannot be
      // deleted while the history names it.
      final audioEntry = artworkHistory.singleWhere((v) => v.field == 'audio');
      final ref = audioEntry.mediaRef!;
      expect(
        await MediaVersionsRepository(
          target.db,
        ).isMediaReferenced(ref.mediaId, ref.version, role: MediaRole.audio),
        isTrue,
      );
      final kept = (await MediaVersionsRepository(target.db).versionsOf(ids.a1))
          .singleWhere(
            (v) => v.version == ref.version && v.role == MediaRole.audio,
          );
      expect(
        await (await target.vault.resolveFile(kept.localPath)).readAsBytes(),
        await (await source.vault.resolveFile(
          (await (source.db.select(
            source.db.artworksTable,
          )..where((t) => t.id.equals(ids.a1))).getSingle()).relativeAudioPath!,
        )).readAsBytes(),
      );

      // A second import of the same archive has nothing new to say.
      final before = await target.snapshot();
      final again = await target.importer().importArchive(export.archive);
      expect(again.changedAnything, isFalse);
      expect(await target.snapshot(), before);
    });

    test(
      'a trashed artwork is not resurrected, an active one not trashed',
      () async {
        final ids = await seed(source);
        final export = await source.exporter().exportArchive();
        await target.importer().importArchive(export.archive);
        await target.artworks.delete(
          ids.a2,
        ); // trashed here, active in the archive
        // Restored here, trashed in the archive.
        await (target.db.update(target.db.artworksTable)
              ..where((t) => t.id.equals(ids.a3)))
            .write(const ArtworksTableCompanion(deletedAt: Value(null)));

        final result = await target.importer().importArchive(export.archive);

        expect(result.keptAside, 2);
        final rows = {
          for (final r in await target.db.select(target.db.artworksTable).get())
            r.id: r,
        };
        expect(rows[ids.a2]!.deletedAt, isNotNull);
        expect(rows[ids.a3]!.deletedAt, isNull);
        final history = await ReplacedValuesRepository(
          target.db,
        ).listReplacedValues(ids.a2);
        expect(history.single.value, 'active');
      },
    );

    test('a different original is kept next to the local one', () async {
      final ids = await seed(source);
      final export = await source.exporter().exportArchive();
      await target.importer().importArchive(export.archive);
      final row = await (target.db.select(
        target.db.artworksTable,
      )..where((t) => t.id.equals(ids.a2))).getSingle();
      final localFile = await target.vault.resolveFile(row.relativeImagePath!);
      await localFile.writeAsBytes([9, 9, 9]);

      final result = await target.importer().importArchive(export.archive);

      expect(result.keptAside, 1);
      expect(await localFile.readAsBytes(), [9, 9, 9]);
      final history = await ReplacedValuesRepository(
        target.db,
      ).listReplacedValues(ids.a2);
      final ref = history.single.mediaRef!;
      final kept = (await MediaVersionsRepository(target.db).versionsOf(ids.a2))
          .singleWhere(
            (v) => v.version == ref.version && v.role == MediaRole.original,
          );
      expect(
        await (await target.vault.resolveFile(kept.localPath)).readAsBytes(),
        await originalBytes(source, ids.a2),
      );
    });

    test('a missing local file is given back at its own path', () async {
      final ids = await seed(source);
      final export = await source.exporter().exportArchive();
      await target.importer().importArchive(export.archive);
      final row = await (target.db.select(
        target.db.artworksTable,
      )..where((t) => t.id.equals(ids.a2))).getSingle();
      final file = await target.vault.resolveFile(row.relativeImagePath!);
      await file.delete();
      await MediaVersionsRepository(target.db).reconcile(target.vault);

      final result = await target.importer().importArchive(export.archive);

      expect(result.filesWritten, 1);
      expect(result.keptAside, 0);
      expect(await file.readAsBytes(), await originalBytes(source, ids.a2));
      final versions = await MediaVersionsRepository(
        target.db,
      ).versionsOf(ids.a2);
      expect(
        versions.where((v) => v.role == MediaRole.original).single.state,
        MediaVersionState.present,
      );
    });
  });

  group('no secret in the archive', () {
    test('the manifest holds no token, key or session identifier', () async {
      final ids = await seed(source);
      // Fill every column a secret could sit in.
      await source.db.customStatement(
        "UPDATE artworks SET audio_object_key = 'SECRET-OBJECT-KEY', "
        "display_object_key = 'SECRET-DISPLAY-KEY', "
        "thumbnail_object_key = 'SECRET-THUMB-KEY', "
        "added_by = 'SECRET-USER-ID' WHERE id = '${ids.a1}'",
      );
      await source.db.customStatement(
        "UPDATE sync_outbox SET last_error = 'SECRET-BEARER-TOKEN'",
      );

      final export = await source.exporter().exportArchive();
      final zip = ZipDecoder().decodeBytes(await export.archive.readAsBytes());
      final text = utf8.decode(
        zip.files.firstWhere((f) => f.name == 'manifest.json').readBytes()!,
      );

      expect(text, isNot(contains('SECRET')));
      final json = jsonDecode(text) as Map<String, Object?>;
      final keys = <String>{};
      void collect(Object? node) {
        if (node is Map) {
          for (final entry in node.entries) {
            keys.add(entry.key as String);
            collect(entry.value);
          }
        } else if (node is List) {
          node.forEach(collect);
        }
      }

      collect(json);
      const allowed = {
        'formatVersion',
        'exportedAt',
        'appVersion',
        'partial',
        'missing',
        'children',
        'artworks',
        'media',
        'id',
        'name',
        'birthDate',
        'createdAt',
        'updatedAt',
        'deletedAt',
        'childId',
        'addedAt',
        'drawnAt',
        'story',
        'imageWidth',
        'imageHeight',
        'audioDurationMs',
        'mediaId',
        'version',
        'role',
        'sha256',
        'byteSize',
        'path',
        'quality',
      };
      expect(keys.difference(allowed), isEmpty);
      final sensitive = RegExp(
        'token|secret|session|jwt|password|authorization|bearer|apikey|'
        'objectkey|accesskey|email|userid|addedby',
        caseSensitive: false,
      );
      expect(keys.where(sensitive.hasMatch), isEmpty);
    });
  });

  group('exporter', () {
    test('shareArchive hands the archive to the share sheet', () async {
      await seed(source);
      File? shared;
      final export = await source
          .exporter(share: (file) async => shared = file)
          .shareArchive();
      expect(shared?.path, export.archive.path);
      expect(await shared!.exists(), isTrue);
    });

    test('too little space stops before anything is written', () async {
      await seed(source);
      await expectLater(
        source.exporter(availableSpace: (_) async => 10).exportArchive(),
        throwsA(isA<RescueExportInsufficientSpaceException>()),
      );
      expect(source.tmp.listSync(), isEmpty);
    });

    test('an empty vault exports a valid archive', () async {
      final export = await source.exporter().exportArchive();
      final manifest = await manifestOf(export.archive);
      expect(manifest.children, isEmpty);
      expect(manifest.media, isEmpty);
      expect(manifest.partial, isFalse);
    });
  });
}
