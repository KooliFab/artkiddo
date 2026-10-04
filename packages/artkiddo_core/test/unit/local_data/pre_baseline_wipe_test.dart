import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:artkiddo_core/src/local/database/app_database.dart';
import 'package:artkiddo_core/src/local/storage/local_vault.dart';

/// Databases from before the launch baseline are erased, with the vault
/// files; a correct v1 database is never touched.
void main() {
  late Directory tmp;
  late File dbFile;
  late LocalVault vault;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    tmp = await Directory.systemTemp.createTemp('pre_baseline_wipe');
    dbFile = File(p.join(tmp.path, 'vault.sqlite'));
    vault = LocalVault(documentsDirProvider: () async => tmp);
  });

  tearDown(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
    await tmp.delete(recursive: true);
  });

  Future<File> seedFile(String folder) async {
    final f = File(p.join(tmp.path, folder, 'x.bin'));
    await f.create(recursive: true);
    await f.writeAsBytes([1, 2, 3]);
    return f;
  }

  AppDatabase open() => AppDatabase.forTesting(
    NativeDatabase(dbFile),
    onPreBaselineWipe: vault.eraseAllFiles,
  );

  /// Builds a database file with raw SQL, as an older app version left it.
  Future<void> seedOld({required int version, required bool withMarker}) async {
    final raw = AppDatabase.forTesting(NativeDatabase(dbFile));
    // Open once to create the baseline, then reshape it into the old state.
    await raw.customSelect('SELECT 1').get();
    await raw.customStatement(
      'INSERT INTO children (id, name, birth_date, created_at, updated_at) '
      "VALUES ('c', 'Old', 0, 0, 0)",
    );
    if (!withMarker) {
      await raw.customStatement('DROP TABLE media_versions');
    }
    await raw.customStatement('CREATE TABLE legacy_only (a INTEGER)');
    await raw.customStatement('PRAGMA user_version = $version');
    await raw.close();
  }

  Future<void> expectFreshAndUsable(AppDatabase db) async {
    expect(await db.select(db.childrenTable).get(), isEmpty);
    final tables = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    final names = tables.map((r) => r.read<String>('name')).toSet();
    expect(names, contains('media_versions'));
    expect(names, isNot(contains('legacy_only')));
    final v = await db.customSelect('PRAGMA user_version').getSingle();
    expect(v.read<int>('user_version'), 1);
  }

  test('old schema v7 database is wiped with the vault files', () async {
    await seedOld(version: 7, withMarker: true);
    final image = await seedFile(LocalVault.artworksFolder);
    final audio = await seedFile(LocalVault.audioFolder);

    final db = open();
    addTearDown(db.close);
    await expectFreshAndUsable(db);
    expect(image.existsSync(), isFalse);
    expect(audio.existsSync(), isFalse);
  });

  test('old schema v1 shape (no media_versions) is wiped', () async {
    await seedOld(version: 1, withMarker: false);
    final image = await seedFile(LocalVault.derivativesFolder);

    final db = open();
    addTearDown(db.close);
    await expectFreshAndUsable(db);
    expect(image.existsSync(), isFalse);
  });

  test('a correct v1 database keeps its data and files', () async {
    var db = open();
    await db.customStatement(
      'INSERT INTO children (id, name, birth_date, created_at, updated_at) '
      "VALUES ('c', 'Kept', 0, 0, 0)",
    );
    await db.close();
    final image = await seedFile(LocalVault.artworksFolder);

    db = open();
    addTearDown(db.close);
    expect(await db.select(db.childrenTable).get(), hasLength(1));
    expect(image.existsSync(), isTrue);
  });

  test('wiping is idempotent: a second open keeps new data', () async {
    await seedOld(version: 7, withMarker: true);
    var db = open();
    await db.customStatement(
      'INSERT INTO children (id, name, birth_date, created_at, updated_at) '
      "VALUES ('n', 'New', 0, 0, 0)",
    );
    await db.close();
    db = open();
    addTearDown(db.close);
    expect(await db.select(db.childrenTable).get(), hasLength(1));
  });
}
