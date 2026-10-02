// L14 scenarios S22–S26: the remote side is not there. No network, an expired
// session, a full quota, a service that is down: nothing is lost, nothing is
// erased, every operation stays queued with its identity, and everything goes
// out once the remote side is back.

import 'dart:io';

import 'package:artkiddo_core/artkiddo_core.dart';
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

  /// The failure a run ends with: thrown (a journal that cannot be read) or
  /// reported in the summary (an operation that cannot be sent).
  Future<Object?> failureOf(Node node) async {
    try {
      return (await node.sync()).lastError;
    } catch (error) {
      return error;
    }
  }

  final outages =
      <({String id, String name, Object error, bool pulls, Matcher failure})>[
        (
          id: 'S22',
          name: 'no network',
          error: const SocketException('Network is unreachable'),
          pulls: true,
          failure: isA<SocketException>(),
        ),
        (
          id: 'S23',
          name: 'an expired session',
          error: const SyncAuthException(SyncAuthFailure.sessionExpired),
          pulls: true,
          failure: isA<SyncAuthException>(),
        ),
        (
          id: 'S24',
          name: 'a full quota',
          error: const QuotaExceededException(),
          pulls: false,
          failure: isA<QuotaExceededFailure>(),
        ),
        (
          id: 'S25',
          name: 'a service that is unavailable',
          error: const HttpException('503 Service Unavailable'),
          pulls: true,
          failure: isA<HttpException>(),
        ),
      ];

  for (final outage in outages) {
    test(
      '${outage.id} with ${outage.name}, nothing is lost, nothing is '
      'erased and everything is sent once it is back (INV-03, INV-08)',
      () async {
        final a = await world.device();
        final b = await world.device();
        final synced = await a.newChild('Déjà là');
        await world.settle([a, b]);
        final artwork = await a.newLocalArtwork(synced, seed: 8);
        final created = await a.newChild('Créé hors ligne');
        await a.children.update(
          id: synced,
          name: 'Renommé hors ligne',
          birthDate: DateTime(2019, 3, 1),
        );
        final files = await a.vaultBytes();
        final queued = {
          for (final op in [...await a.ops(synced), ...await a.ops(created)])
            op.opId,
        };
        expect(queued, hasLength(2));
        world.goDown(outage.error, pulls: outage.pulls);

        final failure = await failureOf(a);

        expect(failure, outage.failure);
        // Every local row, file and operation is exactly as it was.
        expect(await a.childrenView(), {
          synced: 'Renommé hors ligne|2019-03-01',
          created: 'Créé hors ligne|2019-03-01',
        });
        expect(await a.vaultBytes(), files);
        expect(await a.artworkRow(artwork), isNotNull);
        final stillQueued = {
          for (final op in [...await a.ops(synced), ...await a.ops(created)])
            op.opId,
        };
        expect(stillQueued, queued, reason: 'same operations, same identities');
        expect(
          await VaultMetaRepository(a.db).getFamilyId(),
          'family-a',
          reason: 'still attached to its family',
        );
        expect(backend.child(synced).values['name'], 'Déjà là');

        world.recover();
        await a.releaseBackoff();
        await a.sync();
        await a.sync();
        await b.sync();

        expect(backend.child(synced).values['name'], 'Renommé hors ligne');
        expect(backend.child(created).values['name'], 'Créé hors ligne');
        expect(await a.ops(synced), isEmpty);
        expect(await a.ops(created), isEmpty);
        expect(await b.childrenView(), await a.childrenView());
        expect(await a.vaultBytes(), files);
        await a.expectNoDanglingReference();
        // Each queued operation reached the remote side under its own id.
        expect(backend.received.toSet().containsAll(queued), isTrue);
      },
    );
  }
}
