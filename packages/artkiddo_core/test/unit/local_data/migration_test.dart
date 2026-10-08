import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artkiddo_core/src/local/database/app_database.dart';

import '../../generated/migrations/schema.dart';

/// The vault is at `schemaVersion = 1`, the launch baseline. No upgrade
/// exists yet, so this file only pins that the committed v1 snapshot is the
/// schema `onCreate` builds, and that the current version is the newest
/// snapshot. When v2 is introduced:
///
/// 1. `dart run drift_dev schema dump lib/src/local/database/app_database.dart drift_schemas/`
/// 2. `dart run drift_dev schema generate drift_schemas test/generated/migrations/`
/// 3. add an `onUpgrade` step in `AppDatabase.migration`;
/// 4. add `v1 -> current` here (`verifier.startAt(1)`, optionally seed rows
///    through the generated `DatabaseAtV1` and assert they survive).
void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    verifier = SchemaVerifier(GeneratedHelper());
  });

  tearDownAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
  });

  test('the committed v1 snapshot is the schema onCreate builds', () async {
    final schema = await verifier.schemaAt(1);
    final db = AppDatabase.forTesting(schema.newConnection());
    addTearDown(db.close);
    expect(db.schemaVersion, 1);
    await verifier.migrateAndValidate(db, db.schemaVersion);
  });

  test('a fresh vault is created at the current schema', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase.forTesting(connection);
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, db.schemaVersion);
  });
}
