import 'child.dart';

const Object _unset = Object();

class Masterpiece {
  final String id; // UUIDv4
  final String childId;

  final String? relativeImagePath;

  final DateTime addedAt;

  final DateTime? drawnAt;

  final String? story; // Anecdote told by child; null = no anecdote

  final String? displayImagePath;

  final String? thumbnailImagePath;

  final int? imageWidth;
  final int? imageHeight;

  final String? relativeAudioPath;
  final int? audioDurationMs;
  final int audioByteSize;

  final SyncState syncState;

  const Masterpiece({
    required this.id,
    required this.childId,
    this.relativeImagePath,
    required this.addedAt,
    this.drawnAt,
    this.story,
    this.displayImagePath,
    this.thumbnailImagePath,
    this.imageWidth,
    this.imageHeight,
    this.relativeAudioPath,
    this.audioDurationMs,
    this.audioByteSize = 0,
    this.syncState = SyncState.localOnly,
  });

  String? get bestDisplayImagePath =>
      displayImagePath ?? relativeImagePath ?? thumbnailImagePath;

  String? get bestThumbnailImagePath =>
      thumbnailImagePath ?? relativeImagePath ?? displayImagePath;

  bool get imageDownloadFailed => syncState == SyncState.downloadFailed;

  bool get hasAudio => audioDurationMs != null || relativeAudioPath != null;

  bool get isAudioLocal => relativeAudioPath != null;

  Masterpiece copyWith({
    String? id,
    String? childId,
    String? relativeImagePath,
    DateTime? addedAt,
    Object? drawnAt = _unset,
    Object? story = _unset,
    String? displayImagePath,
    String? thumbnailImagePath,
    int? imageWidth,
    int? imageHeight,
    Object? relativeAudioPath = _unset,
    Object? audioDurationMs = _unset,
    int? audioByteSize,
    SyncState? syncState,
  }) {
    return Masterpiece(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      relativeImagePath: relativeImagePath ?? this.relativeImagePath,
      addedAt: addedAt ?? this.addedAt,
      drawnAt: identical(drawnAt, _unset) ? this.drawnAt : drawnAt as DateTime?,
      story: identical(story, _unset) ? this.story : story as String?,
      displayImagePath: displayImagePath ?? this.displayImagePath,
      thumbnailImagePath: thumbnailImagePath ?? this.thumbnailImagePath,
      imageWidth: imageWidth ?? this.imageWidth,
      imageHeight: imageHeight ?? this.imageHeight,
      relativeAudioPath: identical(relativeAudioPath, _unset)
          ? this.relativeAudioPath
          : relativeAudioPath as String?,
      audioDurationMs: identical(audioDurationMs, _unset)
          ? this.audioDurationMs
          : audioDurationMs as int?,
      audioByteSize: audioByteSize ?? this.audioByteSize,
      syncState: syncState ?? this.syncState,
    );
  }
}
