// L14 scenarios S07–S09: a request delivered twice, an answer that never
// arrives, and the app killed at each step of a push. After every one the
// remote side has the change exactly once, the device holds nothing queued,
// and nothing was created twice.

import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';

import '../sync/operation_sync_test.dart' show Node;
import 'scenario_harness.dart';

void main() {
  late World world;
  late ScenarioBackend backend;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() {
    world = World();
    backend = world.backend;
  });

  tearDown(() => world.dispose());

  group('a request delivered twice', () {
    test(
      'S07 a creation sent twice has one effect and one entity (INV-09)',
      () async {
        final a = await world.device();
        final b = await world.device();
        final id = await a.newChild('Léa');
        final opId = (await a.ops(id)).single.opId;
        backend.duplicateNextRequest = true;

        await a.sync();

        expect(backend.received, [opId, opId]);
        expect(backend.effects, 1, reason: 'the second delivery is a replay');
        expect(backend.entities, hasLength(1));
        expect(backend.child(id).revisions['name'], 1);
        expect(await a.ops(id), isEmpty);

        await world.settle([a, b]);

        expect(await b.childrenView(), await a.childrenView());
        expect((await a.childRow(id))!.nameRev, 1);
      },
    );

    test('S07b an edit sent twice moves the revision once (INV-09)', () async {
      final a = await world.device();
      final b = await world.device();
      final id = await a.newChild('Léa');
      await world.settle([a, b]);
      await a.children.update(
        id: id,
        name: 'Léa-Rose',
        birthDate: DateTime(2019, 3, 1),
      );
      final effects = backend.effects;
      backend.duplicateNextRequest = true;

      await a.sync();

      expect(backend.effects, effects + 1);
      expect(backend.child(id).revisions['name'], 2, reason: 'not 3');
      await world.settle([a, b]);
      expect((await a.childRow(id))!.nameRev, 2);
      expect((await b.childRow(id))!.nameRev, 2);
      expect(await b.childrenView(), {id: 'Léa-Rose|2019-03-01'});
    });
  });

  group('an answer that never arrives', () {
    test(
      'S08 an answer lost after the remote side applied the change: the '
      'app is killed and replays the same operation once (INV-08, INV-09)',
      () async {
        final a = await world.device();
        final b = await world.device();
        final id = await a.newChild('Léa');
        final opId = (await a.ops(id)).single.opId;
        backend
          ..loseNextResponse = true
          // Killed before the journal would acknowledge the operation by echo.
          ..failNextPull = const SocketException('killed');

        await expectLater(a.sync(), throwsA(isA<SocketException>()));
        expect(backend.effects, 1, reason: 'the remote side did apply it');
        await a.restart();
        expect((await a.ops(id)).single.opId, opId, reason: 'same operation');

        await world.settle([a, b]);

        expect(backend.received, [opId, opId]);
        expect(backend.effects, 1);
        expect(backend.entities, hasLength(1));
        expect(await a.ops(id), isEmpty);
        expect(await b.childrenView(), await a.childrenView());
        expect((await a.childRow(id))!.syncState, 'synced');
      },
    );
  });

  group('the app is killed at each step of a push (INV-08)', () {
    late Node a;
    late Node b;
    late String id;

    setUp(() async {
      a = await world.device();
      b = await world.device();
      id = await a.newChild('Léa');
    });

    Future<void> expectConverged({required int sends}) async {
      expect(backend.effects, 1, reason: 'one effect, whatever the crash');
      expect(backend.received.length, sends);
      expect(backend.entities, hasLength(1));
      expect(backend.child(id).values['name'], 'Léa');
      expect(await a.ops(id), isEmpty);
      expect(await a.childrenView(), {id: 'Léa|2019-03-01'});
      expect(await b.childrenView(), await a.childrenView());
      expect((await a.childRow(id))!.syncState, 'synced');
      expect(await a.vaultBytes(), isEmpty);
    }

    test(
      'S09a killed after the local write, before anything is sent',
      () async {
        await a.restart();
        expect(backend.received, isEmpty);

        await world.settle([a, b]);

        await expectConverged(sends: 1);
      },
    );

    test('S09b killed with the operation in flight, the request never '
        'delivered', () async {
      final opId = (await a.ops(id)).single.opId;
      backend
        ..dropNextRequest = const SocketException('killed')
        ..failNextPull = const SocketException('killed');

      await expectLater(a.sync(), throwsA(isA<SocketException>()));
      expect(backend.effects, 0, reason: 'nothing reached the remote side');
      await a.restart();
      final op = (await a.ops(id)).single;
      expect((op.opId, op.state), (opId, 'in_flight'));

      await world.settle([a, b]);

      expect(backend.received, [opId, opId]);
      await expectConverged(sends: 2);
    });

    test(
      'S09c killed right after the answer, before the journal is read',
      () async {
        backend.failNextPull = const SocketException('killed');

        await expectLater(a.sync(), throwsA(isA<SocketException>()));
        expect(await a.ops(id), isEmpty, reason: 'the answer was applied');
        await a.restart();

        await world.settle([a, b]);

        await expectConverged(sends: 1);
      },
    );

    test('S09d killed between two pages of the journal that follows the '
        'push', () async {
      backend.pageSize = 1;
      for (var i = 0; i < 3; i++) {
        remoteChild(backend, '00000000-0000-4000-8000-00000000010$i', 'R$i');
      }
      backend.onPageServed = (index) {
        if (index == 1) backend.failNextPull = const SocketException('killed');
      };

      await expectLater(a.sync(), throwsA(isA<SocketException>()));
      await a.restart();

      await world.settle([a, b]);

      expect(backend.effects, 1);
      expect(backend.received, hasLength(1), reason: 'never sent again');
      expect(await a.ops(id), isEmpty);
      expect(await a.childrenView(), hasLength(4));
      expect(await b.childrenView(), await a.childrenView());
      expect(await a.vaultBytes(), isEmpty);
    });
  });
}
