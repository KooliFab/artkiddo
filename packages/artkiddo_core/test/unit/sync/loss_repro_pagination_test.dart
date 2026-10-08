// Reproduction of data loss #2: rows missed by a paginated pull.
//
// The old pull persisted a stream cursor equal to the largest `updated_at` of
// the page it had applied and asked for rows strictly after that instant. A
// timestamp is not a position in commit order, so a row that landed behind
// the cursor was never returned again.
//
// The pull now reads the ordered change journal: a change gets its position
// when it is committed, so a late commit is always after a cursor already
// returned, and rows sharing a timestamp are distinct positions. Both
// scenarios are kept, against a journal served in pages of two.

import 'package:artkiddo_core/artkiddo_core.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';

import 'operation_sync_test.dart' show FakeProtocolBackend, Node;

const _a = '00000000-0000-4000-8000-00000000000a';
const _b = '00000000-0000-4000-8000-00000000000b';
const _c = '00000000-0000-4000-8000-00000000000c';
const _d = '00000000-0000-4000-8000-00000000000d';

void main() {
  late FakeProtocolBackend backend;
  late Node node;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() async {
    backend = FakeProtocolBackend()..pageSize = 2;
    node = await Node.create(backend);
  });

  tearDown(() => node.close());

  void remoteChild(String id, String name) => backend.remoteCreate(
    SyncEntityType.child,
    id,
    {'name': name, 'birthDate': '2019-03-01'},
  );

  Future<Set<String>> localNames() async =>
      (await node.children.watchAll().first).map((c) => c.name).toSet();

  test(
    'a row committed behind the cursor between two pages is still pulled',
    () async {
      remoteChild(_a, 'A');
      remoteChild(_b, 'B');
      remoteChild(_c, 'C');
      // A writer that started before page 1 was served commits after it.
      // With timestamps it landed behind the cursor; in the journal it is
      // simply the next position.
      backend.onPageServed = (pageIndex) {
        if (pageIndex == 0) remoteChild(_d, 'D');
      };

      await node.sync();
      await node.sync(); // a later sync must not be the one to notice it either

      expect(await localNames(), {'A', 'B', 'C', 'D'});
    },
  );

  test(
    'rows sharing the updated_at of a page boundary are all pulled',
    () async {
      // Same instant on the server; three distinct journal positions, and a
      // page boundary after the second.
      remoteChild(_a, 'A');
      remoteChild(_b, 'B');
      remoteChild(_c, 'C');

      await node.sync();
      await node.sync();

      expect(await localNames(), {'A', 'B', 'C'});
    },
  );
}
