// How one receipt is applied to its own operation (L02), without an engine.

import 'dart:io';

import 'package:artkiddo_core/artkiddo_core.dart';
import 'package:artkiddo_core/src/sync/operation_receipts.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const _childId = '00000000-0000-4000-8000-000000000003';
const _artworkId = '00000000-0000-4000-8000-000000000005';
const _mediaId = '00000000-0000-4000-8000-000000000007';
const _opA = '3f2c1a4e-8b7d-4c6e-9f10-2a3b4c5d6e02';
const _opB = '3f2c1a4e-8b7d-4c6e-9f10-2a3b4c5d6e03';

MediaDescriptor _audio(int version) => MediaDescriptor(
  mediaId: _mediaId,
  version: version,
  role: MediaRole.audio,
  format: MediaFormat.m4a,
  byteSize: 3072,
  sha256: 'c3' * 32,
  durationMs: 3000,
);

Map<String, Object?> _ref(int version) => {
  'mediaId': _mediaId,
  'version': version,
};

void main() {
  late Directory tempRoot;
  late AppDatabase db;
  late SyncOutboxRepository outbox;
  late ReplacedValuesRepository history;
  late OutboxReceiptHandler handler;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('artkiddo_receipts_');
    db = AppDatabase.forTesting(
      NativeDatabase(File(p.join(tempRoot.path, 'test.sqlite'))),
    );
    outbox = SyncOutboxRepository(db);
    history = ReplacedValuesRepository(db);
    handler = OutboxReceiptHandler(db, outbox, history);
    await db
        .into(db.childrenTable)
        .insert(
          ChildrenTableCompanion.insert(
            id: _childId,
            name: 'Léa',
            birthDate: DateTime(2019, 3, 1),
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
        );
    await db
        .into(db.artworksTable)
        .insert(
          ArtworksTableCompanion.insert(
            id: _artworkId,
            childId: _childId,
            addedAt: DateTime(2026, 1, 1),
            audioRevision: const Value(1),
            story: const Value('Un dragon bleu'),
          ),
        );
  });

  tearDown(() async {
    await db.close();
    if (await tempRoot.exists()) await tempRoot.delete(recursive: true);
  });

  EntityPatch childPatch(String opId, String name, int base) => EntityPatch(
    opId: opId,
    entityType: SyncEntityType.child,
    entityId: _childId,
    baseRevisions: {'name': base},
    fields: {'name': name},
    createdAt: DateTime.utc(2026, 10, 1),
  );

  Future<SyncOutboxEntryEntity> queueSent(EntityPatch patch) async {
    await outbox.enqueuePatch(patch);
    final entry = (await outbox.operationsOf(
      SyncEntityKind.of(patch.entityType),
      patch.entityId,
    )).firstWhere((o) => o.opId == patch.opId);
    await outbox.markInFlight(entry.seq);
    return entry;
  }

  test(
    'a conflicting audio keeps both recordings and sends the local one again',
    () async {
      final patch = EntityPatch(
        opId: _opA,
        entityType: SyncEntityType.artwork,
        entityId: _artworkId,
        baseRevisions: {'drawnAt': 0, 'audio': 1},
        fields: {'drawnAt': '2026-09-28', 'audio': _ref(4)},
        media: [_audio(4)],
        createdAt: DateTime.utc(2026, 10, 1),
      );
      final entry = await queueSent(patch);

      final outcome = await handler.apply(
        entry: entry,
        patch: patch,
        receipt: MutationReceipt(
          opId: _opA,
          accepted: {'drawnAt': 1},
          conflicts: [
            FieldConflict(
              field: 'audio',
              localValue: _ref(4),
              remoteValue: _ref(3),
              baseRevision: 1,
              remoteRevision: 2,
              kind: FieldConflictKind.audio,
            ),
          ],
        ),
      );

      expect(outcome.resendQueued, isTrue);
      final row = await (db.select(db.artworksTable)).getSingle();
      expect((row.drawnAtRev, row.audioRevision), (1, 2));
      final replaced = (await history.listReplacedValues(_artworkId)).single;
      expect(replaced.field, 'audio');
      expect(replaced.mediaRef, MediaRef(mediaId: _mediaId, version: 3));
      expect(replaced.source, ReplacedValueSource.remote);
      final resend = (await outbox.operationsOf(
        SyncEntityKind.artwork,
        _artworkId,
      )).single;
      expect(resend.opId, isNot(_opA));
      expect(resend.patch!.fields, {'audio': _ref(4)});
      expect(resend.patch!.baseRevisions, {'audio': 2});
      expect(resend.patch!.media.single.version, 4);
    },
  );

  test('an edit of a trashed or purged artwork stays recoverable and is not '
      'sent again', () async {
    final patch = EntityPatch(
      opId: _opA,
      entityType: SyncEntityType.artwork,
      entityId: _artworkId,
      baseRevisions: {'story': 1},
      fields: {'story': 'Un dragon rouge'},
      createdAt: DateTime.utc(2026, 10, 1),
    );
    final entry = await queueSent(patch);

    await handler.apply(
      entry: entry,
      patch: patch,
      receipt: MutationReceipt(
        opId: _opA,
        accepted: {},
        conflicts: [
          FieldConflict(
            field: 'story',
            localValue: 'Un dragon rouge',
            remoteValue: 'Un dragon vert',
            baseRevision: 1,
            remoteRevision: 1,
            kind: FieldConflictKind.deleteVsEdit,
          ),
        ],
      ),
    );

    expect(
      await outbox.operationsOf(SyncEntityKind.artwork, _artworkId),
      isEmpty,
    );
    final replaced = (await history.listReplacedValues(_artworkId)).single;
    expect(
      (replaced.value, replaced.source),
      ('Un dragon rouge', ReplacedValueSource.local),
    );
    final row = await db.select(db.artworksTable).getSingle();
    expect(row.story, 'Un dragon bleu', reason: 'the local row is untouched');
    expect(row.syncState, 'localOnly', reason: 'nothing was accepted');
  });

  test(
    'a later operation takes the acknowledged revision as its base',
    () async {
      final first = childPatch(_opA, 'A', 0);
      final entry = await queueSent(first);
      await outbox.enqueuePatch(childPatch(_opB, 'B', 0));

      await handler.apply(
        entry: entry,
        patch: first,
        receipt: MutationReceipt(opId: _opA, accepted: {'name': 5}),
      );

      final left = (await outbox.operationsOf(
        SyncEntityKind.child,
        _childId,
      )).single;
      expect(left.opId, _opB);
      expect(left.patch!.baseRevisions, {'name': 5});
      expect(left.patch!.fields, {'name': 'B'});
      final row = await db.select(db.childrenTable).getSingle();
      expect(row.nameRev, 0, reason: 'the local value moved on since the op');
      expect(row.syncState, 'localOnly');
    },
  );

  test(
    'a conflict with a newer local edit queued only rebases that edit',
    () async {
      final first = childPatch(_opA, 'A', 1);
      final entry = await queueSent(first);
      await outbox.enqueuePatch(childPatch(_opB, 'B', 1));

      final outcome = await handler.apply(
        entry: entry,
        patch: first,
        receipt: MutationReceipt(
          opId: _opA,
          accepted: {},
          conflicts: [
            FieldConflict(
              field: 'name',
              localValue: 'A',
              remoteValue: 'R',
              baseRevision: 1,
              remoteRevision: 3,
              kind: FieldConflictKind.field,
            ),
          ],
        ),
      );

      expect(outcome.resendQueued, isFalse);
      final left = (await outbox.operationsOf(
        SyncEntityKind.child,
        _childId,
      )).single;
      expect(left.opId, _opB);
      expect(left.patch!.baseRevisions, {'name': 3});
      expect((await history.listReplacedValues(_childId)).map((v) => v.value), [
        'R',
      ]);
    },
  );

  test('a receipt that does not answer the patch changes nothing', () async {
    final patch = childPatch(_opA, 'A', 0);
    final entry = await queueSent(patch);

    await expectLater(
      handler.apply(
        entry: entry,
        patch: patch,
        receipt: MutationReceipt(opId: _opA, accepted: {'birthDate': 1}),
      ),
      throwsA(isA<MutationReceiptMismatchException>()),
    );

    expect(
      (await outbox.operationsOf(SyncEntityKind.child, _childId)).single.opId,
      _opA,
    );
    expect((await db.select(db.childrenTable).getSingle()).nameRev, 0);
    expect(await db.select(db.replacedValuesTable).get(), isEmpty);
  });

  test('an artwork left in error by a failed attempt is synced by the '
      'acknowledgement; other states are left alone', () async {
    final patch = EntityPatch(
      opId: _opA,
      entityType: SyncEntityType.artwork,
      entityId: _artworkId,
      baseRevisions: {'drawnAt': 0},
      fields: {'drawnAt': '2026-09-28'},
      createdAt: DateTime.utc(2026, 10, 1),
    );
    Future<String> ackWith(String state) async {
      await (db.update(
        db.artworksTable,
      )).write(ArtworksTableCompanion(syncState: Value(state)));
      final entry = await queueSent(patch);
      await handler.apply(
        entry: entry,
        patch: patch,
        receipt: MutationReceipt(opId: _opA, accepted: {'drawnAt': 1}),
      );
      return (await db.select(db.artworksTable).getSingle()).syncState;
    }

    expect(await ackWith('syncError'), 'synced');
    expect(await ackWith('remoteThumbnail'), 'remoteThumbnail');
  });
}
