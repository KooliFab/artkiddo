// Reproduction of data loss #2: rows missed by a paginated pull.
//
// `SyncEngine._pull` persists a stream cursor equal to the largest
// `updated_at` of the page it just applied, and the next request asks for
// rows strictly after that instant (`SyncBackend.pullChildrenPage(since:)`,
// same `isAfter` rule as `FakeHomeCloudApi`). A timestamp is not a position in
// commit order, so a row that lands behind the cursor is never returned again.
//
// Expected red until the pull follows an ordered change journal.
// Run without the skip: flutter test --run-skipped --tags known-loss

import 'package:artkiddo_core/artkiddo_core.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'sync_engine_test.dart' show Device;

DateTime _at(int second, [int millisecond = 0]) =>
    DateTime.utc(2030, 1, 1, 0, 0, second, millisecond);

RemoteChildRow _child(String id, String name, DateTime updatedAt) =>
    RemoteChildRow(
      id: id,
      name: name,
      birthDate: DateTime.utc(2019, 3, 1),
      createdAt: _at(0),
      updatedAt: updatedAt,
    );

/// A server that serves children in small pages ordered by `updated_at`,
/// resuming strictly after the cursor. [onPageServed] runs right after a page
/// has been handed to the client, which is where a concurrent write lands.
class _PagedChildrenBackend extends FakeHomeCloudApi {
  static const pageSize = 2;

  final List<RemoteChildRow> serverRows = [];
  void Function(int pageIndex)? onPageServed;
  int _pagesServed = 0;

  @override
  Future<PullPage<RemoteChildRow>> pullChildrenPage({
    required String familyId,
    DateTime? since,
  }) async {
    final matching =
        serverRows
            .where((r) => since == null || r.updatedAt.isAfter(since))
            .toList()
          ..sort((a, b) {
            final byTime = a.updatedAt.compareTo(b.updatedAt);
            return byTime != 0 ? byTime : a.id.compareTo(b.id);
          });
    final items = matching.take(pageSize).toList();
    final page = PullPage<RemoteChildRow>(
      items: items,
      nextCursor: items.isEmpty ? null : items.last.updatedAt,
      hasMore: matching.length > pageSize,
    );
    onPageServed?.call(_pagesServed++);
    return page;
  }
}

void main() {
  late _PagedChildrenBackend backend;
  late FakeObjectUploader uploader;
  late FakeObjectDownloader downloader;
  Device? device;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() {
    backend = _PagedChildrenBackend();
    uploader = FakeObjectUploader();
    downloader = FakeObjectDownloader(uploader.objects);
  });

  tearDown(() async {
    await device?.close();
    device = null;
  });

  Future<Device> newDevice() async => device = await Device.create(
    cloudApi: backend,
    uploader: uploader,
    downloader: downloader,
    userId: 'user-a',
  );

  Future<Set<String>> localNames(Device d) async => (await d.children
      .watchAll()
      .first).map((c) => c.name).toSet();

  test(
    'a row committed behind the cursor between two pages is still pulled',
    () async {
      backend.serverRows.addAll([
        _child('a', 'A', _at(1)),
        _child('b', 'B', _at(2)),
        _child('c', 'C', _at(3)),
      ]);
      // A writer that started before page 1 was served commits after it, with
      // an `updated_at` older than the cursor (`now()` is the transaction
      // start in Postgres, not the commit instant).
      backend.onPageServed = (pageIndex) {
        if (pageIndex == 0) {
          backend.serverRows.add(_child('d', 'D', _at(1, 500)));
        }
      };

      final a = await newDevice();
      await a.sync();
      await a.sync(); // a later sync must not be the one to notice it either

      expect(await localNames(a), {'A', 'B', 'C', 'D'});
    },
    tags: ['known-loss'],
    skip: 'Expected to fail until operations and safe deletions land',
  );

  test(
    'rows sharing the updated_at of a page boundary are all pulled',
    () async {
      backend.serverRows.addAll([
        _child('a', 'A', _at(1)),
        _child('b', 'B', _at(1)),
        _child('c', 'C', _at(1)),
      ]);

      final a = await newDevice();
      await a.sync();
      await a.sync();

      expect(await localNames(a), {'A', 'B', 'C'});
    },
    tags: ['known-loss'],
    skip: 'Expected to fail until operations and safe deletions land',
  );
}
