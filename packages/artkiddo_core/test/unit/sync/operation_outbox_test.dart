// Operation outbox: every local edit is an identified operation written
// in the same transaction as the edit; an operation already sent never
// changes.

import 'dart:convert';
import 'dart:io';

import 'package:artkiddo_core/artkiddo_core.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'sync_engine_test.dart' show makeTestImage;

/// An outbox whose patch writes fail, to prove the business write is undone.
class _ThrowingOutbox extends SyncOutboxRepository {
  _ThrowingOutbox(super.db);

  @override
  Future<String> enqueuePatch(EntityPatch patch) =>
      throw StateError('outbox write failed');
}

final _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

void main() {
  late Directory tempRoot;
  late AppDatabase db;
  late LocalVault vault;
  late SyncOutboxRepository outbox;
  late DriftChildrenRepository children;
  late DriftArtworksRepository artworks;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('artkiddo_ops_test_');
    final docs = Directory(p.join(tempRoot.path, 'docs'))..createSync();
    db = AppDatabase.forTesting(
      NativeDatabase(File(p.join(tempRoot.path, 'test.sqlite'))),
    );
    vault = LocalVault(documentsDirProvider: () async => docs);
    outbox = SyncOutboxRepository(db);
    children = DriftChildrenRepository(db, vault, outbox: outbox);
    artworks = DriftArtworksRepository(db, vault, outbox: outbox);
  });

  tearDown(() async {
    await db.close();
    if (await tempRoot.exists()) await tempRoot.delete(recursive: true);
  });

  Future<String> newChild([String name = 'Léa']) async =>
      (await children.create(name: name, birthDate: DateTime(2019, 3, 1))
              as ActionSuccess<String>)
          .value;

  Future<List<SyncOutboxEntryEntity>> childOps(String id) =>
      outbox.operationsOf(SyncEntityKind.child, id);

  group('a child edit is one operation written with the edit', () {
    test(
      'creation carries the fields, base revision 0 and its own id',
      () async {
        final id = await newChild();

        final op = (await childOps(id)).single;
        expect(op.opId, matches(_uuidV4));
        expect(op.entity, 'child');
        expect(op.op, 'upsert');
        expect(op.state, 'pending');
        expect(op.attempts, 0);

        final patch = EntityPatch.fromJson(jsonDecode(op.patchJson!));
        expect(patch.opId, op.opId);
        expect(patch.isCreation, isTrue);
        expect(patch.fields, {'name': 'Léa', 'birthDate': '2019-03-01'});
        expect(patch.baseRevisions, {'name': 0, 'birthDate': 0});
      },
    );

    test('an edit of a pending operation is merged into it', () async {
      final id = await newChild();
      final first = (await childOps(id)).single;

      await children.update(
        id: id,
        name: 'Léa-Rose',
        birthDate: DateTime(2019, 3, 1),
      );

      final op = (await childOps(id)).single;
      expect(op.opId, first.opId, reason: 'never sent: same operation');
      expect(op.patch!.fields, {'name': 'Léa-Rose', 'birthDate': '2019-03-01'});
      expect(op.patch!.isCreation, isTrue);
    });

    test('an unchanged value queues nothing', () async {
      final id = await newChild();
      await outbox.markSucceeded((await childOps(id)).single.seq);

      await children.update(
        id: id,
        name: 'Léa',
        birthDate: DateTime(2019, 3, 1),
      );

      expect(await childOps(id), isEmpty);
    });

    test(
      'an operation in flight never changes: the edit is a new one',
      () async {
        final id = await newChild();
        final sent = (await childOps(id)).single;
        await outbox.markInFlight(sent.seq);
        final before = (await childOps(id)).single;

        await children.update(
          id: id,
          name: 'Nouveau',
          birthDate: DateTime(2019, 3, 1),
        );

        final ops = await childOps(id);
        expect(ops, hasLength(2));
        expect(ops.first.opId, sent.opId);
        expect(ops.first.patchJson, before.patchJson);
        expect(ops.first.state, 'in_flight');
        expect(ops.last.opId, isNot(sent.opId));
        expect(ops.last.state, 'pending');
        expect(ops.last.patch!.fields, {'name': 'Nouveau'});
        expect(ops.last.patch!.baseRevisions, {'name': 0});

        // A further edit merges into the second operation, not the first.
        await children.update(
          id: id,
          name: 'Encore',
          birthDate: DateTime(2020, 4, 2),
        );
        final merged = await childOps(id);
        expect(merged, hasLength(2));
        expect(merged.first.patchJson, before.patchJson);
        expect(merged.last.opId, ops.last.opId);
        expect(merged.last.patch!.fields, {
          'name': 'Encore',
          'birthDate': '2020-04-02',
        });
      },
    );

    test('the base revisions are the ones the row knows', () async {
      final id = await newChild();
      await outbox.markSucceeded((await childOps(id)).single.seq);
      await (db.update(db.childrenTable)..where((t) => t.id.equals(id))).write(
        const ChildrenTableCompanion(nameRev: Value(4), birthDateRev: Value(7)),
      );

      await children.update(
        id: id,
        name: 'Autre',
        birthDate: DateTime(2018, 1, 1),
      );

      expect((await childOps(id)).single.patch!.baseRevisions, {
        'name': 4,
        'birthDate': 7,
      });
    });

    test(
      'deleting supersedes pending operations but not the one in flight',
      () async {
        final id = await newChild();
        final sent = (await childOps(id)).single;
        await outbox.markInFlight(sent.seq);
        await children.update(
          id: id,
          name: 'Nouveau',
          birthDate: DateTime(2019, 3, 1),
        );

        await children.delete(id);

        final ops = await childOps(id);
        expect(ops.map((o) => (o.opId, o.state, o.op)), [
          (sent.opId, 'in_flight', 'upsert'),
          (ops.last.opId, 'pending', 'delete'),
        ]);
        expect(ops.last.patch!.fields, {'lifecycle': 'purged'});
        expect(await children.getById(id), isNull);
      },
    );
  });

  group('an artwork edit', () {
    Future<String> newArtwork(String childId) async {
      final source = await makeTestImage(tempRoot, 'src.jpg');
      return (await artworks.create(
                childId: childId,
                sourceImageFile: source,
                addedAt: DateTime(2026, 1, 1),
              )
              as ActionSuccess<String>)
          .value;
    }

    Future<List<SyncOutboxEntryEntity>> artworkOps(String id) =>
        outbox.operationsOf(SyncEntityKind.artwork, id);

    test('is absorbed by the pending creation, which reads the row', () async {
      final childId = await newChild();
      final id = await newArtwork(childId);
      final creation = (await artworkOps(id)).single;
      expect(creation.patchJson, isNull);

      await artworks.updateStory(id: id, story: 'Un dragon');

      expect((await artworkOps(id)).single.opId, creation.opId);
    });

    test('story and drawing date are field operations once created', () async {
      final childId = await newChild();
      final id = await newArtwork(childId);
      await outbox.markSucceeded((await artworkOps(id)).single.seq);
      await (db.update(db.artworksTable)..where((t) => t.id.equals(id))).write(
        const ArtworksTableCompanion(storyRev: Value(2), drawnAtRev: Value(3)),
      );

      await artworks.updateStory(id: id, story: 'Un dragon');
      await artworks.updateDrawnAt(id: id, drawnAt: DateTime(2025, 12, 31));

      final op = (await artworkOps(id)).single;
      expect(op.patch!.fields, {'story': 'Un dragon', 'drawnAt': '2025-12-31'});
      expect(op.patch!.baseRevisions, {'story': 2, 'drawnAt': 3});

      await outbox.markInFlight(op.seq);
      await artworks.updateDrawnAt(id: id, drawnAt: null);
      final second = (await artworkOps(id)).last;
      expect(second.opId, isNot(op.opId));
      expect(second.patch!.fields, {'drawnAt': null});
    });

    test(
      'a failed operation write leaves neither the edit nor an operation',
      () async {
        final childId = await newChild();
        final id = await newArtwork(childId);
        await outbox.markSucceeded((await artworkOps(id)).single.seq);
        final failing = DriftArtworksRepository(
          db,
          vault,
          outbox: _ThrowingOutbox(db),
        );

        final result = await failing.updateStory(id: id, story: 'Perdu ?');

        expect(result, isA<ActionFailed<void>>());
        expect((await artworks.getById(id))!.story, isNull);
        expect(await artworkOps(id), isEmpty);
      },
    );
  });

  test(
    'a failed operation write leaves neither the child nor an operation',
    () async {
      final failing = DriftChildrenRepository(
        db,
        vault,
        outbox: _ThrowingOutbox(db),
      );

      final result = await failing.create(
        name: 'Fantôme',
        birthDate: DateTime(2019, 3, 1),
      );

      expect(result, isA<ActionFailed<String>>());
      expect(await children.count(), 0);
      expect(await outbox.countPending(), 0);
    },
  );

  test(
    'the operations of one entity are only ready one at a time, in order',
    () async {
      final id = await newChild();
      final first = (await childOps(id)).single;
      await outbox.markInFlight(first.seq);
      await children.update(
        id: id,
        name: 'Nouveau',
        birthDate: DateTime(2019, 3, 1),
      );
      final other = await newChild('Max');

      expect(
        (await outbox.listReady()).map((o) => o.entityId),
        unorderedEquals([id, other]),
      );
      expect(
        (await outbox.listReady()).where((o) => o.entityId == id).single.opId,
        first.opId,
      );

      // The head is backing off: the later operation must not overtake it.
      await outbox.markFailed(first.seq, error: 'offline');
      expect((await outbox.listReady()).map((o) => o.entityId), [other]);
      expect((await childOps(id)).first.state, 'in_flight');
    },
  );
}
