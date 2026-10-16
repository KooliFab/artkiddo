import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../contracts/following.dart';
import '../../local/logging/log.dart';
import '../providers/core_providers.dart';
import 'gallery_providers.dart';

/// Compositions enabling `followedHouseholds` must override this; the default
/// follows nobody (see [NoFollowingApi]).
final followingApiProvider = Provider<FollowingApi>(
  (ref) => const NoFollowingApi(),
);

/// Clock of the followed feed, injectable so URI expiry is testable.
final followedFeedClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// The households the user follows, with the children they may see. Empty
/// without the capability: the provider is never read through the contract
/// then.
final followedFamiliesProvider = FutureProvider<List<FollowedFamily>>((
  ref,
) async {
  if (!ref.watch(appCapabilitiesProvider).followedHouseholds) return const [];
  // Another session follows other households: never show the previous one's.
  final email = ref.watch(sessionEmailProvider);
  if (email == null) return const [];
  return ref.watch(followingApiProvider).listFollowedFamilies();
});

/// Every child the user sees as a follower, keyed by id.
final followedChildrenProvider = Provider<Map<String, FollowedChildInfo>>((
  ref,
) {
  final families = ref.watch(followedFamiliesProvider).value ?? const [];
  return {
    for (final family in families)
      for (final child in family.children)
        child.id: FollowedChildInfo(child: child, family: family),
  };
});

/// A followed child with the household it belongs to (for labels such as
/// "Tom · Anne").
class FollowedChildInfo {
  final FollowedChild child;
  final FollowedFamily family;

  const FollowedChildInfo({required this.child, required this.family});
}

/// The loaded part of the followed feed.
class FollowedFeedState {
  final List<FollowedArtwork> items;
  final String? nextCursor;
  final bool hasMore;
  final DateTime urisExpireAt;

  /// The last `loadMore` failed; the loaded items stay and the next attempt
  /// retries the same cursor.
  final bool loadMoreFailed;

  const FollowedFeedState({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
    required this.urisExpireAt,
    this.loadMoreFailed = false,
  });

  static final empty = FollowedFeedState(
    items: const [],
    nextCursor: null,
    hasMore: false,
    urisExpireAt: DateTime.utc(9999),
  );

  FollowedFeedState append(FollowedFeedPage page) => FollowedFeedState(
    items: [...items, ...page.items],
    nextCursor: page.nextCursor,
    hasMore: page.hasMore,
    // Every loaded URI must still work: the earliest expiry wins.
    urisExpireAt: page.urisExpireAt.isBefore(urisExpireAt)
        ? page.urisExpireAt
        : urisExpireAt,
  );

  FollowedFeedState withLoadMoreFailed() => FollowedFeedState(
    items: items,
    nextCursor: nextCursor,
    hasMore: hasMore,
    urisExpireAt: urisExpireAt,
    loadMoreFailed: true,
  );
}

/// Pages of artworks from followed households for the current gallery filter:
/// all of them under "All", one followed child's when that child is selected,
/// none when a child of the user's own household is selected.
class FollowedFeedNotifier extends AsyncNotifier<FollowedFeedState> {
  static const pageSize = 30;

  String? _childId;
  bool _loadingMore = false;

  @override
  Future<FollowedFeedState> build() async {
    if (!ref.watch(appCapabilitiesProvider).followedHouseholds) {
      return FollowedFeedState.empty;
    }
    final filter = ref.watch(galleryFilterProvider);
    final families = await ref.watch(followedFamiliesProvider.future);
    if (families.isEmpty) return FollowedFeedState.empty;

    String? childId;
    if (filter case OneChild(childId: final selected)) {
      final followed = families.any(
        (family) => family.children.any((child) => child.id == selected),
      );
      if (!followed) return FollowedFeedState.empty;
      childId = selected;
    }
    _childId = childId;
    _loadingMore = false;
    final page = await ref
        .read(followingApiProvider)
        .feedPage(limit: pageSize, childId: childId);
    return FollowedFeedState.empty.append(page);
  }

  /// Loads the next page. Ignored while one is loading, when nothing is
  /// left, or before the first page is in.
  Future<void> loadMore() async {
    final current = state.value;
    if (_loadingMore || current == null || !current.hasMore) return;
    _loadingMore = true;
    final childId = _childId;
    try {
      final page = await ref
          .read(followingApiProvider)
          .feedPage(
            cursor: current.nextCursor,
            limit: pageSize,
            childId: childId,
          );
      // A filter change rebuilt the notifier meanwhile: drop the stale page.
      if (!ref.mounted || _childId != childId) return;
      state = AsyncData(current.append(page));
    } catch (e, st) {
      // Shown as a retry at the end of the feed; the loaded items stay.
      Log.e('Followed feed page failed', e, st, 'Following');
      if (ref.mounted) state = AsyncData(current.withLoadMoreFailed());
    } finally {
      _loadingMore = false;
    }
  }

  /// Reloads from the first page when the loaded URIs have expired, for
  /// example after the app comes back to the foreground.
  void refreshIfExpired() {
    final current = state.value;
    if (current == null) return;
    if (!ref.read(followedFeedClockProvider)().isBefore(current.urisExpireAt)) {
      ref.invalidateSelf();
    }
  }

  /// Reloads the followed households and the feed from the start.
  void refresh() {
    ref.invalidate(followedFamiliesProvider);
    ref.invalidateSelf();
  }
}

final followedFeedProvider =
    AsyncNotifierProvider<FollowedFeedNotifier, FollowedFeedState>(
      FollowedFeedNotifier.new,
    );
