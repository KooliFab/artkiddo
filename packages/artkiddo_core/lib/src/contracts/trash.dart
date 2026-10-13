import '../domain/action_result.dart';

class TrashedArtwork {
  final String id;
  final String childId;
  final String childName;
  final DateTime deletedAt;
  final DateTime purgeAt;
  final String? story;

  /// Local vault path or temporary authorized remote preview.
  final String? previewPath;
  final Uri? previewUri;

  /// The remote side purged this artwork (or its child): restoring it keeps
  /// it on this phone only. It will not be backed up or shown on other
  /// devices, and the person must be told so.
  final bool existsOnlyHere;

  const TrashedArtwork({
    required this.id,
    required this.childId,
    required this.childName,
    required this.deletedAt,
    required this.purgeAt,
    this.story,
    this.previewPath,
    this.previewUri,
    this.existsOnlyHere = false,
  });
}

abstract class TrashRepository {
  Future<ActionResult<List<TrashedArtwork>>> listTrash({String? scopeId});
  Future<ActionResult<void>> restore(String artworkId);
  Future<ActionResult<void>> purge(String artworkId);
  Future<ActionResult<void>> purgeAll({String? scopeId});

  Future<ActionResult<int>> purgeExpired({DateTime? now});
}
