import 'dart:async';
import 'dart:io';

import 'package:artkiddo_core/artkiddo_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

FollowedArtwork _artwork(String id, DateTime addedAt, {String child = 'tom'}) =>
    FollowedArtwork(
      id: id,
      familyId: 'family-anne',
      familyName: 'Anne',
      childId: child,
      childName: 'Tom',
      addedAt: addedAt,
    );

class _FakeFollowingApi implements FollowingApi {
  final List<FollowedFamily> families;
  final List<FollowedArtwork> all;
  static const pageSize = 2;
  DateTime expiresAt;
  final calls = <({String? cursor, String? childId})>[];
  bool failNextPage = false;

  _FakeFollowingApi({
    required this.families,
    required this.all,
    DateTime? expiresAt,
  }) : expiresAt = expiresAt ?? DateTime.utc(2026, 10, 15, 12);

  @override
  Future<List<FollowedFamily>> listFollowedFamilies() async => families;

  @override
  Future<FollowedFeedPage> feedPage({
    String? cursor,
    int limit = 30,
    String? childId,
  }) async {
    calls.add((cursor: cursor, childId: childId));
    if (failNextPage) {
      failNextPage = false;
      throw const SocketException('offline');
    }
    final matching = [
      for (final a in all)
        if (childId == null || a.childId == childId) a,
    ];
    final start = cursor == null ? 0 : int.parse(cursor);
    final end = (start + pageSize).clamp(0, matching.length);
    final hasMore = end < matching.length;
    return FollowedFeedPage(
      items: matching.sublist(start, end),
      nextCursor: hasMore ? '$end' : null,
      hasMore: hasMore,
      urisExpireAt: expiresAt,
    );
  }

  @override
  Future<void> unfollow(String familyId) async {}
}

Child _localChild(String id, String name) => Child(
  id: id,
  name: name,
  birthDate: DateTime(2020),
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
);

void main() {
  late StreamController<List<Child>> localChildren;
  late _FakeFollowingApi api;
  late DateTime now;

  ProviderContainer container({bool followed = true, bool signedIn = true}) {
    final c = ProviderContainer(
      overrides: [
        appCapabilitiesProvider.overrideWithValue(
          followed ? AppCapabilities.cloud : AppCapabilities.local,
        ),
        followingApiProvider.overrideWithValue(api),
        sessionEmailProvider.overrideWithValue(
          signedIn ? 'paul@example.test' : null,
        ),
        followedFeedClockProvider.overrideWithValue(() => now),
        allChildrenStreamProvider.overrideWith((ref) => localChildren.stream),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    localChildren = StreamController<List<Child>>.broadcast();
    now = DateTime.utc(2026, 10, 15, 10);
    api = _FakeFollowingApi(
      families: [
        FollowedFamily(
          familyId: 'family-anne',
          familyName: 'Anne',
          audienceName: 'Côté Paul',
          followedAt: DateTime.utc(2026, 10, 1),
          children: const [FollowedChild(id: 'tom', name: 'Tom')],
        ),
      ],
      all: [
        _artwork('t3', DateTime.utc(2026, 10, 14)),
        _artwork('t2', DateTime.utc(2026, 10, 12)),
        _artwork('t1', DateTime.utc(2026, 10, 10)),
      ],
    );
  });

  tearDown(() => localChildren.close());

  group('mergeGalleryFeed', () {
    test('mixes both walls newest first, drawing date first', () {
      final local = ArtworkTile(
        artwork: Artwork(
          id: 'l1',
          childId: 'leo',
          addedAt: DateTime.utc(2026, 10, 13),
          relativeImagePath: 'a.jpg',
        ),
        artworkId: 'l1',
        childId: 'leo',
        childName: 'Léo',
        imageFile: File(''),
        imageExists: false,
        addedAt: DateTime.utc(2026, 10, 13),
        drawnAt: DateTime.utc(2026, 10, 9),
        age: '',
        story: null,
        aspectRatio: 1,
      );
      final feed = mergeGalleryFeed(
        [local],
        [
          _artwork('t2', DateTime.utc(2026, 10, 12)),
          _artwork('t1', DateTime.utc(2026, 10, 10)),
        ],
      );
      expect(feed.map((item) => item.id), ['t2', 't1', 'l1']);
      expect(feed.first, isA<FollowedFeedItem>());
      expect(feed.last, isA<LocalFeedItem>());
    });

    test('a followed artwork without dimensions is square', () {
      expect(
        FollowedFeedItem(_artwork('t', DateTime.utc(2026))).aspectRatio,
        1,
      );
    });
  });

  group('followedFeedProvider', () {
    test('signed out, nobody is followed', () async {
      final c = container(signedIn: false);
      expect(await c.read(followedFamiliesProvider.future), isEmpty);
      expect((await c.read(followedFeedProvider.future)).items, isEmpty);
      expect(api.calls, isEmpty);
    });

    test('without the capability it is empty and never asks', () async {
      final c = container(followed: false);
      final state = await c.read(followedFeedProvider.future);
      expect(state.items, isEmpty);
      expect(api.calls, isEmpty);
    });

    test('loads the first page, then appends the next one', () async {
      final c = container();
      final first = await c.read(followedFeedProvider.future);
      expect(first.items.map((a) => a.id), ['t3', 't2']);
      expect(first.hasMore, isTrue);

      await c.read(followedFeedProvider.notifier).loadMore();
      final all = c.read(followedFeedProvider).value!;
      expect(all.items.map((a) => a.id), ['t3', 't2', 't1']);
      expect(all.hasMore, isFalse);
      expect(api.calls.last.cursor, '2');
    });

    test('a failed page keeps the loaded items and can be retried', () async {
      final c = container();
      await c.read(followedFeedProvider.future);
      api.failNextPage = true;
      await c.read(followedFeedProvider.notifier).loadMore();
      final failed = c.read(followedFeedProvider).value!;
      expect(failed.items, hasLength(2));
      expect(failed.loadMoreFailed, isTrue);

      await c.read(followedFeedProvider.notifier).loadMore();
      expect(c.read(followedFeedProvider).value!.items, hasLength(3));
    });

    test('a followed child filter asks for that child only', () async {
      final c = container();
      c.read(galleryFilterProvider.notifier).setFilter(const OneChild('tom'));
      await c.read(followedFeedProvider.future);
      expect(api.calls.single.childId, 'tom');
    });

    test('a filter on one of the user\'s own children shows none', () async {
      final c = container();
      c.read(galleryFilterProvider.notifier).setFilter(const OneChild('leo'));
      final state = await c.read(followedFeedProvider.future);
      expect(state.items, isEmpty);
      expect(api.calls, isEmpty);
    });

    test('reloads from the first page once the URIs expire', () async {
      final c = container();
      await c.read(followedFeedProvider.future);
      c.read(followedFeedProvider.notifier).refreshIfExpired();
      await c.read(followedFeedProvider.future);
      expect(api.calls, hasLength(1), reason: 'still valid');

      now = DateTime.utc(2026, 10, 15, 13);
      c.read(followedFeedProvider.notifier).refreshIfExpired();
      await c.read(followedFeedProvider.future);
      expect(api.calls, hasLength(2));
      expect(api.calls.last.cursor, isNull);
    });
  });

  group('gallery filter', () {
    test('a followed child filter survives local children updates', () async {
      final c = container();
      c.listen(galleryFilterProvider, (_, _) {});
      c.listen(allChildrenStreamProvider, (_, _) {});
      await c.read(followedFamiliesProvider.future);
      c.read(galleryFilterProvider.notifier).setFilter(const OneChild('tom'));

      localChildren.add([_localChild('leo', 'Léo')]);
      await Future<void>.delayed(Duration.zero);

      expect(c.read(galleryFilterProvider), const OneChild('tom'));
      expect(c.read(galleryFilterResetBannerProvider), isNull);
    });

    test('a deleted local child still resets the filter', () async {
      final c = container(followed: false);
      c.listen(galleryFilterProvider, (_, _) {});
      c.listen(allChildrenStreamProvider, (_, _) {});
      localChildren.add([_localChild('leo', 'Léo')]);
      await Future<void>.delayed(Duration.zero);
      c.read(galleryFilterProvider.notifier).setFilter(const OneChild('leo'));

      localChildren.add(const []);
      await Future<void>.delayed(Duration.zero);

      expect(c.read(galleryFilterProvider), const AllChildren());
      expect(c.read(galleryFilterResetBannerProvider), 'Léo');
    });

    test('unfollowing the filtered child resets the filter', () async {
      final c = container();
      c.listen(galleryFilterProvider, (_, _) {});
      c.listen(followedChildrenProvider, (_, _) {});
      await c.read(followedFamiliesProvider.future);
      c.read(galleryFilterProvider.notifier).setFilter(const OneChild('tom'));

      api.families.clear();
      c.invalidate(followedFamiliesProvider);
      await c.read(followedFamiliesProvider.future);
      await Future<void>.delayed(Duration.zero);

      expect(c.read(galleryFilterProvider), const AllChildren());
      expect(c.read(galleryFilterResetBannerProvider), 'Tom');
    });
  });
}
