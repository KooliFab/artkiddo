import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artkiddo_core/src/local/database/app_database.dart';

import '../../generated/migrations/schema.dart';
import '../../generated/migrations/schema_v1.dart' show DatabaseAtV1;

/// ADR 0007 reset the local vault to `schemaVersion = 1` and stated that
/// future schema changes "resume normal practice (schema snapshot, and a
/// migration test once a second schema version exists)". Two now do:
///
/// * v2 adds `vault_meta.join_reset_pending`, the durable marker that lets a
///   family switch recover if the process dies after the server commits but
///   before the local vault is erased;
/// * v3 adds `artworks.added_by`, the attribution of who photographed a piece.
///
/// Both are additive `addColumn` steps, which is exactly the kind of change
/// that looks too trivial to test and then silently drops a column on one
/// path. These tests pin every reachable upgrade, including the v1 -> v3 jump
/// a device that skipped a release actually takes.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    verifier = SchemaVerifier(GeneratedHelper());
  });

  tearDownAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
  });

  // Every starting point, including v1 -> v3 in one step: skipping a release
  // is the common case for a user who updates infrequently, and it is the
  // path where a forgotten `if (from < N)` branch actually bites.
  //
  // The target is always 3 because `migrateAndValidate` upgrades through
  // `AppDatabase`'s own `schemaVersion` — asking it to stop at an
  // intermediate version would validate the current schema against an older
  // snapshot and always fail.
  for (final from in const [1, 2]) {
    test('migrates a v$from vault to the current schema', () async {
      final connection = await verifier.startAt(from);
      final db = AppDatabase.forTesting(connection);
      addTearDown(db.close);

      await verifier.migrateAndValidate(db, db.schemaVersion);
    });
  }

  test('a v1 -> v3 upgrade preserves the rows already in the vault', () async {
    // Written in raw SQL on purpose: the point is to prove that a row
    // inserted through the *old* physical shape survives, so going through
    // today's typed API would defeat the test.
    final schema = await verifier.schemaAt(1);
    // A fresh connection per database object, both onto the same underlying
    // schema: drift refuses to reopen a connection once closed.
    final oldDb = DatabaseAtV1(schema.newConnection());
    await oldDb.customStatement(
      'INSERT INTO children (id, name, birth_date, created_at, updated_at, '
      'sync_state) VALUES (?, ?, ?, ?, ?, ?)',
      ['child-1', 'Léa', 1615680000, 1767225600, 1767225600, 'localOnly'],
    );
    await oldDb.close();

    final db = AppDatabase.forTesting(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 3);

    final children = await db.select(db.childrenTable).get();
    expect(children, hasLength(1));
    expect(children.single.name, 'Léa');

    // The column v3 added must exist and read as null, not be absent: an
    // artwork stored before attribution existed has no known author, and
    // saying so honestly is what stops the UI from inventing one.
    final addedBy = await db
        .customSelect('SELECT added_by FROM artworks')
        .get();
    expect(addedBy, isEmpty);
    final pending = await db
        .customSelect('SELECT join_reset_pending FROM vault_meta')
        .get();
    expect(pending, isEmpty);
  });
}
