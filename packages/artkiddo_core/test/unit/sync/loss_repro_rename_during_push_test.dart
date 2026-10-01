// Reproduction of data loss #1: renaming a child while its push is in flight.
//
// The push reads the child row (old name), sends it, and only then clears the
// outbox entry by `seq`. A rename made during the send is collapsed into that
// still-present entry by `SyncOutboxRepository.enqueue`, so the acknowledgement
// removes the only record of the rename. The pull that follows then sees no
// pending entry and overwrites the new name with the server's old one.
//
// Expected red until the outbox acknowledges the exact operation it sent.
// Run without the skip: flutter test --run-skipped --tags known-loss

import 'dart:async';

import 'package:artkiddo_core/artkiddo_core.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'sync_engine_test.dart' show Device;

/// Records the upsert like the real backend does (the server row now holds the
/// sent values, with a fresh `updated_at`), then parks the response until
/// [release] so the test can edit locally while the push is in flight.
class _GatedUpsertBackend extends FakeHomeCloudApi {
  final entered = Completer<void>();
  final _gate = Completer<void>();

  void release() => _gate.complete();

  @override
  Future<void> upsertChild({
    required String id,
    required String familyId,
    required String name,
    required DateTime birthDate,
    required DateTime createdAt,
  }) async {
    await super.upsertChild(
      id: id,
      familyId: familyId,
      name: name,
      birthDate: birthDate,
      createdAt: createdAt,
    );
    if (!entered.isCompleted) entered.complete();
    await _gate.future;
  }
}

void main() {
  late _GatedUpsertBackend backend;
  late FakeObjectUploader uploader;
  late FakeObjectDownloader downloader;
  Device? device;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() {
    backend = _GatedUpsertBackend();
    uploader = FakeObjectUploader();
    downloader = FakeObjectDownloader(uploader.objects);
  });

  tearDown(() async {
    await device?.close();
    device = null;
  });

  test(
    'a rename made while the child is being pushed survives the sync',
    () async {
      final a = device = await Device.create(
        cloudApi: backend,
        uploader: uploader,
        downloader: downloader,
        userId: 'user-a',
      );
      backend.currentUserId = a.userId;
      final familyId = await a.engine.ensureFamily();

      final birthDate = DateTime(2019, 3, 1);
      final id =
          (await a.children.create(name: 'Ancien', birthDate: birthDate)
                  as ActionSuccess<String>)
              .value;

      // Start the full sync (push then pull) and stop it inside the push.
      final sync = a.sync();
      await backend.entered.future;

      expect(
        await a.children.update(id: id, name: 'Nouveau', birthDate: birthDate),
        isA<ActionSuccess<void>>(),
      );

      backend.release();
      await sync;

      final local = await a.children.getById(id);
      final pending = await SyncOutboxRepository(a.db).countPending();
      final server = (await backend.pullChildren(
        familyId: familyId,
      )).singleWhere((row) => row.id == id);

      expect(
        local?.name,
        'Nouveau',
        reason:
            'the pull must not bring back the pre-rename value '
            '(syncState=${local?.syncState}, pending=$pending, '
            'server=${server.name})',
      );
      expect(
        pending > 0 || server.name == 'Nouveau',
        isTrue,
        reason:
            'the rename must still be pending or already on the server '
            '(pending=$pending, server=${server.name})',
      );
    },
    tags: ['known-loss'],
    skip: 'Attendu rouge jusqu’à L02/L09',
  );
}
