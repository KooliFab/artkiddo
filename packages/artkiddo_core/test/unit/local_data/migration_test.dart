import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:drift/drift.dart' show OrderingTerm, driftRuntimeOptions;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artkiddo_core/src/local/database/app_database.dart';
import 'package:artkiddo_core/src/local/storage/local_vault.dart';
import 'package:artkiddo_core/src/local/storage/media_versions.dart';
import 'package:artkiddo_core/src/sync/sync_outbox.dart';

import '../../generated/migrations/schema.dart';
import '../../generated/migrations/schema_v1.dart' show DatabaseAtV1;
import '../../generated/migrations/schema_v3.dart' show DatabaseAtV3;
import '../../generated/migrations/schema_v4.dart' show DatabaseAtV4;
import '../../generated/migrations/schema_v5.dart' show DatabaseAtV5;
import '../../generated/migrations/schema_v6.dart' show DatabaseAtV6;

/// ADR 0007 reset the local vault to `schemaVersion = 1` and stated that
/// future schema changes "resume normal practice (schema snapshot, and a
/// migration test once a second schema version exists)". Three now do:
///
/// * v2 adds `vault_meta.join_reset_pending`, the durable marker that lets a
///   family switch recover if the process dies after the server commits but
///   before the local vault is erased;
/// * v3 adds `artworks.added_by`, the attribution of who photographed a piece.
///
/// Both are additive `addColumn` steps, which is exactly the kind of change
/// that looks too trivial to test and then silently drops a column on one
/// path. These tests pin every reachable upgrade, including the v1 -> v7 jump
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

  // Every starting point, including v1 -> v4 in one step: skipping a release
  // is the common case for a user who updates infrequently, and it is the
  // path where a forgotten `if (from < N)` branch actually bites.
  //
  // The target is always the current version because `migrateAndValidate` upgrades through
  // `AppDatabase`'s own `schemaVersion` — asking it to stop at an
  // intermediate version would validate the current schema against an older
  // snapshot and always fail.
  for (final from in const [1, 2, 3, 4, 5, 6]) {
    test('migrates a v$from vault to the current schema', () async {
      final connection = await verifier.startAt(from);
      final db = AppDatabase.forTesting(connection);
      addTearDown(db.close);

      await verifier.migrateAndValidate(db, db.schemaVersion);
    });
  }

  test(
    'a v1 -> current upgrade preserves the rows already in the vault',
    () async {
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
      await verifier.migrateAndValidate(db, db.schemaVersion);

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
    },
  );
  test('v3 audio migration preserves pending replacements and deletions', () async {
    final schema = await verifier.schemaAt(3);
    final oldDb = DatabaseAtV3(schema.newConnection());
    await oldDb.customStatement(
      "INSERT INTO children (id,name,birth_date,created_at,updated_at,sync_state) VALUES ('c','Child',1,1,1,'localOnly')",
    );
    for (final values in [
      ['replace', 'audio/local.m4a', null, 'localOnly'],
      ['delete', null, 'remote-voice', 'localOnly'],
      ['keep', null, 'remote-voice', 'synced'],
    ]) {
      await oldDb.customStatement(
        'INSERT INTO artworks (id,child_id,created_at,relative_image_path,display_object_key,relative_audio_path,audio_object_key,sync_state) VALUES (?, ?, 1, ?, ?, ?, ?, ?)',
        [
          values[0],
          'c',
          'photo.jpg',
          'remote-photo',
          values[1],
          values[2],
          values[3],
        ],
      );
    }
    await oldDb.close();
    final db = AppDatabase.forTesting(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, db.schemaVersion);
    final rows = await db.select(db.artworksTable).get();
    for (final row in rows) {
      expect(row.audioSyncIntent, row.id);
      expect(row.audioRevision, 0);
      expect(row.audioConflict, false);
    }
    expect(
      rows.firstWhere((r) => r.id == 'replace').relativeAudioPath,
      'audio/local.m4a',
    );
    expect(
      rows.firstWhere((r) => r.id == 'keep').audioObjectKey,
      'remote-voice',
    );
  });

  test('v4 outbox entries become pending operations with their own id', () async {
    final schema = await verifier.schemaAt(4);
    final oldDb = DatabaseAtV4(schema.newConnection());
    await oldDb.customStatement(
      "INSERT INTO children (id,name,birth_date,created_at,updated_at,sync_state) VALUES ('c','Léa',1,1,1,'localOnly')",
    );
    await oldDb.customStatement(
      "INSERT INTO artworks (id,child_id,created_at,sync_state,story) VALUES ('a','c',1,'localOnly','Un dragon')",
    );
    for (final entry in [
      ['child', 'c', 'upsert', 0, null],
      ['artwork', 'a', 'upsert', 2, 'boom'],
      ['artwork', 'z', 'delete', 0, null],
    ]) {
      await oldDb.customStatement(
        'INSERT INTO sync_outbox (entity,entity_id,op,attempts,last_error,created_at) VALUES (?,?,?,?,?,1)',
        entry,
      );
    }
    await oldDb.close();

    final db = AppDatabase.forTesting(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, db.schemaVersion);

    final ops = await (db.select(
      db.syncOutboxTable,
    )..orderBy([(t) => OrderingTerm(expression: t.seq)])).get();
    expect(ops.map((o) => (o.entity, o.entityId, o.op, o.attempts)), [
      ('child', 'c', 'upsert', 0),
      ('artwork', 'a', 'upsert', 2),
      ('artwork', 'z', 'delete', 0),
    ]);
    expect(ops[1].lastError, 'boom');
    final uuidV4 = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    for (final op in ops) {
      expect(op.opId, matches(uuidV4));
      expect(op.state, 'pending');
      expect(op.patchJson, isNull, reason: 'read from the row when sent');
    }
    expect(ops.map((o) => o.opId).toSet(), hasLength(3));

    // The rows the operations point at keep their data and start at revision 0.
    final child = await db.select(db.childrenTable).getSingle();
    expect((child.name, child.nameRev, child.birthDateRev), ('Léa', 0, 0));
    final artwork = await db.select(db.artworksTable).getSingle();
    expect(
      (artwork.story, artwork.storyRev, artwork.drawnAtRev),
      ('Un dragon', 0, 0),
    );
    expect(await db.select(db.replacedValuesTable).get(), isEmpty);

    // A new operation can be queued on the migrated table.
    await SyncOutboxRepository(db).enqueue(
      entity: SyncEntityKind.child,
      entityId: 'c2',
      op: SyncOutboxOp.upsert,
    );
    expect(await SyncOutboxRepository(db).countPending(), 4);
  });

  test(
    'v5 files are registered; the absent one is flagged, the artwork kept',
    () async {
      final docs = await Directory.systemTemp.createTemp('artkiddo_v6_vault_');
      addTearDown(() => docs.delete(recursive: true));
      File(p.join(docs.path, 'artworks', 'kept.jpg'))
        ..createSync(recursive: true)
        ..writeAsBytesSync([1, 2, 3]);
      File(p.join(docs.path, 'audio', 'kept.m4a'))
        ..createSync(recursive: true)
        ..writeAsBytesSync([4, 5]);

      final schema = await verifier.schemaAt(5);
      final oldDb = DatabaseAtV5(schema.newConnection());
      await oldDb.customStatement(
        "INSERT INTO children (id,name,birth_date,created_at,updated_at,sync_state) VALUES ('c','Léa',1,1,1,'localOnly')",
      );
      for (final row in [
        ['kept', 'artworks/kept.jpg', 'audio/kept.m4a'],
        ['lost', 'artworks/lost.jpg', 'audio/lost.m4a'],
        ['silent', 'artworks/silent.jpg', null],
      ]) {
        await oldDb.customStatement(
          'INSERT INTO artworks (id,child_id,created_at,relative_image_path,relative_audio_path,audio_byte_size) VALUES (?, ?, 1, ?, ?, 2)',
          [row[0], 'c', row[1], row[2]],
        );
      }
      await oldDb.close();

      final db = AppDatabase.forTesting(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, db.schemaVersion);

      final registered = await db.select(db.mediaVersionsTable).get();
      expect(registered, hasLength(5));
      expect(
        registered.every((r) => r.version == 1 && r.state == 'present'),
        isTrue,
      );

      final vault = LocalVault(documentsDirProvider: () async => docs);
      final changed = await MediaVersionsRepository(db).reconcile(vault);

      expect(changed, 4, reason: 'every entry whose size or state moved');
      final byPath = {
        for (final r in await db.select(db.mediaVersionsTable).get())
          r.localPath: r,
      };
      expect(byPath['artworks/kept.jpg']!.state, 'present');
      expect(byPath['artworks/kept.jpg']!.byteSize, 3);
      expect(byPath['audio/kept.m4a']!.byteSize, 2);
      expect(byPath['artworks/lost.jpg']!.state, 'missing');
      expect(byPath['audio/lost.m4a']!.state, 'missing');
      expect(byPath['artworks/silent.jpg']!.state, 'missing');

      // Every artwork row is exactly as before.
      final artworks = await db.select(db.artworksTable).get();
      expect(
        artworks.map((a) => a.id),
        unorderedEquals(['kept', 'lost', 'silent']),
      );
      expect(
        artworks.singleWhere((a) => a.id == 'lost').relativeAudioPath,
        'audio/lost.m4a',
      );
    },
  );

  test('v6 rows survive v7; the journal starts unread', () async {
    final schema = await verifier.schemaAt(6);
    final oldDb = DatabaseAtV6(schema.newConnection());
    await oldDb.customStatement(
      "INSERT INTO children (id,name,birth_date,created_at,updated_at,sync_state,name_rev) VALUES ('c','Léa',1,1,1,'synced',3)",
    );
    await oldDb.customStatement(
      "INSERT INTO vault_meta (id,family_id,join_reset_pending,children_pull_cursor) VALUES ('singleton','f',0,5)",
    );
    await oldDb.close();

    final db = AppDatabase.forTesting(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, db.schemaVersion);

    final child = await db.select(db.childrenTable).getSingle();
    expect((child.name, child.nameRev, child.deletedAt), ('Léa', 3, null));
    final meta = await db.select(db.vaultMetaTable).getSingle();
    expect(meta.familyId, 'f');
    expect((meta.changeCursor, meta.changeGeneration), (null, null));
    expect(await db.select(db.deferredRemoteChangesTable).get(), isEmpty);
    expect(await db.select(db.olderRemoteValuesTable).get(), isEmpty);
  });
}
