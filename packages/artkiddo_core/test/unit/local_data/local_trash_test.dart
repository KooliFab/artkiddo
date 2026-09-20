import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:artkiddo_core/src/local/database/app_database.dart';
import 'package:artkiddo_core/src/contracts/trash.dart';
import 'package:artkiddo_core/src/domain/action_result.dart';
import 'package:artkiddo_core/src/local/storage/local_vault.dart';
import 'package:artkiddo_core/src/local/repositories/children_repository.dart';
import 'package:artkiddo_core/src/local/repositories/local_trash_repository.dart';
import 'package:artkiddo_core/src/local/repositories/artworks_repository.dart';
import 'package:artkiddo_core/src/sync/sync_outbox.dart';

void main() {
  late Directory root;
  late AppDatabase db;
  late LocalVault vault;
  late DriftChildrenRepository children;
  late DriftArtworksRepository artworks;
  late LocalTrashRepository trash;

  final clock = DateTime.utc(2026, 9, 11, 12);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('artkiddo_local_trash_');
    db = AppDatabase.forTesting(
      NativeDatabase(File(p.join(root.path, 'artkiddo.sqlite'))),
    );
    vault = LocalVault(
      documentsDirProvider: () async => Directory(p.join(root.path, 'docs')),
    );
    final outbox = SyncOutboxRepository(db);
    children = DriftChildrenRepository(db, vault, outbox: outbox);
    artworks = DriftArtworksRepository(
      db,
      vault,
      outbox: outbox,
      deletionStrategy: ArtworkDeletionStrategy.localRecoverable,
      now: () => clock,
    );
    trash = LocalTrashRepository(db, vault, now: () => clock);
  });

  tearDown(() async {
    await db.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<String> createArtwork({DateTime? addedAt}) async {
    final childId =
        (await children.create(name: 'Lou', birthDate: DateTime(2020, 1, 1))
                as ActionSuccess<String>)
            .value;
    final source = File(p.join(root.path, 'source-${addedAt?.day ?? 1}.jpg'))
      ..writeAsStringSync('image bytes');
    return (await artworks.create(
              childId: childId,
              sourceImageFile: source,
              addedAt: addedAt ?? clock,
            )
            as ActionSuccess<String>)
        .value;
  }

  test(
    'local delete is recoverable, active reads exclude it, and restore is idempotent',
    () async {
      final id = await createArtwork();
      final before = await artworks.getById(id);
      final imageFile = await vault.resolveFile(before!.relativeImagePath!);

      expect(await artworks.count(), 1);
      final deletion = await artworks.delete(id);
      expect(
        deletion,
        isA<ActionSuccess<void>>(),
        reason: deletion is ActionFailed<void>
            ? 'failure=${deletion.failure.runtimeType} cause=${deletion.failure.cause}'
            : null,
      );
      expect(await artworks.getById(id), isNull);
      expect(await artworks.count(), 0);
      expect(await imageFile.exists(), isTrue, reason: 'trash keeps files');

      final rows = await (db.select(
        db.artworksTable,
      )..where((t) => t.id.equals(id))).get();
      expect(rows.single.deletedAt!.isAtSameMomentAs(clock), isTrue);

      final listed = await trash.listTrash();
      expect(listed, isA<ActionSuccess<List<TrashedArtwork>>>());
      final item = (listed as ActionSuccess<List<TrashedArtwork>>).value.single;
      expect(item.id, id);
      expect(
        item.purgeAt.isAtSameMomentAs(
          clock.add(LocalTrashRepository.retention),
        ),
        isTrue,
      );

      expect(await trash.restore(id), isA<ActionSuccess<void>>());
      expect((await artworks.getById(id))!.id, id);
      expect(await trash.restore(id), isA<ActionSuccess<void>>());
      expect(await imageFile.exists(), isTrue);
    },
  );

  test(
    'purge removes the row and all files, and repeated purge is a no-op',
    () async {
      final id = await createArtwork();
      final before = await artworks.getById(id);
      final imageFile = await vault.resolveFile(before!.relativeImagePath!);
      await artworks.delete(id);

      expect(await trash.purge(id), isA<ActionSuccess<void>>());
      expect(await trash.purge(id), isA<ActionSuccess<void>>());
      expect(await artworks.getById(id), isNull);
      expect(await imageFile.exists(), isFalse);
      expect((await trash.listTrash() as ActionSuccess).value, isEmpty);
    },
  );

  test(
    'purgeAll removes every trashed artwork without a family scope',
    () async {
      final first = await createArtwork();
      final second = await createArtwork(
        addedAt: clock.add(const Duration(days: 1)),
      );
      await artworks.delete(first);
      await artworks.delete(second);

      expect(await trash.purgeAll(), isA<ActionSuccess<void>>());
      expect((await trash.listTrash() as ActionSuccess).value, isEmpty);
      final rows = await db.select(db.artworksTable).get();
      expect(rows.where((row) => row.id == first || row.id == second), isEmpty);
    },
  );

  test(
    'automatic purge uses the injected clock and preserves newer items',
    () async {
      final oldId = await createArtwork();
      final newId = await createArtwork(
        addedAt: clock.add(const Duration(days: 1)),
      );
      await artworks.delete(oldId);
      await artworks.delete(newId);

      await (db.update(
        db.artworksTable,
      )..where((t) => t.id.equals(oldId))).write(
        ArtworksTableCompanion(
          deletedAt: Value(clock.subtract(const Duration(days: 31))),
        ),
      );

      final result = await trash.purgeExpired();
      expect(result, isA<ActionSuccess<int>>());
      expect((result as ActionSuccess<int>).value, 1);
      expect(
        await trash.listTrash(),
        isA<ActionSuccess<List<TrashedArtwork>>>(),
      );
      final remaining =
          (await trash.listTrash() as ActionSuccess<List<TrashedArtwork>>)
              .value;
      expect(remaining.map((item) => item.id), [newId]);
    },
  );

  test('deleteAllPhotos clears database records and local photos', () async {
    final id = await createArtwork();
    final artwork = await artworks.getById(id);
    final photo = await vault.resolveFile(artwork!.relativeImagePath!);
    expect(await photo.exists(), isTrue);

    final result = await artworks.deleteAllPhotos();
    expect(result, isA<ActionSuccess<int>>());
    expect((result as ActionSuccess<int>).value, equals(1));

    final count = await (db.select(db.artworksTable)).get();
    expect(count, isEmpty);
    expect(await photo.exists(), isFalse);
  });
}
