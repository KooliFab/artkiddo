// Harness of the scenarios: several devices (each a [Node]: its own
// database and vault files, closable and reopenable over the same disk) facing
// one remote side whose faults are triggered one by one, so a scenario reads
// as a short story and ends with a full comparison of what every side holds.

import 'dart:io';

import 'package:artkiddo_core/artkiddo_core.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../sync/operation_sync_test.dart'
    show FakeProtocolBackend, Node, ServerEntity;
import '../sync/sync_engine_test.dart' show makeTestImage;

/// The remote side with the faults a scenario needs, on top of the merge
/// rules, the operation ids and the ordered journal of [FakeProtocolBackend].
class ScenarioBackend extends FakeProtocolBackend {
  /// The next patch is delivered twice (a retry the client never saw): the
  /// second delivery must be a replay.
  bool duplicateNextRequest = false;

  /// The next patch never reaches the remote side (nothing is applied).
  Object? dropNextRequest;

  /// Every patch fails with this until it is cleared (the network is down, the
  /// session is gone, the quota is full, the service is unavailable).
  Object? outage;

  /// Every journal read fails with this until it is cleared.
  Object? pullOutage;

  @override
  Future<MutationReceipt> applyPatch(EntityPatch patch) async {
    final down = outage;
    if (down != null) {
      received.add(patch.opId);
      throw down;
    }
    final dropped = dropNextRequest;
    if (dropped != null) {
      dropNextRequest = null;
      received.add(patch.opId);
      throw dropped;
    }
    if (duplicateNextRequest) {
      duplicateNextRequest = false;
      await super.applyPatch(patch);
    }
    return super.applyPatch(patch);
  }

  @override
  Future<SyncChangePage> pullChanges(
    ChangeCursor? cursor, {
    int limit = kMaxChangePageSize,
  }) {
    final down = pullOutage;
    if (down != null) {
      pulledAfter.add(cursor?.value);
      return Future.error(down);
    }
    return super.pullChanges(cursor, limit: limit);
  }

  /// What the remote side holds for every entity: lifecycle and values.
  Map<String, Object?> state() => {
    for (final MapEntry(:key, :value) in entities.entries)
      key: {'lifecycle': value.lifecycle, ...value.values},
  };

  ServerEntity child(String id) => entity(SyncEntityType.child, id)!;
  ServerEntity artwork(String id) => entity(SyncEntityType.artwork, id)!;
}

/// Several devices of one family on one [ScenarioBackend].
class World {
  final backend = ScenarioBackend();
  final _devices = <Node>[];

  Future<Node> device({VaultFileOps? fileOps}) async {
    final node = fileOps == null
        ? await Node.create(backend)
        : await Node.create(backend, fileOps: fileOps);
    _devices.add(node);
    return node;
  }

  Future<void> dispose() async {
    for (final node in _devices) {
      await node.close();
    }
    _devices.clear();
  }

  /// Both directions fail with [error] until [recover].
  void goDown(Object error, {bool pulls = true}) {
    backend.outage = error;
    if (pulls) backend.pullOutage = error;
  }

  void recover() {
    backend.outage = null;
    backend.pullOutage = null;
  }

  /// Runs every device's synchronization, backoff released, until a whole
  /// round changes nothing (nothing queued, nothing new from the journal).
  Future<void> settle(Iterable<Node> nodes, {int maxRounds = 8}) async {
    for (var round = 0; round < maxRounds; round++) {
      var busy = false;
      for (final node in nodes) {
        await node.releaseBackoff();
        final before = backend.effects;
        final summary = await node.sync();
        if (summary.pushSucceeded > 0 ||
            summary.pulledChildren > 0 ||
            summary.pulledArtworks > 0 ||
            backend.effects != before ||
            await node.outbox.countPending() > 0) {
          busy = true;
        }
      }
      if (!busy) return;
    }
    fail('the devices did not settle in $maxRounds rounds');
  }
}

extension NodeScenario on Node {
  /// Lets the queued operations be sent again now.
  Future<void> releaseBackoff() => db
      .update(db.syncOutboxTable)
      .write(const SyncOutboxTableCompanion(nextAttemptAt: Value(null)));

  Future<ChildEntity?> childRow(String id) => (db.select(
    db.childrenTable,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<ArtworkEntity?> artworkRow(String id) => (db.select(
    db.artworksTable,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<SyncOutboxEntryEntity>> artworkOps(String id) =>
      outbox.operationsOf(SyncEntityKind.artwork, id);

  Future<List<ReplacedValue>> replaced(String id) =>
      engine.replacedValues.listReplacedValues(id);

  /// Every child as `name|birthDate`, by id: what the device shows.
  Future<Map<String, String>> childrenView() async => {
    for (final row in await db.select(db.childrenTable).get())
      row.id: '${row.name}|${syncDateValue(row.birthDate)}',
  };

  /// Every file of the vault by relative path, with its SHA-256 and size:
  /// "the bytes of the files" a scenario compares before and after.
  Future<Map<String, String>> vaultBytes() async {
    final docs = Directory(p.join(root.path, 'docs'));
    final files = <String, String>{};
    if (!docs.existsSync()) return files;
    for (final entity in docs.listSync(recursive: true)) {
      if (entity is! File) continue;
      final content = await entity.readAsBytes();
      files[p.relative(entity.path, from: docs.path)] =
          '${sha256.convert(content)}:${content.length}';
    }
    return files;
  }

  /// No `.tmp` write left behind and no reference without its file (INV-04):
  /// every artwork path and every `present` media version has its file.
  Future<void> expectNoDanglingReference() async {
    final bytes = await vaultBytes();
    expect(
      bytes.keys.where((path) => path.endsWith(kTempFileSuffix)),
      isEmpty,
      reason: 'an unfinished write survived',
    );
    for (final row in await db.select(db.artworksTable).get()) {
      for (final path in [
        row.relativeImagePath,
        row.displayImagePath,
        row.thumbnailImagePath,
        row.relativeAudioPath,
      ]) {
        if (path == null) continue;
        expect(
          bytes.containsKey(path),
          isTrue,
          reason: 'artwork ${row.id} points at $path, which is not there',
        );
      }
    }
    for (final version in await db.select(db.mediaVersionsTable).get()) {
      if (version.state == MediaVersionState.present.name) {
        expect(
          bytes.containsKey(version.localPath),
          isTrue,
          reason: 'media ${version.mediaId} is present but has no file',
        );
      }
    }
  }

  /// A local artwork with a real photo, never sent.
  Future<String> newLocalArtwork(
    String childId, {
    int seed = 0,
    String? story,
  }) async {
    final source = await makeTestImage(
      root,
      'scenario_src_$seed.jpg',
      seed: seed,
    );
    return (await artworks.create(
              childId: childId,
              sourceImageFile: source,
              addedAt: DateTime(2026, 1, 1),
              story: story,
            )
            as ActionSuccess<String>)
        .value;
  }
}

/// Another device creates an artwork on the remote side, its photo published.
String remoteArtwork(
  ScenarioBackend backend,
  String childId, {
  required String id,
  required String mediaId,
  Map<String, Object?> extra = const {},
}) {
  final photo = MediaDescriptor(
    mediaId: mediaId,
    version: 1,
    role: MediaRole.optimized,
    format: MediaFormat.jpeg,
    byteSize: 1000,
    sha256: 'a' * 64,
    widthPx: 800,
    heightPx: 600,
  );
  backend.remoteCreate(
    SyncEntityType.artwork,
    id,
    {
      'childId': childId,
      'addedAt': syncInstantValue(DateTime.utc(2026, 1, 1)),
      'photo': photo.ref.toJson(),
      ...extra,
    },
    media: [photo],
  );
  return id;
}

String remoteChild(ScenarioBackend backend, String id, [String name = 'Léa']) {
  backend.remoteCreate(SyncEntityType.child, id, {
    'name': name,
    'birthDate': '2019-03-01',
  });
  return id;
}
