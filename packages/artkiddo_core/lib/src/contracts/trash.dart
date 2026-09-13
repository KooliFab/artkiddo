import '../domain/action_result.dart';

class TrashedArtwork {
  final String id;
  final String childId;
  final String childName;
  final DateTime deletedAt;
  final DateTime purgeAt;
  final String? story;

  const TrashedArtwork({
    required this.id,
    required this.childId,
    required this.childName,
    required this.deletedAt,
    required this.purgeAt,
    this.story,
  });
}

abstract class TrashRepository {
  Future<ActionResult<List<TrashedArtwork>>> listTrash({String? scopeId});
  Future<ActionResult<void>> restore(String masterpieceId);
  Future<ActionResult<void>> purge(String masterpieceId);
  Future<ActionResult<void>> purgeAll({String? scopeId});

  Future<ActionResult<int>> purgeExpired({DateTime? now});
}
