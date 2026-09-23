// C-06 convergence engine tests.
//
// Each "device" is a fully independent local vault (its own temp-file
// SQLite database and its own temp documents directory — real persistence,
// exactly like `local_data_test.dart`), wired to a *shared*
// `FakeHomeCloudApi`/`FakeObjectUploader`/`FakeObjectDownloader` standing in
// for cloud backend + remote object storage. Two devices sharing the fakes is
// what actually exercises convergence: what one device pushes is what the
// other pulls, through the exact same `SyncEngine` code either device runs
// — there is no special-cased "test-only" sync path.
//
// The delete-wins/last-write-wins server rules this suite relies on
// (`DeletedRowUpdateRejectedException`, server-assigned `updated_at`) are
// modeled by `FakeHomeCloudApi` to match migration `0004`'s trigger, which
// is verified separately against the backend integration test suite.

import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'package:artkiddo_core/artkiddo_core.dart';

import 'fakes.dart';

/// One independent local vault + its own `SyncEngine`, sharing the fakes
/// passed in with every other `Device` in a test — the household's shared
/// cloud.
class Device {
  final Directory tempRoot;
  final AppDatabase db;
  final LocalVault vault;
  final DriftChildrenRepository children;
  final DriftArtworksRepository artworks;
  final SyncEngine engine;
  final String userId;
  final FakeHomeCloudApi cloudApi;

  Device._(
    this.tempRoot,
    this.db,
    this.vault,
    this.children,
    this.artworks,
    this.engine,
    this.userId,
    this.cloudApi,
  );

  static Future<Device> create({
    required FakeHomeCloudApi cloudApi,
    required FakeObjectUploader uploader,
    required FakeObjectDownloader downloader,
    required String userId,
  }) async {
    final tempRoot = await Directory.systemTemp.createTemp(
      'artkiddo_sync_device_',
    );
    final docsDir = Directory(p.join(tempRoot.path, 'docs'))
      ..createSync(recursive: true);
    final dbFile = File(p.join(tempRoot.path, 'test.sqlite'));
    final db = AppDatabase.forTesting(NativeDatabase(dbFile));
    final vault = LocalVault(documentsDirProvider: () async => docsDir);
    final childrenRepo = DriftChildrenRepository(db, vault);
    final artworksRepo = DriftArtworksRepository(db, vault);
    final engine = SyncEngine(
      db: db,
      vault: vault,
      uploader: uploader,
      downloader: downloader,
      childrenRepo: childrenRepo,
      artworksRepo: artworksRepo,
      cloudApi: cloudApi,
      outbox: SyncOutboxRepository(db),
      vaultMeta: VaultMetaRepository(db),
      currentUserId: () => userId,
    );
    return Device._(
      tempRoot,
      db,
      vault,
      childrenRepo,
      artworksRepo,
      engine,
      userId,
      cloudApi,
    );
  }

  /// Sets the shared fake's "currently authenticated account" to this
  /// device's user before running a sync — the real app only ever has one
  /// remote auth session per process; this models switching which
  /// account/device is "active" between calls in a single test process.
  Future<SyncRunSummary> sync() async {
    cloudApi.currentUserId = userId;
    return engine.syncAll();
  }

  Future<void> close() async {
    await db.close();
    if (await tempRoot.exists()) await tempRoot.delete(recursive: true);
  }
}

Future<File> makeTestImage(
  Directory dir,
  String name, {
  int width = 40,
  int height = 30,
  int seed = 0,
}) async {
  final image = img.Image(width: width, height: height);
  img.fill(
    image,
    color: img.ColorRgb8(
      (seed * 37) % 255,
      (seed * 61) % 255,
      (seed * 89) % 255,
    ),
  );
  final bytes = img.encodeJpg(image, quality: 80);
  final file = File(p.join(dir.path, name));
  await file.writeAsBytes(bytes);
  return file;
}

Future<String> createSyncedArtwork(
  Device device, {
  required String childId,
  String story = 'une histoire',
  File? sourceAudioFile,
  int? audioDurationMs,
  int seed = 0,
}) async {
  final source = await makeTestImage(
    device.tempRoot,
    'src_$seed.jpg',
    seed: seed,
  );
  final result = await device.artworks.create(
    childId: childId,
    sourceImageFile: source,
    sourceAudioFile: sourceAudioFile,
    audioDurationMs: audioDurationMs,
    addedAt: DateTime(2024, 1, 1),
    story: story,
  );
  return (result as ActionSuccess<String>).value;
}

void main() {
  late FakeHomeCloudApi cloudApi;
  late FakeObjectUploader uploader;
  late FakeObjectDownloader downloader;
  final devices = <Device>[];

  // Every test intentionally opens several independent `AppDatabase`
  // instances at once (one per simulated device) — the multi-database
  // warning is meant for accidental concurrent misuse of the *same* file,
  // not this pattern (same convention as `local_data_test.dart`).
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() {
    cloudApi = FakeHomeCloudApi();
    uploader = FakeObjectUploader();
    downloader = FakeObjectDownloader(uploader.objects);
  });

  tearDown(() async {
    for (final d in devices) {
      await d.close();
    }
    devices.clear();
  });

  Future<Device> newDevice(String userId) async {
    final d = await Device.create(
      cloudApi: cloudApi,
      uploader: uploader,
      downloader: downloader,
      userId: userId,
    );
    devices.add(d);
    return d;
  }

  group('family creation at first cloud send', () {
    test('creates a family and attaches this vault to it, as Parent', () async {
      final a = await newDevice('user-a');
      expect(
        await a.vault.artworksDirectory,
        isNotNull,
      ); // sanity: vault usable

      expect(await VaultMetaRepository(a.db).getFamilyId(), isNull);

      await a.sync();

      final familyId = await VaultMetaRepository(a.db).getFamilyId();
      expect(familyId, isNotNull);
      expect(cloudApi.membership['user-a'], familyId);
    });

    test(
      'a second sync for the same account is idempotent — same family, no duplicate creation',
      () async {
        final a = await newDevice('user-a');
        await a.sync();
        final familyAfterFirst = await VaultMetaRepository(a.db).getFamilyId();

        await a.sync();
        final familyAfterSecond = await VaultMetaRepository(a.db).getFamilyId();

        expect(familyAfterSecond, familyAfterFirst);
      },
    );
  });

  group('progress', () {
    test('reports sending against a known total, then receiving', () async {
      final a = await newDevice('user-a');
      await a.sync(); // creates the family
      final familyId = (await VaultMetaRepository(a.db).getFamilyId())!;
      final childId =
          (await a.children.create(name: 'Zoé', birthDate: DateTime(2019))
                  as ActionSuccess<String>)
              .value;
      for (var i = 0; i < 3; i++) {
        await createSyncedArtwork(a, childId: childId, seed: i);
      }

      final sent = <SyncProgress>[];
      cloudApi.currentUserId = a.userId;
      await a.engine.syncAll(onProgress: sent.add);

      final sending = sent.where((p) => p.phase == SyncPhase.sending);
      // One child + three artworks were waiting in the outbox.
      expect(sending.map((p) => p.done), [0, 1, 2, 3, 4]);
      expect(sending.every((p) => p.total == 4), isTrue);
      expect(
        sent.indexWhere((p) => p.phase == SyncPhase.receiving),
        greaterThan(sent.lastIndexWhere((p) => p.phase == SyncPhase.sending)),
        reason: 'receiving starts only once sending is over',
      );

      cloudApi.seedMembership('user-b', familyId);
      final b = await newDevice('user-b');
      final received = <SyncProgress>[];
      cloudApi.currentUserId = b.userId;
      await b.engine.syncAll(onProgress: received.add);

      final receiving = received
          .where((p) => p.phase == SyncPhase.receiving)
          .toList();
      expect(receiving.map((p) => p.done), [0, 1, 2, 3]);
      expect(
        receiving.every((p) => p.total == null),
        isTrue,
        reason: 'remote pages have no known total',
      );
    });
  });

  group('D13 — join and restore are the same operation', () {
    test(
      'a fresh device joining an already-populated family pulls everything (restore)',
      () async {
        final a = await newDevice('user-a');
        await a.sync(); // creates the family
        final familyId = (await VaultMetaRepository(a.db).getFamilyId())!;

        final childId =
            (await a.children.create(
                      name: 'Zoé',
                      birthDate: DateTime(2019, 3, 1),
                    )
                    as ActionSuccess<String>)
                .value;
        for (var i = 0; i < 5; i++) {
          await createSyncedArtwork(
            a,
            childId: childId,
            story: 'oeuvre $i',
            seed: i,
          );
        }
        await a.sync(); // pushes the child + 5 artworks

        // A second member, already invited (C-11 territory — simulated by
        // seeding membership directly) opens the app on a brand-new device.
        cloudApi.seedMembership('user-b', familyId);
        final b = await newDevice('user-b');
        expect(await b.children.watchAll().first, isEmpty);
        expect(await b.artworks.watch().first, isEmpty);

        await b.sync();

        final bChildren = await b.children.watchAll().first;
        final bArtworks = await b.artworks.watch().first;
        expect(bChildren, hasLength(1));
        expect(bChildren.single.id, childId);
        expect(bArtworks, hasLength(5));
        // T-R3: the original ids survive the restore, never regenerated.
        expect(bArtworks.map((m) => m.id).toSet(), hasLength(5));
      },
    );

    test('restoring twice in a row creates no duplicates', () async {
      final a = await newDevice('user-a');
      await a.sync();
      final familyId = (await VaultMetaRepository(a.db).getFamilyId())!;
      final childId =
          (await a.children.create(name: 'Léo', birthDate: DateTime(2020, 1, 1))
                  as ActionSuccess<String>)
              .value;
      await createSyncedArtwork(a, childId: childId);
      await a.sync();

      cloudApi.seedMembership('user-b', familyId);
      final b = await newDevice('user-b');
      await b.sync();
      await b.sync(); // restore again — e.g. app relaunch, or a retry

      expect(await b.children.watchAll().first, hasLength(1));
      expect(await b.artworks.watch().first, hasLength(1));
    });

    test(
      'a family with children but no artworks yet restores without error or a stuck screen',
      () async {
        // Annex §2.1: children pushed before any artwork existed, on the
        // old engine — must not crash or hang the new one.
        final a = await newDevice('user-a');
        await a.sync();
        final familyId = (await VaultMetaRepository(a.db).getFamilyId())!;
        await a.children.create(
          name: 'Bébé sans dessin',
          birthDate: DateTime(2025, 6, 1),
        );
        await a.sync();

        cloudApi.seedMembership('user-b', familyId);
        final b = await newDevice('user-b');
        await b.sync();

        expect(await b.children.watchAll().first, hasLength(1));
        expect(await b.artworks.watch().first, isEmpty);
      },
    );

    test(
      '40 local artworks + 5 already in the family converge to 45 on both sides',
      () async {
        final a = await newDevice('user-a');
        await a.sync();
        final familyId = (await VaultMetaRepository(a.db).getFamilyId())!;
        final childId =
            (await a.children.create(
                      name: 'Family',
                      birthDate: DateTime(2018, 1, 1),
                    )
                    as ActionSuccess<String>)
                .value;
        for (var i = 0; i < 5; i++) {
          await createSyncedArtwork(a, childId: childId, seed: i);
        }
        await a.sync();

        // A new member's local vault already has 40 artworks of its own
        // (pre-account usage) attached to its own local child before ever
        // touching the cloud.
        cloudApi.seedMembership('user-b', familyId);
        final b = await newDevice('user-b');
        final bChildId =
            (await b.children.create(
                      name: 'Family',
                      birthDate: DateTime(2018, 1, 1),
                    )
                    as ActionSuccess<String>)
                .value;
        for (var i = 0; i < 40; i++) {
          await createSyncedArtwork(b, childId: bChildId, seed: 100 + i);
        }

        await b.sync();

        // D8's "oui" path: today `syncAll` always pushes every local-only
        // row it finds queued (see the C-06 report — the interactive prompt
        // itself is out of scope for this ticket). 45 artworks total in
        // the family; B sees all of them locally.
        expect(cloudApi.artworksInFamily(familyId), 45);
        expect(await b.artworks.watch().first, hasLength(45));

        await a.sync();
        expect(await a.artworks.watch().first, hasLength(45));
      },
    );
  });

  group('D9 — delete wins over a concurrent modification', () {
    test(
      'A deletes, then B pushes a stale content edit on the same row: the delete wins',
      () async {
        final a = await newDevice('user-a');
        await a.sync();
        final familyId = (await VaultMetaRepository(a.db).getFamilyId())!;
        final childId =
            (await a.children.create(name: 'C', birthDate: DateTime(2020, 1, 1))
                    as ActionSuccess<String>)
                .value;
        final mpId = await createSyncedArtwork(
          a,
          childId: childId,
          story: 'original',
        );
        await a.sync();

        cloudApi.seedMembership('user-b', familyId);
        final b = await newDevice('user-b');
        await b.sync(); // B now has the artwork locally too

        // A deletes it and pushes first.
        final delResult = await a.artworks.delete(mpId);
        expect(delResult, isA<ActionSuccess<void>>());
        await a.sync();
        expect(cloudApi.artworkIsDeleted(mpId), isTrue);

        // B, unaware, edits the anecdote on its own (still-local) copy and
        // pushes afterwards.
        final editResult = await b.artworks.updateStory(
          id: mpId,
          story: 'édité par B, trop tard',
        );
        expect(editResult, isA<ActionSuccess<void>>());
        await b.sync();

        // The delete still wins: content on the server is unchanged by B's
        // edit, and B's own local row converges to "gone" on its next pull.
        expect(cloudApi.artworkStory(mpId), 'original');
        expect(cloudApi.artworkIsDeleted(mpId), isTrue);
        expect(await b.artworks.getById(mpId), isNull);
      },
    );

    test(
      'B edits first (succeeds), then A deletes afterwards: still deleted, edit is moot',
      () async {
        final a = await newDevice('user-a');
        await a.sync();
        final familyId = (await VaultMetaRepository(a.db).getFamilyId())!;
        final childId =
            (await a.children.create(name: 'C', birthDate: DateTime(2020, 1, 1))
                    as ActionSuccess<String>)
                .value;
        final mpId = await createSyncedArtwork(
          a,
          childId: childId,
          story: 'original',
        );
        await a.sync();

        cloudApi.seedMembership('user-b', familyId);
        final b = await newDevice('user-b');
        await b.sync();

        await b.artworks.updateStory(id: mpId, story: 'édité par B, à temps');
        await b.sync();
        expect(cloudApi.artworkStory(mpId), 'édité par B, à temps');

        await a.artworks.delete(mpId);
        await a.sync();

        expect(cloudApi.artworkIsDeleted(mpId), isTrue);
        await b.sync();
        expect(await b.artworks.getById(mpId), isNull);
      },
    );

    test(
      'a deleted child cascades its tombstone to its artworks (D18), converging to both devices',
      () async {
        final a = await newDevice('user-a');
        await a.sync();
        final familyId = (await VaultMetaRepository(a.db).getFamilyId())!;
        final childId =
            (await a.children.create(
                      name: 'À supprimer',
                      birthDate: DateTime(2019, 1, 1),
                    )
                    as ActionSuccess<String>)
                .value;
        final mpId = await createSyncedArtwork(a, childId: childId);
        await a.sync();

        cloudApi.seedMembership('user-b', familyId);
        final b = await newDevice('user-b');
        await b.sync();
        expect(await b.artworks.getById(mpId), isNotNull);

        await a.children.delete(childId);
        await a.sync();

        expect(cloudApi.childIsDeleted(childId), isTrue);
        expect(cloudApi.artworkIsDeleted(mpId), isTrue);

        await b.sync();
        expect(await b.children.getById(childId), isNull);
        expect(await b.artworks.getById(mpId), isNull);
      },
    );
  });

  group(
    'D9 — last-write-wins is by server arrival order, never the device clock',
    () {
      test(
        'a device with its clock lied a year forward does not win just by claiming a later local time',
        () async {
          final a = await newDevice('user-a');
          await a.sync();
          final familyId = (await VaultMetaRepository(a.db).getFamilyId())!;
          final childId =
              (await a.children.create(
                        name: 'C',
                        birthDate: DateTime(2020, 1, 1),
                      )
                      as ActionSuccess<String>)
                  .value;
          final mpId = await createSyncedArtwork(
            a,
            childId: childId,
            story: 'v1',
          );
          await a.sync();

          cloudApi.seedMembership('user-b', familyId);
          final b = await newDevice('user-b');
          await b.sync();

          // A's device clock is deliberately advanced by a year — but nothing
          // about `updateStory` reads the device clock into what gets pushed
          // as content, and the server (`FakeHomeCloudApi._tick`, modeling
          // migration 0004) assigns `updated_at` itself, never trusting a
          // client-supplied timestamp.
          await a.artworks.updateStory(
            id: mpId,
            story: 'v2 depuis A (horloge trafiquée)',
          );
          // B pushes its own edit *after* A's, in call order — B's write must
          // win, purely because it reached the fake "server" last.
          await b.artworks.updateStory(id: mpId, story: 'v3 depuis B');

          await a.sync(); // arrives at the "server" first
          await b.sync(); // arrives second — must win

          expect(cloudApi.artworkStory(mpId), 'v3 depuis B');
          await a.sync(); // A converges to B's version on its next pull
          expect((await a.artworks.getById(mpId))!.story, 'v3 depuis B');
        },
      );
    },
  );

  group('spec §5 — push isolation, backoff-free happy path for the rest', () {
    test(
      'one artwork with a vanished local file does not block the other nine',
      () async {
        final a = await newDevice('user-a');
        await a.sync();
        final childId =
            (await a.children.create(name: 'C', birthDate: DateTime(2020, 1, 1))
                    as ActionSuccess<String>)
                .value;

        final ids = <String>[];
        for (var i = 0; i < 10; i++) {
          ids.add(await createSyncedArtwork(a, childId: childId, seed: i));
        }

        // Simulate the original file vanishing out-of-band (e.g. OS-level
        // storage cleanup) for exactly one of the ten, before syncing.
        final victim = (await a.artworks.getById(ids[3]))!;
        final victimFile = await a.vault.resolveFile(victim.relativeImagePath!);
        await victimFile.delete();

        final summary = await a.sync();

        // 9 artworks + 1 child = 10 successes; the tenth artwork
        // (its file gone) is the one terminal failure.
        expect(summary.pushSucceeded, 10);
        expect(summary.pushFailed, 1);
        expect(summary.lastError, isA<FileMissingFailure>());

        for (final id in ids.where((id) => id != ids[3])) {
          expect(cloudApi.artworkExists(id), isTrue);
        }
        expect(cloudApi.artworkExists(ids[3]), isFalse);

        final victimAfter = await a.artworks.getById(ids[3]);
        expect(victimAfter!.syncState, SyncState.downloadFailed);

        // Terminal: the outbox does not keep retrying it.
        expect(await a.engine.outbox.countPending(), 0);
      },
    );
  });

  group(
    'spec — a sync interrupted mid-drain resumes without duplicating or losing entries',
    () {
      test(
        'one failing entry does not block the others, and retrying only the survivor never duplicates it',
        () async {
          final a = await newDevice('user-a');
          await a.sync();
          final childId =
              (await a.children.create(
                        name: 'C',
                        birthDate: DateTime(2020, 1, 1),
                      )
                      as ActionSuccess<String>)
                  .value;
          for (var i = 0; i < 6; i++) {
            await createSyncedArtwork(a, childId: childId, seed: i);
          }

          final pending = await a.engine.outbox.listReady();
          // 1 child (created before the loop) + 6 artworks.
          expect(pending, hasLength(7));
          cloudApi.throwOnNextArtworkUpsert = Exception(
            'simulated transient failure',
          );

          final firstAttempt = await a.sync();
          // Exactly one entry hit the injected failure; the rest (the child +
          // 5 artworks) still went through in the same run (isolation,
          // spec §5) — the failed one is still queued, waiting out its
          // backoff, not lost.
          expect(firstAttempt.pushFailed, 1);
          expect(firstAttempt.pushSucceeded, 6);
          expect(await a.engine.outbox.countPending(), 1);

          final familyId = (await VaultMetaRepository(a.db).getFamilyId())!;
          expect(
            cloudApi.artworksInFamily(familyId),
            5,
            reason: 'the failed entry never reached the server',
          );

          // The failure was transient and does not recur — but it is still
          // sitting out its backoff window (`markFailed`), which a real retry
          // must honor rather than hammering the server immediately. Force
          // the one surviving entry ready *now*, the way the real backoff
          // eventually would on its own, and drain again the exact same way
          // a genuinely restarted app would: a brand-new `SyncEngine` reading
          // the same persistent outbox and local database.
          await a.db
              .update(a.db.syncOutboxTable)
              .write(
                const SyncOutboxTableCompanion(nextAttemptAt: Value(null)),
              );
          final restarted = SyncEngine(
            db: a.db,
            vault: a.vault,
            uploader: uploader,
            downloader: downloader,
            childrenRepo: a.children,
            artworksRepo: a.artworks,
            cloudApi: cloudApi,
            outbox: SyncOutboxRepository(a.db),
            vaultMeta: VaultMetaRepository(a.db),
            currentUserId: () => a.userId,
          );
          cloudApi.currentUserId = a.userId;
          final secondAttempt = await restarted.syncAll();

          expect(secondAttempt.pushSucceeded, 1);
          expect(await a.engine.outbox.countPending(), 0);
          expect(
            cloudApi.artworksInFamily(familyId),
            6,
            reason: 'no duplicate rows created by the retried push',
          );
        },
      );

      test(
        'a device restart (a fresh SyncEngine over the same local database) resumes a half-drained outbox',
        () async {
          final a = await newDevice('user-a');
          await a.sync();
          final childId =
              (await a.children.create(
                        name: 'C',
                        birthDate: DateTime(2020, 1, 1),
                      )
                      as ActionSuccess<String>)
                  .value;

          // Session 1: three artworks created and fully synced.
          for (var i = 0; i < 3; i++) {
            await createSyncedArtwork(a, childId: childId, seed: i);
          }
          await a.sync();
          final familyId = (await VaultMetaRepository(a.db).getFamilyId())!;
          expect(cloudApi.artworksInFamily(familyId), 3);

          // Session 2: three more created, but the app is killed before this
          // session's own `syncAll()` ever runs — nothing has been attempted
          // for these three yet.
          for (var i = 3; i < 6; i++) {
            await createSyncedArtwork(a, childId: childId, seed: i);
          }

          // "Restart" — a brand-new `SyncEngine` instance, no in-memory state
          // carried over, reading the same on-disk database and vault.
          final restarted = SyncEngine(
            db: a.db,
            vault: a.vault,
            uploader: uploader,
            downloader: downloader,
            childrenRepo: a.children,
            artworksRepo: a.artworks,
            cloudApi: cloudApi,
            outbox: SyncOutboxRepository(a.db),
            vaultMeta: VaultMetaRepository(a.db),
            currentUserId: () => a.userId,
          );
          cloudApi.currentUserId = a.userId;
          final summary = await restarted.syncAll();

          expect(
            summary.pushSucceeded,
            3,
            reason: 'only the three never-attempted entries were pending',
          );
          expect(
            cloudApi.artworksInFamily(familyId),
            6,
            reason: 'the first three were not re-sent',
          );
          expect(await a.engine.outbox.countPending(), 0);
        },
      );
    },
  );

  group('C-06 §1 — vault isolation refuses to merge two families', () {
    test(
      'signing into a different family than the one this vault is attached to throws, and touches nothing',
      () async {
        final a = await newDevice('user-a');
        await a.sync(); // attaches to family-a
        final familyA = (await VaultMetaRepository(a.db).getFamilyId())!;

        final childId =
            (await a.children.create(
                      name: 'Local',
                      birthDate: DateTime(2021, 1, 1),
                    )
                    as ActionSuccess<String>)
                .value;
        await a.sync();

        // A *different* account, belonging to a *different* family, signs
        // into the very same local vault (e.g. someone else uses this
        // device without realizing it's already linked).
        final bDevice = await newDevice(
          'user-b',
        ); // separate vault, only to mint a genuinely distinct family
        await bDevice.sync();
        final familyB = (await VaultMetaRepository(bDevice.db).getFamilyId())!;
        expect(familyB, isNot(familyA));

        // Re-point `a`'s own engine at user-b's session (simulating a sign-
        // out/sign-in on the SAME device/vault as `a`).
        final mismatchedEngine = SyncEngine(
          db: a.db,
          vault: a.vault,
          uploader: uploader,
          downloader: downloader,
          childrenRepo: a.children,
          artworksRepo: a.artworks,
          cloudApi: cloudApi,
          outbox: SyncOutboxRepository(a.db),
          vaultMeta: VaultMetaRepository(a.db),
          currentUserId: () => 'user-b',
        );
        cloudApi.currentUserId = 'user-b';

        expect(
          () => mismatchedEngine.syncAll(),
          throwsA(isA<FamilyMismatchException>()),
        );

        // Nothing merged, nothing lost: `a`'s local child is still exactly
        // as it was, and family A's cloud content is untouched by user-b's
        // session.
        expect(await a.children.watchAll().first, hasLength(1));
        expect((await a.children.watchAll().first).single.id, childId);
        expect(cloudApi.artworksInFamily(familyA), 0);
      },
    );
  });

  group('D10 — thumbnails converge before the original', () {
    test(
      'a device joining a populated family gets a thumbnail immediately; the display derivative stays deferred',
      () async {
        final a = await newDevice('user-a');
        await a.sync();
        final familyId = (await VaultMetaRepository(a.db).getFamilyId())!;
        final childId =
            (await a.children.create(name: 'C', birthDate: DateTime(2020, 1, 1))
                    as ActionSuccess<String>)
                .value;
        final mpId = await createSyncedArtwork(a, childId: childId);
        await a.sync();

        cloudApi.seedMembership('user-b', familyId);
        final b = await newDevice('user-b');
        await b.sync();

        final pulled = await b.artworks.getById(mpId);
        expect(pulled, isNotNull);
        expect(
          pulled!.relativeImagePath,
          isNull,
          reason: 'the original never left device A (ADR 0007)',
        );
        expect(
          pulled.thumbnailImagePath,
          isNotNull,
          reason: 'thumbnail regenerated locally from display',
        );
        expect(
          pulled.displayImagePath,
          isNotNull,
          reason: 'display downloaded to regenerate thumbnail',
        );
        expect(pulled.syncState, SyncState.synced);

        final thumbFile = await b.vault.resolveFile(pulled.thumbnailImagePath!);
        expect(await thumbFile.exists(), isTrue);
        expect(await thumbFile.length(), greaterThan(0));

        // Display is already downloaded
        final downloadResult = await b.engine.ensureDisplayImageDownloaded(
          mpId,
        );
        expect(downloadResult, ActionResultLike.alreadyHave);
        final afterDisplay = await b.artworks.getById(mpId);
        expect(afterDisplay!.displayImagePath, isNotNull);
        expect(afterDisplay.syncState, SyncState.synced);
      },
    );

    test(
      'a display download failure is recorded, not thrown, and does not block the rest of the pull',
      () async {
        final a = await newDevice('user-a');
        await a.sync();
        final familyId = (await VaultMetaRepository(a.db).getFamilyId())!;
        final childId =
            (await a.children.create(name: 'C', birthDate: DateTime(2020, 1, 1))
                    as ActionSuccess<String>)
                .value;
        final okId = await createSyncedArtwork(a, childId: childId, seed: 1);
        final failId = await createSyncedArtwork(a, childId: childId, seed: 2);
        await a.sync();

        final failKey = 'fake/$failId/display.jpg';
        downloader.failOnce.add(failKey);

        cloudApi.seedMembership('user-b', familyId);
        final b = await newDevice('user-b');
        await b.sync();

        final ok = await b.artworks.getById(okId);
        final fail = await b.artworks.getById(failId);
        expect(ok!.thumbnailImagePath, isNotNull);
        expect(ok.syncState, SyncState.synced);
        expect(fail!.thumbnailImagePath, isNull);
        expect(fail.syncState, SyncState.downloadFailed);
      },
    );
  });

  group(
    'C-12 — a purge converges even to a device that missed the soft-delete window entirely',
    () {
      test(
        'device offline through soft-delete and purge alike still learns the row is gone',
        () async {
          final a = await newDevice('user-a');
          await a.sync();
          final familyId = (await VaultMetaRepository(a.db).getFamilyId())!;
          final childId =
              (await a.children.create(
                        name: 'Zoé',
                        birthDate: DateTime(2019, 3, 1),
                      )
                      as ActionSuccess<String>)
                  .value;
          final mpId = await createSyncedArtwork(a, childId: childId);
          await a.sync();

          // B pulls the artwork once, then goes offline for the rest of
          // this test — it never sees the soft-delete `a` performs next, only
          // the eventual physical purge, via the purge log rather than a
          // cursor-filtered `pullArtworks` (which can never surface a row
          // that no longer exists at all).
          cloudApi.seedMembership('user-b', familyId);
          final b = await newDevice('user-b');
          await b.sync();
          expect(await b.artworks.getById(mpId), isNotNull);

          // `a` deletes it (soft-delete, C-06's existing path) and it is
          // later purged (C-12) — B is offline for both, never pulling in
          // between, exactly the gap this ticket's own report flagged.
          await a.artworks.delete(mpId);
          await a.sync();
          cloudApi.purgeArtwork(mpId);

          await b.sync();

          expect(await b.artworks.getById(mpId), isNull);
        },
      );

      test(
        'a device that DID see the soft-delete first is unaffected by the purge log (no double-processing)',
        () async {
          final a = await newDevice('user-a');
          await a.sync();
          final familyId = (await VaultMetaRepository(a.db).getFamilyId())!;
          final childId =
              (await a.children.create(
                        name: 'Léo',
                        birthDate: DateTime(2020, 1, 1),
                      )
                      as ActionSuccess<String>)
                  .value;
          final mpId = await createSyncedArtwork(a, childId: childId);
          await a.sync();

          cloudApi.seedMembership('user-b', familyId);
          final b = await newDevice('user-b');
          await b.sync();

          await a.artworks.delete(mpId);
          await a.sync();
          await b
              .sync(); // sees the tombstone the ordinary way, row gone locally already
          expect(await b.artworks.getById(mpId), isNull);

          cloudApi.purgeArtwork(mpId);
          await b
              .sync(); // purge-log entry for an id already absent locally: a no-op, not an error

          expect(await b.artworks.getById(mpId), isNull);
        },
      );
    },
  );

  group('Audio stories sync & lazy download', () {
    test(
      'push uploads audio, pull syncs metadata, and ensureAudioDownloaded fetches lazily',
      () async {
        final a = await newDevice('user-a');
        await a.sync();
        final familyId = (await VaultMetaRepository(a.db).getFamilyId())!;
        final childId =
            (await a.children.create(name: 'C', birthDate: DateTime(2020, 1, 1))
                    as ActionSuccess<String>)
                .value;

        final dummyAudioFile = File('${a.tempRoot.path}/test_voice.m4a');
        await dummyAudioFile.writeAsBytes(List.filled(1024, 42));

        final mpId = await createSyncedArtwork(
          a,
          childId: childId,
          sourceAudioFile: dummyAudioFile,
          audioDurationMs: 45000,
        );

        final initialUploads = uploader.uploadCount;
        await a.sync();
        // Should have uploaded display and audio (2 uploads, no thumbnail in remote storage)
        expect(uploader.uploadCount, initialUploads + 2);

        cloudApi.seedMembership('user-b', familyId);
        final b = await newDevice('user-b');
        await b.sync();

        final pulled = await b.artworks.getById(mpId);
        expect(pulled, isNotNull);
        expect(pulled!.hasAudio, isTrue);
        expect(pulled.audioDurationMs, 45000);
        expect(
          pulled.relativeAudioPath,
          isNull,
          reason: 'Audio is not downloaded eagerly on pull',
        );
        expect(pulled.isAudioLocal, isFalse);

        // Lazy download of audio
        final downloadResult = await b.engine.ensureAudioDownloaded(mpId);
        expect(downloadResult, ActionResultLike.downloaded);

        final afterDownload = await b.artworks.getById(mpId);
        expect(afterDownload!.isAudioLocal, isTrue);
        expect(afterDownload.relativeAudioPath, isNotNull);

        final localAudio = await b.vault.resolveFile(
          afterDownload.relativeAudioPath!,
        );
        expect(await localAudio.exists(), isTrue);
        expect(await localAudio.length(), 1024);

        // Calling again returns alreadyHave
        final secondDownload = await b.engine.ensureAudioDownloaded(mpId);
        expect(secondDownload, ActionResultLike.alreadyHave);

        // Modifying text on device A does not re-upload images or audio
        final currentUploads = uploader.uploadCount;
        await a.artworks.updateStory(id: mpId, story: 'Nouvelle histoire');
        await a.sync();
        expect(
          uploader.uploadCount,
          currentUploads,
          reason: 'object keys reused, no new uploads',
        );
      },
    );
  });
}
