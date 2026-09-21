// Test doubles for the C-06 convergence engine.

import 'dart:typed_data';

import 'package:artkiddo_core/artkiddo_core.dart';

class _FakeChildRow {
  final String id;
  final String familyId;
  final String name;
  final DateTime birthDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const _FakeChildRow({
    required this.id,
    required this.familyId,
    required this.name,
    required this.birthDate,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  _FakeChildRow copyWith({
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) => _FakeChildRow(
    id: id,
    familyId: familyId,
    name: name,
    birthDate: birthDate,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
  );
}

class _FakeArtworkRow {
  final String id;
  final String familyId;
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
  final int byteSize;
  final int? imageWidth;
  final int? imageHeight;
  const _FakeArtworkRow({
    required this.id,
    required this.familyId,
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

  _FakeArtworkRow copyWith({DateTime? updatedAt, DateTime? deletedAt}) =>
      _FakeArtworkRow(
        id: id,
        familyId: familyId,
        childId: childId,
        displayObjectKey: displayObjectKey,
        thumbnailObjectKey: thumbnailObjectKey,
        audioObjectKey: audioObjectKey,
        audioDurationMs: audioDurationMs,
        audioByteSize: audioByteSize,
        addedAt: addedAt,
        drawnAt: drawnAt,
        story: story,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt ?? this.deletedAt,
        byteSize: byteSize,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      );
}

class FakeHomeCloudApi extends SyncBackend {
  final Map<String, String> membership = {}; // userId -> familyId
  final Map<String, _FakeChildRow> _children = {};
  final Map<String, _FakeArtworkRow> _artworks = {};
  int _clock = 0;

  String? currentUserId;

  Object? throwOnNextArtworkUpsert;

  DateTime _tick() {
    _clock += 1;
    return DateTime.utc(2000).add(Duration(microseconds: _clock));
  }

  @override
  Future<String> ensureMyFamily() async {
    final uid = currentUserId;
    if (uid == null) {
      throw StateError(
        'FakeHomeCloudApi.currentUserId must be set before calling ensureMyFamily()',
      );
    }
    final existing = membership[uid];
    if (existing != null) return existing;
    final familyId =
        'family-${membership.values.toSet().length + 1}-${DateTime.now().microsecondsSinceEpoch}';
    membership[uid] = familyId;
    return familyId;
  }

  void seedMembership(String userId, String familyId) =>
      membership[userId] = familyId;

  @override
  Future<void> upsertChild({
    required String id,
    required String familyId,
    required String name,
    required DateTime birthDate,
    required DateTime createdAt,
  }) async {
    final existing = _children[id];
    if (existing != null && existing.deletedAt != null) {
      throw const DeletedRowUpdateRejectedException(
        'C06_DELETED_ROW_UPDATE_REJECTED: fake',
      );
    }
    _children[id] = _FakeChildRow(
      id: id,
      familyId: familyId,
      name: name,
      birthDate: birthDate,
      createdAt: existing?.createdAt ?? createdAt,
      updatedAt: _tick(),
    );
  }

  @override
  Future<void> softDeleteChild(String id) async {
    final existing = _children[id];
    if (existing == null) return;
    _children[id] = existing.copyWith(updatedAt: _tick(), deletedAt: _tick());
  }

  @override
  Future<void> upsertArtwork({
    required String id,
    required String familyId,
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
  }) async {
    if (throwOnNextArtworkUpsert != null) {
      final e = throwOnNextArtworkUpsert!;
      throwOnNextArtworkUpsert = null;
      throw e;
    }
    final existing = _artworks[id];
    if (existing != null && existing.deletedAt != null) {
      throw const DeletedRowUpdateRejectedException(
        'C06_DELETED_ROW_UPDATE_REJECTED: fake',
      );
    }
    _artworks[id] = _FakeArtworkRow(
      id: id,
      familyId: familyId,
      childId: childId,
      displayObjectKey: displayObjectKey,
      thumbnailObjectKey: thumbnailObjectKey,
      audioObjectKey: audioObjectKey,
      audioDurationMs: audioDurationMs,
      audioByteSize: audioByteSize,
      addedAt: existing?.addedAt ?? addedAt,
      drawnAt: drawnAt,
      story: story,
      updatedAt: _tick(),
      byteSize: byteSize,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );
  }

  @override
  Future<void> softDeleteArtwork(String id) async {
    final existing = _artworks[id];
    if (existing == null) return;
    _artworks[id] = existing.copyWith(updatedAt: _tick(), deletedAt: _tick());
  }

  @override
  Future<void> softDeleteArtworksForChild(String childId) async {
    for (final mp
        in _artworks.values
            .where((m) => m.childId == childId && m.deletedAt == null)
            .toList()) {
      _artworks[mp.id] = mp.copyWith(updatedAt: _tick(), deletedAt: _tick());
    }
  }

  @override
  Future<List<RemoteChildRow>> pullChildren({
    required String familyId,
    DateTime? since,
  }) async {
    return _children.values
        .where(
          (c) =>
              c.familyId == familyId &&
              (since == null || c.updatedAt.isAfter(since)),
        )
        .map(
          (c) => RemoteChildRow(
            id: c.id,
            name: c.name,
            birthDate: c.birthDate,
            createdAt: c.createdAt,
            updatedAt: c.updatedAt,
            deletedAt: c.deletedAt,
          ),
        )
        .toList();
  }

  @override
  Future<List<RemoteArtworkRow>> pullArtworks({
    required String familyId,
    DateTime? since,
  }) async {
    return _artworks.values
        .where(
          (m) =>
              m.familyId == familyId &&
              (since == null || m.updatedAt.isAfter(since)),
        )
        .map(
          (m) => RemoteArtworkRow(
            id: m.id,
            childId: m.childId,
            displayObjectKey: m.displayObjectKey,
            thumbnailObjectKey: m.thumbnailObjectKey,
            audioObjectKey: m.audioObjectKey,
            audioDurationMs: m.audioDurationMs,
            audioByteSize: m.audioByteSize,
            addedAt: m.addedAt,
            drawnAt: m.drawnAt,
            story: m.story,
            updatedAt: m.updatedAt,
            deletedAt: m.deletedAt,
            byteSize: m.byteSize,
            imageWidth: m.imageWidth,
            imageHeight: m.imageHeight,
          ),
        )
        .toList();
  }

  final Map<String, DateTime> _purgeLog = {};

  void purgeArtwork(String id) {
    _artworks.remove(id);
    _purgeLog[id] = _tick();
  }

  @override
  Future<List<PurgedArtworkRow>> pullPurgedArtworkIds({
    required String familyId,
    DateTime? since,
  }) async {
    return _purgeLog.entries
        .where((e) => since == null || e.value.isAfter(since))
        .map((e) => PurgedArtworkRow(id: e.key, purgedAt: e.value))
        .toList();
  }

  // Test-only introspection.
  bool childExists(String id) => _children.containsKey(id);
  bool childIsDeleted(String id) => _children[id]?.deletedAt != null;
  bool artworkExists(String id) => _artworks.containsKey(id);
  bool artworkIsDeleted(String id) => _artworks[id]?.deletedAt != null;
  String? artworkStory(String id) => _artworks[id]?.story;
  int artworksInFamily(String familyId) =>
      _artworks.values.where((m) => m.familyId == familyId).length;
}

class FakeObjectUploader implements ObjectUploader {
  final Map<String, Uint8List> objects = {};
  int uploadCount = 0;

  bool quotaExceeded = false;

  @override
  Future<String> uploadDerivative({
    required List<int> bytes,
    required String artworkId,
    required ObjectVariant variant,
    String? childId,
    String? fileName,
  }) async {
    if (quotaExceeded) {
      throw const QuotaExceededException();
    }
    uploadCount++;
    final key = 'fake/$artworkId/${variant.name}.jpg';
    objects[key] = Uint8List.fromList(bytes);
    return key;
  }
}

class FakeObjectDownloader implements ObjectDownloader {
  final Map<String, Uint8List> objects;
  FakeObjectDownloader(this.objects);

  final Set<String> failOnce = {};

  @override
  Future<List<int>> downloadByKey(String key) async {
    if (failOnce.remove(key)) {
      throw Exception('simulated transient download failure for $key');
    }
    final bytes = objects[key];
    if (bytes == null) {
      throw Exception(
        'no object at key $key (ownership check failed, or key unknown)',
      );
    }
    return bytes;
  }
}
