// Focused unit tests for `SyncOutboxRepository` and `VaultMetaRepository`
// — the two new local tables C-06 adds — covering behaviors not already
// exercised end-to-end by `sync_engine_test.dart`.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:artkiddo_core/src/local/database/app_database.dart';
import 'package:artkiddo_core/src/sync/sync_outbox.dart';
import 'package:artkiddo_core/src/sync/vault_meta.dart';

void main() {
  late Directory tempRoot;
  late AppDatabase db;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('artkiddo_outbox_test_');
    db = AppDatabase.forTesting(
      NativeDatabase(File(p.join(tempRoot.path, 'test.sqlite'))),
    );
  });

  tearDown(() async {
    await db.close();
    if (await tempRoot.exists()) await tempRoot.delete(recursive: true);
  });

  group('SyncOutboxRepository.enqueue', () {
    test(
      'a delete supersedes a still-pending upsert for the same entity — one entry, not two',
      () async {
        final outbox = SyncOutboxRepository(db);
        await outbox.enqueue(
          entity: SyncEntityKind.masterpiece,
          entityId: 'm1',
          op: SyncOutboxOp.upsert,
        );
        expect(await outbox.countPending(), 1);

        await outbox.enqueue(
          entity: SyncEntityKind.masterpiece,
          entityId: 'm1',
          op: SyncOutboxOp.delete,
        );

        final ready = await outbox.listReady();
        expect(ready, hasLength(1));
        expect(ready.single.op, 'delete');
      },
    );

    test(
      'repeated upserts for the same entity collapse to one queued entry',
      () async {
        final outbox = SyncOutboxRepository(db);
        await outbox.enqueue(
          entity: SyncEntityKind.masterpiece,
          entityId: 'm1',
          op: SyncOutboxOp.upsert,
        );
        await outbox.enqueue(
          entity: SyncEntityKind.masterpiece,
          entityId: 'm1',
          op: SyncOutboxOp.upsert,
        );
        await outbox.enqueue(
          entity: SyncEntityKind.masterpiece,
          entityId: 'm1',
          op: SyncOutboxOp.upsert,
        );

        expect(await outbox.countPending(), 1);
      },
    );

    test('different entities queue independently', () async {
      final outbox = SyncOutboxRepository(db);
      await outbox.enqueue(
        entity: SyncEntityKind.child,
        entityId: 'c1',
        op: SyncOutboxOp.upsert,
      );
      await outbox.enqueue(
        entity: SyncEntityKind.masterpiece,
        entityId: 'm1',
        op: SyncOutboxOp.upsert,
      );
      await outbox.enqueue(
        entity: SyncEntityKind.masterpiece,
        entityId: 'm2',
        op: SyncOutboxOp.upsert,
      );

      expect(await outbox.countPending(), 3);
      expect(
        await outbox.pendingEntityIds(entity: SyncEntityKind.masterpiece),
        {'m1', 'm2'},
      );
      expect(await outbox.pendingEntityIds(entity: SyncEntityKind.child), {
        'c1',
      });
    });
  });

  group('SyncOutboxRepository retry bookkeeping', () {
    test('markSucceeded removes the entry entirely', () async {
      final outbox = SyncOutboxRepository(db);
      await outbox.enqueue(
        entity: SyncEntityKind.masterpiece,
        entityId: 'm1',
        op: SyncOutboxOp.upsert,
      );
      final entry = (await outbox.listReady()).single;

      await outbox.markSucceeded(entry.seq);

      expect(await outbox.countPending(), 0);
    });

    test(
      'markFailed increments attempts, records the error, and defers nextAttemptAt into the future',
      () async {
        final outbox = SyncOutboxRepository(db);
        await outbox.enqueue(
          entity: SyncEntityKind.masterpiece,
          entityId: 'm1',
          op: SyncOutboxOp.upsert,
        );
        final entry = (await outbox.listReady()).single;

        await outbox.markFailed(entry.seq, error: 'boom');

        // Still pending overall, but no longer "ready right now".
        expect(await outbox.countPending(), 1);
        expect(await outbox.countFailed(), 1);
        expect(await outbox.listReady(), isEmpty);
        expect(
          await outbox.listReady(
            now: DateTime.now().add(const Duration(minutes: 2)),
          ),
          hasLength(1),
        );
      },
    );

    test(
      'markTerminal removes the entry without counting it as succeeded',
      () async {
        final outbox = SyncOutboxRepository(db);
        await outbox.enqueue(
          entity: SyncEntityKind.masterpiece,
          entityId: 'm1',
          op: SyncOutboxOp.upsert,
        );
        final entry = (await outbox.listReady()).single;

        await outbox.markTerminal(entry.seq);

        expect(await outbox.countPending(), 0);
      },
    );

    test(
      'backoffFor doubles per attempt and caps at 60 minutes; retryAfter overrides it',
      () {
        expect(SyncOutboxRepository.backoffFor(1), const Duration(minutes: 1));
        expect(SyncOutboxRepository.backoffFor(2), const Duration(minutes: 2));
        expect(SyncOutboxRepository.backoffFor(3), const Duration(minutes: 4));
        expect(
          SyncOutboxRepository.backoffFor(10),
          const Duration(minutes: 60),
          reason: 'capped at 1h (spec §5)',
        );
        expect(
          SyncOutboxRepository.backoffFor(
            1,
            retryAfter: const Duration(seconds: 5),
          ),
          const Duration(seconds: 5),
          reason:
              '429 Retry-After takes precedence over the computed delay (spec §5)',
        );
      },
    );
  });

  group('VaultMetaRepository', () {
    test('a fresh vault has no foyer and no pull cursor', () async {
      final vaultMeta = VaultMetaRepository(db);
      expect(await vaultMeta.getFoyerId(), isNull);
      expect(await vaultMeta.getLastPullCursor(), isNull);
    });

    test('attachFoyer is idempotent for the same foyer', () async {
      final vaultMeta = VaultMetaRepository(db);
      await vaultMeta.attachFoyer('foyer-1');
      await vaultMeta.attachFoyer('foyer-1');
      expect(await vaultMeta.getFoyerId(), 'foyer-1');
    });

    test(
      'attachFoyer throws FoyerMismatchException for a different foyer, and does not overwrite the existing one',
      () async {
        final vaultMeta = VaultMetaRepository(db);
        await vaultMeta.attachFoyer('foyer-1');

        expect(
          () => vaultMeta.attachFoyer('foyer-2'),
          throwsA(isA<FoyerMismatchException>()),
        );
        expect(
          await vaultMeta.getFoyerId(),
          'foyer-1',
          reason: 'the mismatch must never silently overwrite',
        );
      },
    );

    test('assertCompatible mirrors attachFoyer without ever writing', () async {
      final vaultMeta = VaultMetaRepository(db);
      await vaultMeta.assertCompatible(
        'foyer-1',
      ); // unattached vault: nothing to conflict with
      expect(
        await vaultMeta.getFoyerId(),
        isNull,
        reason: 'assertCompatible must never write',
      );

      await vaultMeta.attachFoyer('foyer-1');
      await vaultMeta.assertCompatible('foyer-1'); // same foyer: fine
      expect(
        () => vaultMeta.assertCompatible('foyer-2'),
        throwsA(isA<FoyerMismatchException>()),
      );
    });

    test(
      'setLastPullCursor is readable back and reflects the maximal server timestamp applied',
      () async {
        final vaultMeta = VaultMetaRepository(db);
        final cursor = DateTime.utc(2026, 1, 1, 12, 0, 0);
        await vaultMeta.setLastPullCursor(cursor);
        // SQLite round-trips a `DateTime` as a local-time unix timestamp
        // (drift's default `DateTimeColumn`), so the *instant* survives
        // exactly — the type's timezone flag does not.
        expect(
          (await vaultMeta.getLastPullCursor())!.isAtSameMomentAs(cursor),
          isTrue,
        );
      },
    );

    test(
      'v10 persists children, masterpieces, and purge cursors independently',
      () async {
        final vaultMeta = VaultMetaRepository(db);
        final children = DateTime.utc(2026, 1, 1);
        final masterpieces = DateTime.utc(2026, 1, 3);
        final purged = DateTime.utc(2026, 1, 2);

        await vaultMeta.setChildrenPullCursor(children);
        await vaultMeta.setMasterpiecesPullCursor(masterpieces);
        await vaultMeta.setPurgedPullCursor(purged);

        final stored = await vaultMeta.getPullCursors();
        expect(stored.children!.isAtSameMomentAs(children), isTrue);
        expect(stored.masterpieces!.isAtSameMomentAs(masterpieces), isTrue);
        expect(stored.purged!.isAtSameMomentAs(purged), isTrue);
        expect(
          (await vaultMeta.getLastPullCursor())!.isAtSameMomentAs(masterpieces),
          isTrue,
        );
      },
    );
  });
}
