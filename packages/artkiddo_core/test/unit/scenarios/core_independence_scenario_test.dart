// Scenario S26: the account-free path stands alone (INV-16). A local life
// (children, artworks with files, a restart) needs no remote side, no network
// and no configuration: a device with no session neither reads nor sends, and
// loses nothing. That the core holds no provider SDK is checked by
// `tool/guard_public_boundary.sh`, which runs with the rest of the validation.

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';

import 'scenario_harness.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  test('S26 a local life with no remote side keeps every row and every file '
      'across restarts, and a sync with no session reads and sends nothing '
      '(INV-16)', () async {
    final world = World();
    addTearDown(world.dispose);
    final a = await world.device();
    final child = await a.newChild('Léa');
    final artwork = await a.newLocalArtwork(child, seed: 9, story: 'Local');
    final files = await a.vaultBytes();

    await a.restart();
    a.engine = a.newEngine(currentUserId: () => null);
    final summary = await a.sync();

    expect(summary.pushSucceeded + summary.pushFailed, 0);
    expect(world.backend.received, isEmpty);
    expect(world.backend.pulledAfter, isEmpty);
    expect((await a.artworkRow(artwork))!.story, 'Local');
    expect(await a.childrenView(), {child: 'Léa|2019-03-01'});
    expect(await a.vaultBytes(), files);
    await a.expectNoDanglingReference();
  });
}
