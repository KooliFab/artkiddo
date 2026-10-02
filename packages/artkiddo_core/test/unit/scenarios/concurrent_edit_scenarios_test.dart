// L14 scenarios S01–S06: edits that overlap in time or across two devices.
// Each one cites the invariant of docs/v1-fiabilisation/invariants.md it proves
// and ends by comparing what the remote side and every device hold.

import 'dart:async';

import 'package:artkiddo_core/artkiddo_core.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';

import 'scenario_harness.dart';

const _childA = '00000000-0000-4000-8000-0000000000a1';
const _artwork = '00000000-0000-4000-8000-0000000000b1';
const _photo = '00000000-0000-4000-8000-0000000000c1';

void main() {
  late World world;
  late ScenarioBackend backend;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() {
    world = World();
    backend = world.backend;
  });

  tearDown(() => world.dispose());

  /// Holds the next patch's answer until [release] is called.
  ({Future<void> entered, void Function() release}) holdNextAnswer() {
    final entered = Completer<void>();
    final gate = Completer<void>();
    backend.beforeReply = (_) async {
      backend.beforeReply = null;
      entered.complete();
      await gate.future;
    };
    return (entered: entered.future, release: gate.complete);
  }

  group('edit during a send', () {
    test('S01 a child renamed while its creation is being sent keeps the new '
        'name everywhere (INV-01, INV-02)', () async {
      final a = await world.device();
      final b = await world.device();
      final id = await a.newChild('Léa');
      final hold = holdNextAnswer();

      final running = a.sync();
      await hold.entered;
      await a.children.update(
        id: id,
        name: 'Léa-Rose',
        birthDate: DateTime(2019, 3, 1),
      );
      hold.release();
      await running;

      // The first acknowledgement did not swallow the rename.
      final waiting = await a.ops(id);
      expect(waiting, hasLength(1));
      expect(waiting.single.patch!.fields, {'name': 'Léa-Rose'});
      expect((await a.childRow(id))!.name, 'Léa-Rose');

      await world.settle([a, b]);

      expect(backend.child(id).values['name'], 'Léa-Rose');
      expect(await a.childrenView(), {id: 'Léa-Rose|2019-03-01'});
      expect(await b.childrenView(), await a.childrenView());
      expect(await a.ops(id), isEmpty);
      expect(await a.replaced(id), isEmpty);
    });

    test('S02 a story and a drawing date edited while an earlier story edit '
        'is being sent all arrive (INV-01, INV-02)', () async {
      remoteChild(backend, _childA);
      remoteArtwork(
        backend,
        _childA,
        id: _artwork,
        mediaId: _photo,
        extra: {'story': 'Un dragon'},
      );
      final a = await world.device();
      final b = await world.device();
      await world.settle([a, b]);
      await a.artworks.updateStory(id: _artwork, story: 'Un dragon bleu');
      final hold = holdNextAnswer();

      final running = a.sync();
      await hold.entered;
      await a.artworks.updateStory(id: _artwork, story: 'Un dragon vert');
      await a.artworks.updateDrawnAt(
        id: _artwork,
        drawnAt: DateTime(2026, 2, 3),
      );
      hold.release();
      await running;

      final row = (await a.artworkRow(_artwork))!;
      expect(row.story, 'Un dragon vert', reason: 'never replaced by an echo');
      expect(row.drawnAt, DateTime(2026, 2, 3));

      await world.settle([a, b]);

      final server = backend.artwork(_artwork).values;
      expect(server['story'], 'Un dragon vert');
      expect(server['drawnAt'], '2026-02-03');
      for (final node in [a, b]) {
        final seen = (await node.artworkRow(_artwork))!;
        expect(
          (seen.story, seen.drawnAt),
          ('Un dragon vert', DateTime(2026, 2, 3)),
        );
        expect(await node.artworkOps(_artwork), isEmpty);
      }
      expect(await a.vaultBytes(), isEmpty);
    });
  });

  group('two devices, offline edits', () {
    test('S03 different fields of one child merge on both devices, with '
        'nothing to recover (INV-10)', () async {
      final a = await world.device();
      final b = await world.device();
      final id = await a.newChild('Léa');
      await world.settle([a, b]);

      await a.children.update(
        id: id,
        name: 'Léa-Rose',
        birthDate: DateTime(2019, 3, 1),
      );
      await b.children.update(
        id: id,
        name: 'Léa',
        birthDate: DateTime(2018, 2, 2),
      );
      await world.settle([a, b]);

      expect(backend.child(id).values, {
        'name': 'Léa-Rose',
        'birthDate': '2018-02-02',
      });
      expect(await a.childrenView(), {id: 'Léa-Rose|2018-02-02'});
      expect(await b.childrenView(), await a.childrenView());
      expect(await a.replaced(id), isEmpty);
      expect(await b.replaced(id), isEmpty);
    });

    test('S04 the same field of one child: the last one sent wins and the '
        'other value stays readable after a restart (INV-10)', () async {
      final a = await world.device();
      final b = await world.device();
      final id = await a.newChild('Léa');
      await world.settle([a, b]);

      await a.children.update(
        id: id,
        name: 'Alpha',
        birthDate: DateTime(2019, 3, 1),
      );
      await b.children.update(
        id: id,
        name: 'Bravo',
        birthDate: DateTime(2019, 3, 1),
      );
      await a.sync();
      await world.settle([b, a]);

      expect(backend.child(id).values['name'], 'Bravo');
      expect(await a.childrenView(), {id: 'Bravo|2019-03-01'});
      expect(await b.childrenView(), await a.childrenView());

      await b.restart();
      final kept = await b.replaced(id);
      expect(kept.map((v) => (v.field, v.value)), [('name', 'Alpha')]);
      expect(kept.single.source, ReplacedValueSource.remote);
    });

    test('S04b the same story of one artwork: the last one sent wins and the '
        'other text stays readable after a restart (INV-10)', () async {
      remoteChild(backend, _childA);
      remoteArtwork(backend, _childA, id: _artwork, mediaId: _photo);
      final a = await world.device();
      final b = await world.device();
      await world.settle([a, b]);

      await a.artworks.updateStory(id: _artwork, story: 'Histoire de A');
      await b.artworks.updateStory(id: _artwork, story: 'Histoire de B');
      await a.sync();
      await world.settle([b, a]);

      expect(backend.artwork(_artwork).values['story'], 'Histoire de B');
      for (final node in [a, b]) {
        expect((await node.artworkRow(_artwork))!.story, 'Histoire de B');
      }
      await b.restart();
      expect((await b.replaced(_artwork)).map((v) => (v.field, v.value)), [
        ('story', 'Histoire de A'),
      ]);
    });

    test('S06 a story on one device and a drawing date on the other both '
        'survive (INV-10)', () async {
      remoteChild(backend, _childA);
      remoteArtwork(backend, _childA, id: _artwork, mediaId: _photo);
      final a = await world.device();
      final b = await world.device();
      await world.settle([a, b]);

      await a.artworks.updateStory(id: _artwork, story: 'Un château');
      await b.artworks.updateDrawnAt(
        id: _artwork,
        drawnAt: DateTime(2025, 12, 24),
      );
      await world.settle([a, b]);

      final server = backend.artwork(_artwork).values;
      expect(server['story'], 'Un château');
      expect(server['drawnAt'], '2025-12-24');
      for (final node in [a, b]) {
        final row = (await node.artworkRow(_artwork))!;
        expect(
          (row.story, row.drawnAt),
          ('Un château', DateTime(2025, 12, 24)),
        );
        expect(await node.replaced(_artwork), isEmpty);
      }
    });
  });
}
