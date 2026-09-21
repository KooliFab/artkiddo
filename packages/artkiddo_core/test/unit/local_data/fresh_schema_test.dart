import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artkiddo_core/src/local/database/app_database.dart';

/// These tests pin the physical shape of the supported local schema.
void main() {
  late AppDatabase db;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
  });

  Future<Set<String>> tableNames() async {
    final rows = await db
        .customSelect(
          'SELECT name FROM sqlite_master '
          "WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
        )
        .get();
    return rows.map((row) => row.data['name'] as String).toSet();
  }

  Future<Set<String>> columnNames(String table) async {
    final rows = await db.customSelect('PRAGMA table_info($table)').get();
    return rows.map((row) => row.data['name'] as String).toSet();
  }

  test('a fresh vault is created at schema version 3', () async {
    await db.customStatement('SELECT 1');
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(db.schemaVersion, 3);
    expect(version.data['user_version'], 3);
  });

  test('a fresh vault exposes exactly the baseline tables', () async {
    await db.customStatement('SELECT 1');
    expect(await tableNames(), <String>{
      'children',
      'artworks',
      'sync_outbox',
      'vault_meta',
      'pending_file_cleanups',
      'share_link_url_cache',
    });
  });

  test('artworks exposes exactly the baseline columns', () async {
    await db.customStatement('SELECT 1');
    expect(await columnNames('artworks'), <String>{
      'id',
      'child_id',
      'relative_image_path',
      'created_at',
      'drawn_at',
      'story',
      'sync_state',
      'display_image_path',
      'thumbnail_image_path',
      'image_width',
      'image_height',
      'display_object_key',
      'thumbnail_object_key',
      'byte_size',
      'relative_audio_path',
      'audio_duration_ms',
      'audio_object_key',
      'audio_byte_size',
      'deleted_at',
      'added_by',
    });
  });

  test('vault_meta uses family_id and artworks_pull_cursor', () async {
    await db.customStatement('SELECT 1');
    expect(
      await columnNames('vault_meta'),
      containsAll(<String>{
        'family_id',
        'join_reset_pending',
        'children_pull_cursor',
        'artworks_pull_cursor',
        'purged_pull_cursor',
      }),
    );
  });

  test('foreign keys are enforced on a fresh vault', () async {
    await db.customStatement('SELECT 1');
    final pragma = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(pragma.data['foreign_keys'], 1);
    final check = await db.customSelect('PRAGMA foreign_key_check').get();
    expect(check, isEmpty);
  });
}
