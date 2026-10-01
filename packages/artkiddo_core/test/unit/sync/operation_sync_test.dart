// Operation sync (L02): the engine sends identified operations through
// `SyncProtocolBackend`, applies each receipt to its own operation only, and
// keeps every value that lost a conflict.

import 'dart:async';
import 'dart:io';

import 'package:artkiddo_core/artkiddo_core.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'fakes.dart';
import 'sync_engine_test.dart' show makeTestImage;

class ServerEntity {
  final values = <String, Object?>{};
  final revisions = <String, int>{};
  bool purged = false;
}

/// In-memory remote side applying the merge rules of the sync protocol.
class FakeProtocolBackend implements SyncProtocolBackend {
  final entities = <String, ServerEntity>{};
  final receipts = <String, MutationReceipt>{};

  /// Every `opId` received, replays included.
  final received = <String>[];

  /// Patches that had an effect (a replay has none).
  int effects = 0;

  /// Runs after the patch is applied, before the answer is returned.
  Future<void> Function(EntityPatch patch)? beforeReply;

  /// The next answer never reaches the device, although the patch was applied.
  bool loseNextResponse = false;

  ServerEntity? entity(SyncEntityType type, String id) =>
      entities['${type.name}/$id'];

  /// Another device changes [field].
  void remoteEdit(SyncEntityType type, String id, String field, Object? value) {
    final e = entities['${type.name}/$id']!;
    e.values[field] = value;
    e.revisions[field] = (e.revisions[field] ?? 0) + 1;
  }

  @override
  Future<MutationReceipt> applyPatch(EntityPatch patch) async {
    received.add(patch.opId);
    final stored = receipts[patch.opId];
    final MutationReceipt receipt;
    if (stored != null) {
      receipt = stored.asReplay();
    } else {
      receipt = _apply(patch);
      receipts[patch.opId] = receipt;
      effects++;
    }
    await beforeReply?.call(patch);
    if (loseNextResponse) {
      loseNextResponse = false;
      throw const SocketException('response lost');
    }
    return receipt;
  }

  MutationReceipt _apply(EntityPatch patch) {
    final key = '${patch.entityType.name}/${patch.entityId}';
    final current = entities[key];
    if (current == null && !patch.isCreation || (current?.purged ?? false)) {
      return MutationReceipt(
        opId: patch.opId,
        accepted: {},
        conflicts: [
          for (final f in patch.fields.entries)
            FieldConflict(
              field: f.key,
              localValue: f.value,
              remoteValue: current?.values[f.key],
              baseRevision: patch.baseRevisions[f.key]!,
              remoteRevision: current?.revisions[f.key] ?? 0,
              kind: FieldConflictKind.deleteVsEdit,
            ),
        ],
      );
    }
    final e = current ?? (entities[key] = ServerEntity());
    final accepted = <String, int>{};
    final conflicts = <FieldConflict>[];
    for (final f in patch.fields.entries) {
      final revision = e.revisions[f.key] ?? 0;
      if (f.key == 'lifecycle') {
        e.purged = true;
        e.revisions[f.key] = revision + 1;
        accepted[f.key] = revision + 1;
      } else if (patch.baseRevisions[f.key] == revision) {
        e.values[f.key] = f.value;
        e.revisions[f.key] = revision + 1;
        accepted[f.key] = revision + 1;
      } else if (e.values[f.key] == f.value) {
        accepted[f.key] = revision;
      } else {
        conflicts.add(
          FieldConflict(
            field: f.key,
            localValue: f.value,
            remoteValue: e.values[f.key],
            baseRevision: patch.baseRevisions[f.key]!,
            remoteRevision: revision,
            kind: FieldConflictKind.field,
          ),
        );
      }
    }
    return MutationReceipt(
      opId: patch.opId,
      accepted: accepted,
      conflicts: conflicts,
    );
  }

  @override
  Future<SyncChangePage> pullChanges(ChangeCursor? cursor, {int limit = 200}) =>
      throw UnimplementedError();

  @override
  Future<MediaReservation> reserveMedia({
    required String opId,
    required String artworkId,
    required MediaDescriptor media,
  }) => throw UnimplementedError();

  @override
  Future<void> uploadMedia(MediaReservation reservation, List<int> bytes) =>
      throw UnimplementedError();

  @override
  Future<MediaDescriptor> confirmMedia(MediaReservation reservation) =>
      throw UnimplementedError();
}

/// One local vault that can be closed and reopened over the same files.
class Node {
  final Directory root;
  final FakeProtocolBackend backend;
  final FakeHomeCloudApi legacy = FakeHomeCloudApi()..currentUserId = 'user';
  final uploader = FakeObjectUploader();
  late AppDatabase db;
  late LocalVault vault;
  late SyncOutboxRepository outbox;
  late DriftChildrenRepository children;
  late DriftArtworksRepository artworks;
  late SyncEngine engine;

  Node._(this.root, this.backend);

  static Future<Node> create(FakeProtocolBackend backend) async {
    final root = await Directory.systemTemp.createTemp('artkiddo_opsync_');
    Directory(p.join(root.path, 'docs')).createSync();
    return Node._(root, backend).._open();
  }

  void _open() {
    db = AppDatabase.forTesting(
      NativeDatabase(File(p.join(root.path, 'test.sqlite'))),
    );
    vault = LocalVault(
      documentsDirProvider: () async => Directory(p.join(root.path, 'docs')),
    );
    outbox = SyncOutboxRepository(db);
    children = DriftChildrenRepository(db, vault, outbox: outbox);
    artworks = DriftArtworksRepository(db, vault, outbox: outbox);
    engine = SyncEngine(
      db: db,
      vault: vault,
      uploader: uploader,
      downloader: FakeObjectDownloader(uploader.objects),
      childrenRepo: children,
      artworksRepo: artworks,
      cloudApi: legacy,
      outbox: outbox,
      vaultMeta: VaultMetaRepository(db),
      currentUserId: () => 'user',
      protocolBackend: backend,
    );
  }

  /// Process restart: the database file is reopened, nothing else survives.
  Future<void> restart() async {
    await db.close();
    _open();
  }

  Future<SyncRunSummary> sync() => engine.syncAll();

  Future<String> newChild([String name = 'Ancien']) async =>
      (await children.create(name: name, birthDate: DateTime(2019, 3, 1))
              as ActionSuccess<String>)
          .value;

  Future<List<SyncOutboxEntryEntity>> ops(String id) =>
      outbox.operationsOf(SyncEntityKind.child, id);

  Future<ChildEntity> row(String id) =>
      (db.select(db.childrenTable)..where((t) => t.id.equals(id))).getSingle();

  Future<void> close() async {
    await db.close();
    if (await root.exists()) await root.delete(recursive: true);
  }
}

void main() {
  late FakeProtocolBackend backend;
  late Node node;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() async {
    backend = FakeProtocolBackend();
    node = await Node.create(backend);
  });

  tearDown(() => node.close());

  test(
    'a created child is sent once and acknowledged by its revisions',
    () async {
      final id = await node.newChild();

      final summary = await node.sync();

      expect(summary.pushSucceeded, 1);
      expect(await node.ops(id), isEmpty);
      final row = await node.row(id);
      expect((row.nameRev, row.birthDateRev), (1, 1));
      expect(row.syncState, 'synced');
      expect(backend.entity(SyncEntityType.child, id)!.values, {
        'name': 'Ancien',
        'birthDate': '2019-03-01',
      });
    },
  );

  test('an edit made during the send is a second operation the first '
      'acknowledgement leaves alone', () async {
    final id = await node.newChild();
    final first = (await node.ops(id)).single;
    final entered = Completer<void>();
    final gate = Completer<void>();
    backend.beforeReply = (_) async {
      backend.beforeReply = null;
      entered.complete();
      await gate.future;
    };

    final running = node.sync();
    await entered.future;
    await node.children.update(
      id: id,
      name: 'Nouveau',
      birthDate: DateTime(2019, 3, 1),
    );
    gate.complete();
    await running;

    final ops = await node.ops(id);
    expect(ops, hasLength(1), reason: 'only the first one was acknowledged');
    expect(ops.single.opId, isNot(first.opId));
    expect(ops.single.state, 'pending');
    expect(ops.single.patch!.fields, {'name': 'Nouveau'});
    // It now builds on the revision the first operation produced.
    expect(ops.single.patch!.baseRevisions, {'name': 1});
    var row = await node.row(id);
    expect(row.name, 'Nouveau');
    expect(row.birthDateRev, 1);
    expect(row.syncState, 'localOnly', reason: 'an operation is still queued');
    expect(backend.entity(SyncEntityType.child, id)!.values['name'], 'Ancien');

    await node.sync();

    expect(await node.ops(id), isEmpty);
    row = await node.row(id);
    expect((row.name, row.nameRev, row.syncState), ('Nouveau', 2, 'synced'));
    expect(backend.entity(SyncEntityType.child, id)!.values['name'], 'Nouveau');
  });

  test('a crash between in_flight and the acknowledgement replays the same '
      'operation id without a second effect', () async {
    final id = await node.newChild();
    final opId = (await node.ops(id)).single.opId;
    backend.loseNextResponse = true;

    final summary = await node.sync();

    expect(summary.pushFailed, 1);
    var op = (await node.ops(id)).single;
    expect((op.opId, op.state, op.attempts), (opId, 'in_flight', 1));
    expect(backend.effects, 1, reason: 'the server did apply it');

    await node.restart();
    // Leave the retry backoff.
    await (node.db.update(
      node.db.syncOutboxTable,
    )).write(const SyncOutboxTableCompanion(nextAttemptAt: Value(null)));
    op = (await node.ops(id)).single;
    expect((op.opId, op.state), (opId, 'in_flight'));

    final replay = await node.sync();

    expect(replay.pushSucceeded, 1);
    expect(backend.received, [opId, opId]);
    expect(backend.effects, 1, reason: 'a replay has no second effect');
    expect(await node.ops(id), isEmpty);
    final row = await node.row(id);
    expect((row.nameRev, row.syncState), (1, 'synced'));
  });

  test('the same field changed on both sides: the local value wins and the '
      'remote one is kept after a restart', () async {
    final id = await node.newChild();
    await node.sync();
    backend.remoteEdit(SyncEntityType.child, id, 'name', 'Distant');
    await node.children.update(
      id: id,
      name: 'Local',
      birthDate: DateTime(2019, 3, 1),
    );

    final summary = await node.sync();

    expect(summary.pushSucceeded, 1);
    expect((await node.row(id)).name, 'Local');
    final resend = (await node.ops(id)).single;
    expect(resend.patch!.fields, {'name': 'Local'});
    expect(resend.patch!.baseRevisions, {'name': 2});
    expect(backend.entity(SyncEntityType.child, id)!.values['name'], 'Distant');

    await node.restart();
    final history = await node.engine.replacedValues.listReplacedValues(id);
    expect(history, hasLength(1));
    expect(history.single.field, 'name');
    expect(history.single.value, 'Distant');
    expect(history.single.source, ReplacedValueSource.remote);
    expect(history.single.entityType, SyncEntityType.child);

    await node.sync();

    expect(backend.entity(SyncEntityType.child, id)!.values['name'], 'Local');
    expect(await node.ops(id), isEmpty);
    final row = await node.row(id);
    expect((row.name, row.nameRev, row.syncState), ('Local', 3, 'synced'));
  });

  test('different fields merge without any history', () async {
    final id = await node.newChild();
    await node.sync();
    backend.remoteEdit(SyncEntityType.child, id, 'birthDate', '2018-02-02');
    await node.children.update(
      id: id,
      name: 'Local',
      birthDate: DateTime(2019, 3, 1),
    );

    await node.sync();

    final values = backend.entity(SyncEntityType.child, id)!.values;
    expect(values, {'name': 'Local', 'birthDate': '2018-02-02'});
    expect(await node.engine.replacedValues.listReplacedValues(id), isEmpty);
    expect(await node.ops(id), isEmpty);
    expect((await node.row(id)).nameRev, 2);
  });

  test(
    'a rejected send keeps the operation in flight with the same id',
    () async {
      final id = await node.newChild();
      final opId = (await node.ops(id)).single.opId;
      backend.beforeReply = (_) => throw const SocketException('offline');

      await node.sync();
      backend.beforeReply = null;
      await (node.db.update(
        node.db.syncOutboxTable,
      )).write(const SyncOutboxTableCompanion(nextAttemptAt: Value(null)));
      // A new edit cannot touch the operation that may already be applied.
      await node.children.update(
        id: id,
        name: 'Autre',
        birthDate: DateTime(2019, 3, 1),
      );
      await node.sync();
      await node.sync();

      expect(backend.received.take(2), [opId, opId]);
      expect(backend.entity(SyncEntityType.child, id)!.values['name'], 'Autre');
      expect(await node.ops(id), isEmpty);
    },
  );

  test(
    'an artwork whose media are not described waits instead of being sent',
    () async {
      final childId = await node.newChild();
      final source = await makeTestImage(node.root, 'src.jpg');
      final artworkId =
          (await node.artworks.create(
                    childId: childId,
                    sourceImageFile: source,
                    addedAt: DateTime(2026, 1, 1),
                  )
                  as ActionSuccess<String>)
              .value;
      await node.artworks.updateStory(id: artworkId, story: 'Un dragon');

      final summary = await node.sync();

      expect(summary.pushSucceeded, 1, reason: 'only the child');
      expect(backend.received, hasLength(1));
      final ops = await node.outbox.operationsOf(
        SyncEntityKind.artwork,
        artworkId,
      );
      expect(ops, hasLength(1));
      expect(ops.single.state, 'pending');
      expect(ops.single.patchJson, isNull);
      expect(await node.engine.outbox.countPending(), 1);
    },
  );

  test('an edit merged into a pending operation after the round started is '
      'the one that is sent', () async {
    final y = await node.newChild('Y');
    final x = await node.newChild('X');
    await node.sync();
    // Both have a patch of their own, Y queued before X.
    for (final entry in [(y, 'Y2'), (x, 'X2')]) {
      await node.children.update(
        id: entry.$1,
        name: entry.$2,
        birthDate: DateTime(2019, 3, 1),
      );
    }
    final entered = Completer<void>();
    final gate = Completer<void>();
    backend.beforeReply = (patch) async {
      if (patch.entityId != y) return;
      backend.beforeReply = null;
      entered.complete();
      await gate.future;
    };

    final running = node.sync();
    await entered.future;
    // X's operation is still pending: this edit is merged into it.
    await node.children.update(
      id: x,
      name: 'X3',
      birthDate: DateTime(2019, 3, 1),
    );
    gate.complete();
    await running;
    await node.sync();

    expect(backend.entity(SyncEntityType.child, x)!.values['name'], 'X3');
    expect(backend.entity(SyncEntityType.child, y)!.values['name'], 'Y2');
    expect(await node.ops(x), isEmpty);
    expect(await node.ops(y), isEmpty);
    expect((await node.row(x)).name, 'X3');
  });

  test('an operation in flight without a patch gets its patch persisted on '
      'the first attempt and replays it', () async {
    final id = await node.newChild();
    await node.sync();
    await node.outbox.enqueue(
      entity: SyncEntityKind.child,
      entityId: id,
      op: SyncOutboxOp.upsert,
    );
    final op = (await node.ops(id)).single;
    // Marked by the legacy path: in flight, no patch.
    await node.outbox.markInFlight(op.seq);
    expect((await node.ops(id)).single.patchJson, isNull);
    final before = backend.received.length;
    backend.beforeReply = (_) => throw const SocketException('offline');

    await node.sync();

    backend.beforeReply = null;
    final persisted = (await node.ops(id)).single;
    expect(persisted.state, 'in_flight');
    expect(persisted.patch!.fields['name'], 'Ancien');
    await (node.db.update(
      node.db.syncOutboxTable,
    )).write(const SyncOutboxTableCompanion(nextAttemptAt: Value(null)));
    await node.children.update(
      id: id,
      name: 'Autre',
      birthDate: DateTime(2019, 3, 1),
    );

    await node.sync();
    await node.sync();

    expect(backend.received.skip(before).take(2), [op.opId, op.opId]);
    expect(backend.effects, 3, reason: 'create, the replayed one, the edit');
    expect(backend.entity(SyncEntityType.child, id)!.values['name'], 'Autre');
    expect(await node.ops(id), isEmpty);
  });

  test('an artwork of a demo child is dropped without being sent', () async {
    const demoChild = '${debugDemoIdPrefix}child';
    const demoArtwork = '${debugDemoIdPrefix}artwork';
    await node.db
        .into(node.db.childrenTable)
        .insert(
          ChildrenTableCompanion.insert(
            id: demoChild,
            name: 'Demo',
            birthDate: DateTime(2019, 3, 1),
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
        );
    await node.db
        .into(node.db.artworksTable)
        .insert(
          ArtworksTableCompanion.insert(
            id: demoArtwork,
            childId: demoChild,
            addedAt: DateTime(2026, 1, 1),
          ),
        );
    await node.outbox.enqueue(
      entity: SyncEntityKind.artwork,
      entityId: demoArtwork,
      op: SyncOutboxOp.upsert,
    );

    await node.sync();

    expect(backend.received, isEmpty);
    expect(
      await node.outbox.operationsOf(SyncEntityKind.artwork, demoArtwork),
      isEmpty,
    );
  });

  group('history of replaced values', () {
    test('entries older than 30 days are removed, newer ones kept', () async {
      var now = DateTime(2026, 9, 1);
      final history = ReplacedValuesRepository(node.db, now: () => now);
      await history.record(
        entityType: SyncEntityType.child,
        entityId: 'c',
        field: 'name',
        value: 'Ancien',
        source: ReplacedValueSource.remote,
      );
      now = DateTime(2026, 9, 20);
      await history.record(
        entityType: SyncEntityType.child,
        entityId: 'c',
        field: 'name',
        value: 'Récent',
        source: ReplacedValueSource.local,
      );

      expect(await history.purgeExpired(now: DateTime(2026, 9, 30)), 0);
      expect(await history.purgeExpired(now: DateTime(2026, 10, 2)), 1);

      final left = await history.listReplacedValues('c');
      expect(left.map((v) => v.value), ['Récent']);
      expect(left.single.source, ReplacedValueSource.local);
    });

    test('a synchronization run purges the expired entries', () async {
      await node.db
          .into(node.db.replacedValuesTable)
          .insert(
            ReplacedValuesTableCompanion.insert(
              id: 'old',
              entityType: 'child',
              entityId: 'c',
              field: 'name',
              valueJson: '"x"',
              source: 'remote',
              createdAt: DateTime.now().subtract(const Duration(days: 31)),
            ),
          );

      await node.sync();

      expect(await node.db.select(node.db.replacedValuesTable).get(), isEmpty);
    });
  });
}
