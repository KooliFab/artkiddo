// Convergence engine: the parts of a `syncAll` run that do not depend on
// what is sent or read (operations: `operation_sync_test.dart`, journal:
// `change_journal_pull_test.dart`) — family attachment, progress, vault
// isolation and the single shared run.

import 'dart:async';
import 'dart:io';

import 'package:artkiddo_core/artkiddo_core.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'operation_sync_test.dart' show FakeProtocolBackend, Node;

const _uuid = Uuid();

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

void main() {
  late FakeProtocolBackend backend;
  late Node node;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() async {
    backend = FakeProtocolBackend();
    node = await Node.create(backend);
  });

  tearDown(() => node.close());

  group('family attachment', () {
    test('the first run attaches this vault to the account family', () async {
      expect(await VaultMetaRepository(node.db).getFamilyId(), isNull);

      await node.sync();

      expect(await VaultMetaRepository(node.db).getFamilyId(), 'family-a');
    });

    test('a second run for the same account changes nothing', () async {
      await node.sync();
      await node.sync();

      expect(await VaultMetaRepository(node.db).getFamilyId(), 'family-a');
    });

    test(
      'an account of another family is refused and nothing is touched',
      () async {
        final childId = await node.newChild('Local');
        await node.sync();
        expect(await VaultMetaRepository(node.db).getFamilyId(), 'family-a');

        // Someone else signs into the very same local vault.
        node.familyId = 'family-b';
        node.engine = node.newEngine();

        await expectLater(node.sync(), throwsA(isA<FamilyMismatchException>()));

        expect(await node.children.watchAll().first, hasLength(1));
        expect((await node.children.watchAll().first).single.id, childId);
        expect(await VaultMetaRepository(node.db).getFamilyId(), 'family-a');
      },
    );

    test(
      'a join reset starts from an empty vault when the family changed',
      () async {
        await node.newChild('Ancien');
        await node.sync();
        // The other family has a history of its own: none of this vault's.
        backend.journal.clear();
        await VaultMetaRepository(node.db).markJoinResetPending();
        node.familyId = 'family-b';
        node.engine = node.newEngine();

        await node.sync();

        expect(await node.children.count(), 0);
        expect(await VaultMetaRepository(node.db).getFamilyId(), 'family-b');
      },
    );
  });

  group('progress', () {
    test('reports sending against a known total, then receiving', () async {
      for (var i = 0; i < 3; i++) {
        await node.newChild('Enfant $i');
      }
      final seen = <SyncProgress>[];

      await node.engine.syncAll(onProgress: seen.add);

      final sending = seen.where((p) => p.phase == SyncPhase.sending);
      expect(sending.map((p) => p.done), [0, 1, 2, 3]);
      expect(sending.every((p) => p.total == 3), isTrue);
      expect(
        seen.indexWhere((p) => p.phase == SyncPhase.receiving),
        greaterThan(seen.lastIndexWhere((p) => p.phase == SyncPhase.sending)),
        reason: 'receiving starts only once sending is over',
      );
    });

    test(
      'counts the artworks applied while receiving, without a total',
      () async {
        final childId = _uuid.v4();
        backend.remoteCreate(SyncEntityType.child, childId, {
          'name': 'Zoé',
          'birthDate': '2019-03-01',
        });
        for (var i = 0; i < 3; i++) {
          final id = _uuid.v4();
          final mediaId = _uuid.v4();
          backend.remoteCreate(
            SyncEntityType.artwork,
            id,
            {
              'childId': childId,
              'addedAt': syncInstantValue(DateTime.utc(2026, 1, 1)),
              'photo': MediaRef(mediaId: mediaId, version: 1).toJson(),
            },
            media: [
              MediaDescriptor(
                mediaId: mediaId,
                version: 1,
                role: MediaRole.optimized,
                format: MediaFormat.jpeg,
                byteSize: 1000,
                sha256: 'a' * 64,
                widthPx: 800,
                heightPx: 600,
              ),
            ],
          );
        }
        final seen = <SyncProgress>[];

        await node.engine.syncAll(onProgress: seen.add);

        final receiving = seen.where((p) => p.phase == SyncPhase.receiving);
        // One report per page of the journal, with the artworks applied so far.
        expect(receiving.map((p) => p.done), [0, 3]);
        expect(
          receiving.every((p) => p.total == null),
          isTrue,
          reason: 'remote pages have no known total',
        );
      },
    );
  });

  test('concurrent sync triggers share one run', () async {
    await node.newChild('C');
    final gate = Completer<void>();
    final entered = Completer<void>();
    backend.beforeReply = (_) async {
      if (!entered.isCompleted) entered.complete();
      await gate.future;
    };

    final first = node.engine.syncAll();
    await entered.future;
    final second = node.engine.syncAll();

    expect(identical(first, second), isTrue);
    gate.complete();
    await Future.wait([first, second]);
    expect(await node.engine.outbox.countPending(), 0);
    expect(backend.effects, 1);
  });
}
