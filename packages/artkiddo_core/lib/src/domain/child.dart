enum SyncState {
  localOnly,
  pendingUpload,
  synced,
  syncError,

  remoteThumbnail,

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
