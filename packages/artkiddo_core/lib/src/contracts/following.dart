library;

import 'household.dart';

/// A child of a followed household. The follower may see every child;
/// [followed] is their own choice of whose drawings they receive.
class FollowedChild {
  final String id;
  final String name;
  final bool followed;

  const FollowedChild({
    required this.id,
    required this.name,
    this.followed = true,
  });
}

/// A household the user asked to follow or follows, read-only. Following
/// never makes the user a member, and the household's artworks are never
/// copied into the local vault.
class FollowedFamily {
  final String familyId;

  /// Display name chosen by the household; null until one of its members
  /// sets it.
  final String? familyName;

  /// The request waits for a parent of the household: nothing is visible yet
  /// and [children] is empty.
  final bool isPending;

  /// Null while [isPending].
  final DateTime? followedAt;

  /// Every child is followed, future ones included; otherwise only the
  /// children marked [FollowedChild.followed].
  final bool followsAll;
  final List<FollowedChild> children;

  const FollowedFamily({
    required this.familyId,
    required this.familyName,
    required this.isPending,
    required this.followedAt,
    required this.followsAll,
    required this.children,
  });
}

/// One artwork of a followed household. Read-only: it has no local row, no
/// local file and no backup status. Media arrive as temporary authorized
/// URIs that expire at [FollowedFeedPage.urisExpireAt]; a null URI means the
/// media is not available yet.
class FollowedArtwork {
  final String id;
  final String familyId;
  final String? familyName;
  final String childId;
  final String childName;
  final DateTime addedAt;
  final DateTime? drawnAt;
  final String? story;
  final Uri? imageUri;
  final Uri? thumbnailUri;
  final Uri? audioUri;
  final Duration? audioDuration;
  final int? imageWidth;
  final int? imageHeight;

  const FollowedArtwork({
    required this.id,
    required this.familyId,
    required this.familyName,
    required this.childId,
    required this.childName,
    required this.addedAt,
    this.drawnAt,
    this.story,
    this.imageUri,
    this.thumbnailUri,
    this.audioUri,
    this.audioDuration,
    this.imageWidth,
    this.imageHeight,
  });

  bool get hasAudio => audioUri != null;
}

/// One page of the followed feed, newest first. [nextCursor] is opaque and
/// present exactly when [hasMore].
class FollowedFeedPage {
  final List<FollowedArtwork> items;
  final String? nextCursor;
  final bool hasMore;

  /// When the URIs of [items] stop working; the page must be fetched again
  /// after that.
  final DateTime urisExpireAt;

  const FollowedFeedPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
    required this.urisExpireAt,
  });
}

/// Read-only access to the households the signed-in user follows.
///
/// Asking to follow a household happens in the composition (it owns the
/// invite flow for codes that are not household codes); this contract reads
/// what follows from it, lets the user choose the children they follow and
/// stop following.
abstract class FollowingApi {
  /// Pending requests and accepted follows.
  Future<List<FollowedFamily>> listFollowedFamilies();

  /// Follows only [childIds] of an accepted [familyId]; an empty list
  /// follows every child, future ones included.
  Future<void> setFollowedChildren(String familyId, List<String> childIds);

  /// The page after [cursor] (the first page when null), at most [limit]
  /// artworks, optionally for one followed [childId]. The user's own
  /// household is never part of it.
  Future<FollowedFeedPage> feedPage({
    String? cursor,
    int limit = 30,
    String? childId,
  });

  /// Stops following [familyId], or cancels the pending request. Idempotent.
  Future<void> unfollow(String familyId);
}

/// Default when no composition bound a real [FollowingApi]: the user follows
/// nobody, which is the truthful answer without the capability. Stopping a
/// follow that cannot exist fails loudly.
final class NoFollowingApi implements FollowingApi {
  const NoFollowingApi();

  @override
  Future<List<FollowedFamily>> listFollowedFamilies() async => const [];

  @override
  Future<FollowedFeedPage> feedPage({
    String? cursor,
    int limit = 30,
    String? childId,
  }) async => FollowedFeedPage(
    items: const [],
    nextCursor: null,
    hasMore: false,
    urisExpireAt: DateTime.utc(9999),
  );

  @override
  Future<void> setFollowedChildren(
    String familyId,
    List<String> childIds,
  ) async {
    throw const HouseholdUnavailableException();
  }

  @override
  Future<void> unfollow(String familyId) async {
    throw const HouseholdUnavailableException();
  }
}
