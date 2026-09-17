import '../domain/action_result.dart';

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

/// Honest default implementation for local environments where web links are not available.
final class NoSharingService implements SharingService {
  const NoSharingService();

  @override
  Future<ActionResult<List<ShareLink>>> listLinks(String childId) async {
    return const ActionSuccess([]);
  }

  @override
  Future<ActionResult<ShareLink>> createLink(
    String childId, {
    bool includeAudio = false,
  }) async {
    return const ActionCancelled();
  }

  @override
  Future<ActionResult<void>> updateIncludeAudio(
    String linkId,
    bool includeAudio,
  ) async {
    return const ActionCancelled();
  }

  @override
  Future<ActionResult<void>> revokeLink(String linkId) async {
    return const ActionCancelled();
  }
}

