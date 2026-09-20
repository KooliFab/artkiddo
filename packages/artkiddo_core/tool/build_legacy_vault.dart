import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

/// Materializes SQLite files for the historical schemas still supported by
/// the migration strategy. The files are disposable build artifacts; the
/// committed source of truth remains drift_schemas/drift_schema_v*.json.
Future<void> main(List<String> arguments) async {
  final output = Directory(
    arguments.isEmpty ? 'build/legacy_vaults' : arguments.single,
  );
  if (output.existsSync()) {
    output.deleteSync(recursive: true);
  }
  output.createSync(recursive: true);

  for (var version = 5; version <= 11; version++) {
    final file = File('${output.path}/vault_v$version.sqlite');
    _createLatest(file);
    final database = sqlite3.open(file.path);
    try {
      _rewind(database, version);
      database.execute('PRAGMA user_version = $version');
    } finally {
      database.close();
    }
    stdout.writeln('created ${file.path}');
  }
}

void _createLatest(File file) {
  final snapshot =
      json.decode(
            File('drift_schemas/drift_schema_v11.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  final database = sqlite3.open(file.path);
  try {
    for (final fixed in snapshot['fixed_sql'] as List<dynamic>) {
      for (final statement in fixed['sql'] as List<dynamic>) {
        if (statement['dialect'] == 'sqlite') {
          database.execute(statement['sql'] as String);
        }
      }
    }
    database.execute('PRAGMA user_version = 11');
  } finally {
    database.close();
  }
}

void _rewind(Database database, int version) {
  if (version <= 10) {
    _rename(database, 'display_object_key', 'r2_key_display');
    _rename(database, 'thumbnail_object_key', 'r2_key_thumbnail');
    _rename(database, 'audio_object_key', 'r2_key_audio');
  }
  if (version <= 9) {
    database.execute('ALTER TABLE masterpieces_table DROP COLUMN deleted_at');
    for (final column in [
      'children_pull_cursor',
      'masterpieces_pull_cursor',
      'purged_pull_cursor',
    ]) {
      database.execute('ALTER TABLE vault_meta_table DROP COLUMN $column');
    }
  }
  if (version <= 8) {
    for (final column in [
      'relative_audio_path',
      'audio_duration_ms',
      'r2_key_audio',
      'audio_byte_size',
    ]) {
      database.execute('ALTER TABLE masterpieces_table DROP COLUMN $column');
    }
  }
  if (version <= 7) {
    database.execute('ALTER TABLE masterpieces_table DROP COLUMN image_width');
    database.execute('ALTER TABLE masterpieces_table DROP COLUMN image_height');
  }
  if (version <= 6) {
    database.execute('ALTER TABLE masterpieces_table DROP COLUMN byte_size');
  }
  if (version <= 5) {
    database.execute('DROP TABLE share_link_url_cache_table');
  }
}

void _rename(Database database, String from, String to) {
  database.execute('ALTER TABLE masterpieces_table RENAME COLUMN $from TO $to');
}
