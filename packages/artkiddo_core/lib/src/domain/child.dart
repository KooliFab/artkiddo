/// Synchronization state for local-first entities.
enum SyncState {
  localOnly,
  pendingUpload,
  synced,
  syncError,

  /// An artwork known through remote synchronization whose thumbnail has
  /// downloaded but whose display derivative has not (either never
  /// requested yet — deferred until the artwork is opened — or still in
  /// flight). Distinct from [syncError]: nothing has failed here, the
  /// download is simply not complete yet.
  remoteThumbnail,

  /// An artwork known through remote synchronization whose thumbnail
  /// download failed and did not recover on its own. The gallery shows a
  /// pending/error tile — never a blank space.
  downloadFailed,
}

class Child {
  final String id; // UUIDv4
  final String name;
  final DateTime birthDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncState syncState;

  const Child({
    required this.id,
    required this.name,
    required this.birthDate,
    required this.createdAt,
    required this.updatedAt,
    this.syncState = SyncState.localOnly,
  });

  Child copyWith({
    String? id,
    String? name,
    DateTime? birthDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    SyncState? syncState,
  }) {
    return Child(
      id: id ?? this.id,
      name: name ?? this.name,
      birthDate: birthDate ?? this.birthDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncState: syncState ?? this.syncState,
    );
  }
}
