import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artkiddo_core/src/local/database/app_database.dart';
import '../../generated/migrations/schema.dart';

void main() {
  final verifier = SchemaVerifier(GeneratedHelper());

  for (final from in [5, 6, 7, 8, 9, 10]) {
    test('migrates schema v$from to v${from + 1}', () async {
      final schema = await verifier.schemaAt(from);
      final database = AppDatabase.forTesting(schema.newConnection().executor);
      await verifier.migrateAndValidate(database, from + 1);
      await database.close();
      schema.close();
    });
  }

  test('migrates v5 to v11 without losing vault data', () async {
    final schema = await verifier.schemaAt(5);
    const createdAt = 1700000000;
    const createdAtMilliseconds = createdAt * 1000;
    schema.rawDatabase.execute(
      'INSERT INTO children_table '
      '(id, name, birth_date, created_at, updated_at, sync_state) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      ['child-1', 'Mila', createdAt, createdAt, createdAt, 'localOnly'],
    );
    schema.rawDatabase.execute(
      'INSERT INTO masterpieces_table '
      '(id, child_id, relative_image_path, created_at, drawn_at, story, '
      'sync_state, display_image_path, thumbnail_image_path, '
      'r2_key_display, r2_key_thumbnail) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        'masterpiece-1',
        'child-1',
        'masterpieces/masterpiece-1.png',
        createdAt,
        null,
        'Une histoire conservée',
        'localOnly',
        'masterpieces/masterpiece-1.png',
        'masterpieces_derivatives/masterpiece-1.jpg',
        'display-key',
        'thumbnail-key',
      ],
    );

    final database = AppDatabase.forTesting(schema.newConnection().executor);
    await verifier.migrateAndValidate(database, 11);

    final child = await database.select(database.childrenTable).getSingle();
    final masterpiece = await database
        .select(database.masterpiecesTable)
        .getSingle();
    expect(child.id, 'child-1');
    expect(child.name, 'Mila');
    expect(child.createdAt.millisecondsSinceEpoch, createdAtMilliseconds);
    expect(masterpiece.id, 'masterpiece-1');
    expect(masterpiece.childId, 'child-1');
    expect(masterpiece.relativeImagePath, 'masterpieces/masterpiece-1.png');
    expect(masterpiece.story, 'Une histoire conservée');
    expect(masterpiece.addedAt.millisecondsSinceEpoch, createdAtMilliseconds);

    await database.close();
    schema.close();
  });
}
