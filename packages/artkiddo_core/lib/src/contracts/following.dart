library;

import 'household.dart';

/// A child of a followed household, as far as the follower may see it.
class FollowedChild {
  final String id;
  final String name;

  const FollowedChild({required this.id, required this.name});
}

/// A household the user follows: read-only access to the children its
/// audience lets them see. Following never makes the user a member, and the
/// household's artworks are never copied into the local vault.
class FollowedFamily {
  final String familyId;

  /// Display name chosen by the household; null until one of its members
  /// sets it.
  final String? familyName;

  /// Name of the audience the user joined, as the household named it.
  final String audienceName;
  final DateTime followedAt;
  final List<FollowedChild> children;

  const FollowedFamily({
    required this.familyId,
    required this.familyName,
    required this.audienceName,
    required this.followedAt,
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
/// Joining a household's audience happens in the composition (it owns the
/// invite flow for codes that are not household codes); this contract only
/// reads what follows from it and lets the user stop following.
abstract class FollowingApi {
  Future<List<FollowedFamily>> listFollowedFamilies();

  /// The page after [cursor] (the first page when null), at most [limit]
  /// artworks, optionally for one followed [childId]. The user's own
  /// household is never part of it.
  Future<FollowedFeedPage> feedPage({
    String? cursor,
    int limit = 30,
    String? childId,
  });

  /// Stops following [familyId]. Idempotent.
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
  Future<void> unfollow(String familyId) async {
    throw const HouseholdUnavailableException();
  }
}
