import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:artkiddo_core/src/local/database/app_database.dart';
import 'package:artkiddo_core/src/contracts/trash.dart';
import 'package:artkiddo_core/src/domain/action_result.dart';
import 'package:artkiddo_core/src/local/storage/local_vault.dart';
import 'package:artkiddo_core/src/local/repositories/children_repository.dart';
import 'package:artkiddo_core/src/local/repositories/local_trash_repository.dart';
import 'package:artkiddo_core/src/local/repositories/masterpieces_repository.dart';
import 'package:artkiddo_core/src/sync/sync_outbox.dart';
import 'package:artkiddo_core/src/sync/vault_meta.dart';

void main() {
  late Directory root;
  late AppDatabase db;
  late LocalVault vault;
  late DriftChildrenRepository children;
  late DriftMasterpiecesRepository masterpieces;
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
    masterpieces = DriftMasterpiecesRepository(
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
    return (await masterpieces.create(
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
      final before = await masterpieces.getById(id);
      final imageFile = await vault.resolveFile(before!.relativeImagePath!);

      expect(await masterpieces.count(), 1);
      final deletion = await masterpieces.delete(id);
      expect(
        deletion,
        isA<ActionSuccess<void>>(),
        reason: deletion is ActionFailed<void>
            ? 'failure=${deletion.failure.runtimeType} cause=${deletion.failure.cause}'
            : null,
      );
      expect(await masterpieces.getById(id), isNull);
      expect(await masterpieces.count(), 0);
      expect(await imageFile.exists(), isTrue, reason: 'trash keeps files');

      final rows = await (db.select(
        db.masterpiecesTable,
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
      expect((await masterpieces.getById(id))!.id, id);
      expect(await trash.restore(id), isA<ActionSuccess<void>>());
      expect(await imageFile.exists(), isTrue);
    },
  );

  test(
    'purge removes the row and all files, and repeated purge is a no-op',
    () async {
      final id = await createArtwork();
      final before = await masterpieces.getById(id);
      final imageFile = await vault.resolveFile(before!.relativeImagePath!);
      await masterpieces.delete(id);

      expect(await trash.purge(id), isA<ActionSuccess<void>>());
      expect(await trash.purge(id), isA<ActionSuccess<void>>());
      expect(await masterpieces.getById(id), isNull);
      expect(await imageFile.exists(), isFalse);
      expect((await trash.listTrash() as ActionSuccess).value, isEmpty);
    },
  );

  test(
    'purgeAll removes every trashed artwork without a foyer scope',
    () async {
      final first = await createArtwork();
      final second = await createArtwork(
        addedAt: clock.add(const Duration(days: 1)),
      );
      await masterpieces.delete(first);
      await masterpieces.delete(second);

      expect(await trash.purgeAll(), isA<ActionSuccess<void>>());
      expect((await trash.listTrash() as ActionSuccess).value, isEmpty);
      final rows = await db.select(db.masterpiecesTable).get();
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
      await masterpieces.delete(oldId);
      await masterpieces.delete(newId);

      await (db.update(
        db.masterpiecesTable,
      )..where((t) => t.id.equals(oldId))).write(
        MasterpiecesTableCompanion(
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

  test(
    'v10 -> v11 renames legacy provider object-key columns without data loss',
    () async {
      final migrationRoot = await Directory.systemTemp.createTemp(
        'artkiddo_v11_migration_',
      );
      final file = File(p.join(migrationRoot.path, 'legacy.sqlite'));
      addTearDown(() async {
        if (await migrationRoot.exists()) {
          await migrationRoot.delete(recursive: true);
        }
      });

      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      addTearDown(
        () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
      );

      var legacy = AppDatabase.forTesting(NativeDatabase(file));
      final oldCursor = DateTime.utc(2026, 1, 1);
      await legacy
          .into(legacy.vaultMetaTable)
          .insert(
            VaultMetaTableCompanion.insert(
              id: 'singleton',
              lastPullCursor: Value(oldCursor),
            ),
          );
      await legacy.customStatement(
        'ALTER TABLE masterpieces_table RENAME COLUMN display_object_key TO r2_key_display',
      );
      await legacy.customStatement(
        'ALTER TABLE masterpieces_table RENAME COLUMN thumbnail_object_key TO r2_key_thumbnail',
      );
      await legacy.customStatement(
        'ALTER TABLE masterpieces_table RENAME COLUMN audio_object_key TO r2_key_audio',
      );
      await legacy.customStatement('PRAGMA user_version = 10');
      await legacy.close();

      legacy = AppDatabase.forTesting(NativeDatabase(file));
      final cursors = await VaultMetaRepository(legacy).getPullCursors();
      expect(cursors.children, isNull);
      expect(cursors.masterpieces, isNull);
      expect(cursors.purged, isNull);
      expect(await VaultMetaRepository(legacy).getLastPullCursor(), isNull);
      final columns = await legacy
          .customSelect('PRAGMA table_info(masterpieces_table)')
          .get();
      final names = columns.map((row) => row.data['name']).toSet();
      expect(
        names,
        containsAll(<String>{
          'display_object_key',
          'thumbnail_object_key',
          'audio_object_key',
        }),
      );
      expect(names, isNot(contains('r2_key_display')));
      final fk = await legacy.customSelect('PRAGMA foreign_key_check').get();
      expect(fk, isEmpty);
      await legacy.close();
    },
  );

  test('deleteAllPhotos clears database records and local photos', () async {
    final id = await createArtwork();
    final artwork = await masterpieces.getById(id);
    final photo = await vault.resolveFile(artwork!.relativeImagePath!);
    expect(await photo.exists(), isTrue);

    final result = await masterpieces.deleteAllPhotos();
    expect(result, isA<ActionSuccess<int>>());
    expect((result as ActionSuccess<int>).value, equals(1));

    final count = await (db.select(db.masterpiecesTable)).get();
    expect(count, isEmpty);
    expect(await photo.exists(), isFalse);
  });
}
