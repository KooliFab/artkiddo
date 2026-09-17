import '../domain/action_result.dart';
import '../domain/app_failure.dart';

class ShareLink {
  final String id;
  final String? url;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool revoked;
  final bool includeAudio;

  const ShareLink({
    required this.id,
    required this.url,
    required this.createdAt,
    required this.expiresAt,
    required this.revoked,
    this.includeAudio = false,
  });

  ShareLink copyWith({
    String? id,
    String? url,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? revoked,
    bool? includeAudio,
  }) {
    return ShareLink(
      id: id ?? this.id,
      url: url ?? this.url,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      revoked: revoked ?? this.revoked,
      includeAudio: includeAudio ?? this.includeAudio,
    );
  }
}

abstract class SharingService {
  Future<ActionResult<List<ShareLink>>> listLinks(String childId);

  Future<ActionResult<ShareLink>> createLink(
    String childId, {
    bool includeAudio = false,
  });

  Future<ActionResult<void>> updateIncludeAudio(
    String linkId,
    bool includeAudio,
  );
  Future<ActionResult<void>> revokeLink(String linkId);
}

/// Default implementation when no composition has bound a real
/// [SharingService].
///
/// `ActionResult` already has a truthful way to say "this isn't available" —
/// [ActionFailed] with [UnavailableFailure] — so every member uses it rather
/// than reporting empty success or a user cancellation that never happened.
final class NoSharingService implements SharingService {
  const NoSharingService();

  @override
  Future<ActionResult<List<ShareLink>>> listLinks(String childId) async {
    return const ActionFailed(UnavailableFailure());
  }

  @override
  Future<ActionResult<ShareLink>> createLink(
    String childId, {
    bool includeAudio = false,
  }) async {
    return const ActionFailed(UnavailableFailure());
  }

  @override
  Future<ActionResult<void>> updateIncludeAudio(
    String linkId,
    bool includeAudio,
  ) async {
    return const ActionFailed(UnavailableFailure());
  }

  @override
  Future<ActionResult<void>> revokeLink(String linkId) async {
    return const ActionFailed(UnavailableFailure());
  }
}
