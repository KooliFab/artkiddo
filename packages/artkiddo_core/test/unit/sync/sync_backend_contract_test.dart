import 'package:flutter_test/flutter_test.dart';

import 'package:artkiddo_core/src/contracts/sync_backend.dart';

class _ContractBackend extends SyncBackend {
  final childRows = <RemoteChildRow>[];
  final masterpieceRows = <RemoteMasterpieceRow>[];
  final purgedRows = <PurgedMasterpieceRow>[];

  @override
  Future<String> ensureMyFoyer() async => 'foyer';

  @override
  Future<void> upsertChild({
    required String id,
    required String foyerId,
    required String name,
    required DateTime birthDate,
    required DateTime createdAt,
  }) async {}

  @override
  Future<void> softDeleteChild(String id) async {}

  @override
  Future<void> upsertMasterpiece({
    required String id,
    required String foyerId,
    required String childId,
    required String displayObjectKey,
    String? thumbnailObjectKey,
    String? audioObjectKey,
    int? audioDurationMs,
    int audioByteSize = 0,
    required DateTime addedAt,
    required DateTime? drawnAt,
    required String? story,
    required String addedBy,
    required int byteSize,
    int? imageWidth,
    int? imageHeight,
  }) async {}

  @override
  Future<void> softDeleteMasterpiece(String id) async {}

  @override
  Future<void> softDeleteMasterpiecesForChild(String childId) async {}

  @override
  Future<List<RemoteChildRow>> pullChildren({
    required String foyerId,
    DateTime? since,
  }) async => childRows;

  @override
  Future<List<RemoteMasterpieceRow>> pullMasterpieces({
    required String foyerId,
    DateTime? since,
  }) async => masterpieceRows;

  @override
  Future<List<PurgedMasterpieceRow>> pullPurgedMasterpieceIds({
    required String foyerId,
    DateTime? since,
  }) async => purgedRows;
}

void main() {
  test(
    'legacy list adapters expose bounded typed pages and latest cursors',
    () async {
      final backend = _ContractBackend();
      final first = DateTime.utc(2024, 1, 1);
      final latest = DateTime.utc(2024, 1, 3);
      backend.childRows.addAll([
        RemoteChildRow(
          id: 'child-1',
          name: 'A',
          birthDate: DateTime.utc(2020),
          createdAt: first,
          updatedAt: latest,
        ),
        RemoteChildRow(
          id: 'child-2',
          name: 'B',
          birthDate: DateTime.utc(2021),
          createdAt: first,
          updatedAt: DateTime.utc(2024, 1, 2),
        ),
      ]);

      final page = await backend.pullChildrenPage(foyerId: 'foyer');

      expect(page.items, hasLength(2));
      expect(page.nextCursor, latest);
      expect(page.hasMore, isFalse);
      expect(page.isEmpty, isFalse);
    },
  );

  test('PullCursorSet is an independent value object', () {
    final children = DateTime.utc(2024, 1, 1);
    final masterpieces = DateTime.utc(2024, 1, 2);
    const empty = PullCursorSet();
    final cursors = empty.copyWith(
      children: children,
      masterpieces: masterpieces,
    );

    expect(
      cursors,
      PullCursorSet(children: children, masterpieces: masterpieces),
    );
    expect(cursors.copyWith(clearChildren: true).children, isNull);
    expect(cursors.purged, isNull);
  });
}
