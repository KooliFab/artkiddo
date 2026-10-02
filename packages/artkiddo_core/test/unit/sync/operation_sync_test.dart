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

import 'sync_engine_test.dart' show makeTestImage;

class ServerEntity {
  final SyncEntityType type;
  final String id;
  final values = <String, Object?>{};
  final revisions = <String, int>{};
  final media = <MediaDescriptor>[];
  final unavailable = <MediaRef>[];
  String lifecycle = 'active';

  ServerEntity(this.type, this.id);

  bool get purged => lifecycle == 'purged';

  EntitySnapshot snapshot() {
    final fields = {...values, 'lifecycle': lifecycle};
    final referenced = {
      for (final entry in fields.entries)
        if (syncFieldSpecs(type)[entry.key]!.type == SyncValueType.mediaRef &&
            entry.value != null)
          MediaRef.fromJson(entry.value),
    };
    return EntitySnapshot(
      fields: fields,
      revisions: {
        for (final entry in revisions.entries)
          if (entry.value >= 1) entry.key: entry.value,
      },
      media: [
        for (final m in media)
          if (referenced.contains(m.ref)) m,
      ],
      unavailableMedia: [
        for (final ref in unavailable)
          if (referenced.contains(ref)) ref,
      ],
    );
  }
}

/// In-memory remote side applying the merge rules of the sync protocol and
/// keeping an ordered change journal: a change gets its `seq` when it is
/// committed, never before.
class FakeProtocolBackend implements SyncProtocolBackend {
  final entities = <String, ServerEntity>{};
  final receipts = <String, MutationReceipt>{};

  final journal = <SyncChange>[];
  int generation = 1;

  /// Largest page served, whatever the device asks for.
  int pageSize = kMaxChangePageSize;

  /// Cursor value of every `pullChanges` call, in order (null = beginning).
  final pulledAfter = <String?>[];

  /// Runs right after a page is handed out, where a concurrent write lands.
  void Function(int pageIndex)? onPageServed;
  int _pagesServed = 0;

  /// Thrown by the next `pullChanges` call, after it is recorded.
  Object? failNextPull;

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
  void remoteEdit(
    SyncEntityType type,
    String id,
    String field,
    Object? value, {
    List<MediaDescriptor> media = const [],
  }) {
    final e = entities['${type.name}/$id']!;
    e.values[field] = value;
    e.revisions[field] = (e.revisions[field] ?? 0) + 1;
    e.media.addAll(media);
    commit(e);
  }

  /// Another device creates an entity.
  ServerEntity remoteCreate(
    SyncEntityType type,
    String id,
    Map<String, Object?> values, {
    List<MediaDescriptor> media = const [],
  }) {
    final e = entities['${type.name}/$id'] = ServerEntity(type, id);
    e.values.addAll(values);
    for (final field in values.keys) {
      if (field != ArtworkSyncFields.addedBy) e.revisions[field] = 1;
    }
    e.revisions['lifecycle'] = 1;
    e.media.addAll(media);
    commit(e);
    return e;
  }

  /// Another device trashes, restores or purges an entity. Purging a child
  /// first trashes its active artworks, as the remote side does.
  void remoteLifecycle(SyncEntityType type, String id, String lifecycle) {
    final e = entities['${type.name}/$id']!;
    if (type == SyncEntityType.child && lifecycle == 'purged') {
      for (final artwork in entities.values) {
        if (artwork.type == SyncEntityType.artwork &&
            artwork.values['childId'] == id &&
            artwork.lifecycle == 'active') {
          remoteLifecycle(SyncEntityType.artwork, artwork.id, 'trashed');
        }
      }
    }
    final from = e.lifecycle;
    e.lifecycle = lifecycle;
    e.revisions['lifecycle'] = (e.revisions['lifecycle'] ?? 0) + 1;
    commit(e, from: from);
  }

  /// Appends the change that [e] just went through to the journal.
  void commit(ServerEntity e, {String? opId, String? from}) {
    final kind = switch (e.lifecycle) {
      'purged' => SyncChangeKind.purge,
      'trashed' when from != 'trashed' => SyncChangeKind.trash,
      'active' when from == 'trashed' => SyncChangeKind.restore,
      _ => SyncChangeKind.upsert,
    };
    journal.add(
      SyncChange(
        seq: journal.isEmpty ? 1 : journal.last.seq + 1,
        kind: kind,
        entityType: e.type,
        entityId: e.id,
        snapshot: kind == SyncChangeKind.purge ? null : e.snapshot(),
        opId: opId,
      ),
    );
  }

  /// The remote history is rebuilt (a restore): new generation, one change
  /// per entity still there, children first. Older cursors become invalid.
  void rebuildHistory({bool Function(ServerEntity e)? keep}) {
    generation++;
    journal.clear();
    for (final type in SyncEntityType.values) {
      for (final e in entities.values.toList()) {
        if (e.type != type || e.purged) continue;
        if (keep != null && !keep(e)) {
          entities.remove('${e.type.name}/${e.id}');
          continue;
        }
        commit(e);
      }
    }
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
    final edit = !patch.fields.containsKey('lifecycle');
    if (current == null && !patch.isCreation ||
        (current?.purged ?? false) ||
        (edit && current?.lifecycle == 'trashed')) {
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
    final e =
        current ??
        (entities[key] = ServerEntity(patch.entityType, patch.entityId));
    if (current == null) e.revisions['lifecycle'] = 1;
    final from = e.lifecycle;
    final accepted = <String, int>{};
    final conflicts = <FieldConflict>[];
    var changed = current == null;
    for (final f in patch.fields.entries) {
      final revision = e.revisions[f.key] ?? 0;
      if (f.key == 'lifecycle') {
        if (patch.entityType == SyncEntityType.child && f.value == 'purged') {
          remoteLifecycle(SyncEntityType.child, patch.entityId, 'purged');
          return MutationReceipt(
            opId: patch.opId,
            accepted: {'lifecycle': e.revisions['lifecycle']!},
          );
        }
        e.lifecycle = f.value as String;
        e.revisions[f.key] = revision + 1;
        accepted[f.key] = revision + 1;
        changed = true;
      } else if (patch.baseRevisions[f.key] == revision) {
        changed |= e.values[f.key] != f.value || revision == 0;
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
    e.media.addAll(patch.media);
    if (changed) commit(e, opId: patch.opId, from: from);
    return MutationReceipt(
      opId: patch.opId,
      accepted: accepted,
      conflicts: conflicts,
    );
  }

  @override
  Future<SyncChangePage> pullChanges(
    ChangeCursor? cursor, {
    int limit = kMaxChangePageSize,
  }) async {
    pulledAfter.add(cursor?.value);
    final failure = failNextPull;
    if (failure != null) {
      failNextPull = null;
      throw failure;
    }
    if (cursor != null && cursor.generation != generation) {
      throw ChangeCursorInvalidException(
        reason: ChangeCursorInvalidReason.generationChanged,
        currentGeneration: generation,
      );
    }
    final after = cursor == null ? 0 : int.parse(cursor.value);
    final size = limit < pageSize ? limit : pageSize;
    final rest = [
      for (final change in journal)
        if (change.seq > after) change,
    ];
    final changes = rest.take(size).toList();
    final page = SyncChangePage(
      changes: changes,
      nextCursor: ChangeCursor(
        value: '${changes.isEmpty ? after : changes.last.seq}',
        generation: generation,
      ),
      hasMore: rest.length > size,
      generation: generation,
    );
    onPageServed?.call(_pagesServed++);
    return page;
  }

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

  /// Disk primitives of the vault (a test makes them fail on demand).
  final VaultFileOps fileOps;

  /// The family the signed-in account belongs to.
  String familyId = 'family-a';
  late AppDatabase db;
  late LocalVault vault;
  late SyncOutboxRepository outbox;
  late DriftChildrenRepository children;
  late DriftArtworksRepository artworks;
  late SyncEngine engine;

  Node._(this.root, this.backend, this.fileOps);

  static Future<Node> create(
    FakeProtocolBackend backend, {
    VaultFileOps fileOps = const DiskVaultFileOps(),
  }) async {
    final root = await Directory.systemTemp.createTemp('artkiddo_opsync_');
    Directory(p.join(root.path, 'docs')).createSync();
    return Node._(root, backend, fileOps).._open();
  }

  void _open() {
    db = AppDatabase.forTesting(
      NativeDatabase(File(p.join(root.path, 'test.sqlite'))),
    );
    vault = LocalVault(
      documentsDirProvider: () async => Directory(p.join(root.path, 'docs')),
      fileOps: fileOps,
    );
    outbox = SyncOutboxRepository(db);
    children = DriftChildrenRepository(db, vault, outbox: outbox);
    artworks = DriftArtworksRepository(db, vault, outbox: outbox);
    engine = newEngine();
  }

  /// An engine over this node's files; [userId] null means signed out.
  SyncEngine newEngine({String? Function()? currentUserId}) => SyncEngine(
    db: db,
    vault: vault,
    artworksRepo: artworks,
    protocolBackend: backend,
    ensureMyFamily: () async => familyId,
    outbox: outbox,
    vaultMeta: VaultMetaRepository(db),
    currentUserId: currentUserId ?? () => 'user',
  );

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
    // The app dies before reading the journal, where the echo of the
    // operation would acknowledge it.
    backend.failNextPull = const SocketException('killed');

    await expectLater(node.sync(), throwsA(isA<SocketException>()));

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
      backend.failNextPull = const SocketException('offline');

      await expectLater(node.sync(), throwsA(isA<SocketException>()));
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
    // Left in flight without a patch by an earlier version of the engine.
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

    test('a value replaced again is kept 30 days from its last '
        'replacement', () async {
      var now = DateTime(2026, 9, 1);
      final history = ReplacedValuesRepository(node.db, now: () => now);
      Future<void> replace() => history.record(
        entityType: SyncEntityType.child,
        entityId: 'c',
        field: 'name',
        value: 'Encore',
        source: ReplacedValueSource.remote,
      );
      await replace();
      now = DateTime(2026, 9, 29);
      await replace();

      expect(await history.purgeExpired(now: DateTime(2026, 10, 5)), 0);
      final left = await history.listReplacedValues('c');
      expect(left.single.createdAt, DateTime(2026, 9, 29));
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
