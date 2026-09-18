/// Vendor-neutral synchronization boundary.
///
/// This file is deliberately free of Flutter, Drift, provider SDK and
/// wire-map dependencies. Concrete adapters decode their provider
/// payloads and return these typed values to the local application.
library;

/// Thrown when a remote delete has already won a concurrent update.
class DeletedRowUpdateRejectedException implements Exception {
  final String message;
  const DeletedRowUpdateRejectedException(this.message);

  @override
  String toString() => 'DeletedRowUpdateRejectedException: $message';
}

/// A remote service asks the caller to slow down.
class RateLimitedException implements Exception {
  final Duration? retryAfter;
  const RateLimitedException({this.retryAfter});

  @override
  String toString() => 'RateLimitedException(retryAfter: $retryAfter)';
}

/// One typed child row returned by a sync pull.
class RemoteChildRow {
  final String id;
  final String name;
  final DateTime birthDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const RemoteChildRow({
    required this.id,
    required this.name,
    required this.birthDate,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
}

/// One typed masterpiece row returned by a sync pull.
class RemoteMasterpieceRow {
  final String id;
  final String childId;
  final String? displayObjectKey;
  final String? thumbnailObjectKey;
  final String? audioObjectKey;
  final int? audioDurationMs;
  final int audioByteSize;
  final DateTime addedAt;
  final DateTime? drawnAt;
  final String? story;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  /// The server's authoritative byte count for quota accounting.
  final int byteSize;
  final int? imageWidth;
  final int? imageHeight;

  const RemoteMasterpieceRow({
    required this.id,
    required this.childId,
    required this.displayObjectKey,
    required this.thumbnailObjectKey,
    this.audioObjectKey,
    this.audioDurationMs,
    this.audioByteSize = 0,
    required this.addedAt,
    required this.drawnAt,
    required this.story,
    required this.updatedAt,
    required this.byteSize,
    this.imageWidth,
    this.imageHeight,
    this.deletedAt,
  });
}

/// One tombstone for an artwork physically removed after the trash
/// window.
class PurgedMasterpieceRow {
  final String id;
  final DateTime purgedAt;

  const PurgedMasterpieceRow({required this.id, required this.purgedAt});
}

/// A bounded page returned by one remote stream.
///
/// [nextCursor] is only safe to persist after every item in [items]
/// has been applied durably. [hasMore] lets an adapter expose server
/// pagination without forcing the public core to know its provider's
/// page token format.
class PullPage<T> {
  final List<T> items;
  final DateTime? nextCursor;
  final bool hasMore;

  const PullPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  bool get isEmpty => items.isEmpty;
}

/// Independent cursors for the three remote streams.
///
/// Drift v11 persists this value object as three durable stream
/// cursors. Keeping it in the neutral contract means public/local and
/// private/cloud adapters share the same pagination semantics without
/// exposing a provider token.
class PullCursorSet {
  final DateTime? children;
  final DateTime? masterpieces;
  final DateTime? purged;

  const PullCursorSet({this.children, this.masterpieces, this.purged});

  PullCursorSet copyWith({
    DateTime? children,
    DateTime? masterpieces,
    DateTime? purged,
    bool clearChildren = false,
    bool clearMasterpieces = false,
    bool clearPurged = false,
  }) {
    return PullCursorSet(
      children: clearChildren ? null : (children ?? this.children),
      masterpieces: clearMasterpieces
          ? null
          : (masterpieces ?? this.masterpieces),
      purged: clearPurged ? null : (purged ?? this.purged),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PullCursorSet &&
      _sameInstant(other.children, children) &&
      _sameInstant(other.masterpieces, masterpieces) &&
      _sameInstant(other.purged, purged);

  @override
  int get hashCode => Object.hash(
    children?.microsecondsSinceEpoch,
    masterpieces?.microsecondsSinceEpoch,
    purged?.microsecondsSinceEpoch,
  );
}

bool _sameInstant(DateTime? left, DateTime? right) {
  if (left == null || right == null) return left == right;
  return left.isAtSameMomentAs(right);
}

/// Public sync contract implemented by a private/cloud adapter.
abstract class SyncBackend {
  Future<String> ensureMyFoyer();

  Future<void> upsertChild({
    required String id,
    required String foyerId,
    required String name,
    required DateTime birthDate,
    required DateTime createdAt,
  });

  Future<void> softDeleteChild(String id);

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
  });

  Future<void> softDeleteMasterpiece(String id);
  Future<void> softDeleteMasterpiecesForChild(String childId);

  /// Legacy list methods remain the compatibility bridge until
  /// adapters all expose bounded pages. Their payload is already
  /// typed at this boundary.
  Future<List<RemoteChildRow>> pullChildren({
    required String foyerId,
    DateTime? since,
  });

  Future<List<RemoteMasterpieceRow>> pullMasterpieces({
    required String foyerId,
    DateTime? since,
  });

  Future<List<PurgedMasterpieceRow>> pullPurgedMasterpieceIds({
    required String foyerId,
    DateTime? since,
  });

  Future<PullPage<RemoteChildRow>> pullChildrenPage({
    required String foyerId,
    DateTime? since,
  }) async {
    final rows = await pullChildren(foyerId: foyerId, since: since);
    return PullPage(
      items: rows,
      nextCursor: _latest(rows.map((row) => row.updatedAt)),
      hasMore: false,
    );
  }

  Future<PullPage<RemoteMasterpieceRow>> pullMasterpiecesPage({
    required String foyerId,
    DateTime? since,
  }) async {
    final rows = await pullMasterpieces(foyerId: foyerId, since: since);
    return PullPage(
      items: rows,
      nextCursor: _latest(rows.map((row) => row.updatedAt)),
      hasMore: false,
    );
  }

  Future<PullPage<PurgedMasterpieceRow>> pullPurgedMasterpieceIdsPage({
    required String foyerId,
    DateTime? since,
  }) async {
    final rows = await pullPurgedMasterpieceIds(foyerId: foyerId, since: since);
    return PullPage(
      items: rows,
      nextCursor: _latest(rows.map((row) => row.purgedAt)),
      hasMore: false,
    );
  }
}

DateTime? _latest(Iterable<DateTime> values) {
  DateTime? latest;
  for (final value in values) {
    if (latest == null || value.isAfter(latest)) latest = value;
  }
  return latest;
}
