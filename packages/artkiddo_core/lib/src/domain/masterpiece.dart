import 'child.dart';

/// Sentinel used by [Masterpiece.copyWith] to distinguish an omitted
/// argument from an explicit `null`. Not exported.
const Object _unset = Object();

class Masterpiece {
  final String id; // UUIDv4
  final String childId;

  /// Path inside the local vault to the untouched original.
  /// **Nullable**: non-null for every masterpiece captured on this
  /// device; null for one known only through `pull` — the original
  /// never leaves the device that captured it, so a restored/converged
  /// row has no original to point to here, only whatever derivatives
  /// have been downloaded (see [displayImagePath]/[thumbnailImagePath]).
  final String? relativeImagePath;

  /// Instant the parent added the artwork to the app. Technical, posed
  /// by the system, **never modifiable**. Used for insertion order.
  final DateTime addedAt;

  /// Date the child actually created the artwork, told by the parent
  /// from the artwork detail screen. **Nullable**: absence ("I don't
  /// know") is a valid, permanent answer, not a gap to fill later. The
  /// age is computed on this date when present, on [addedAt] only as a
  /// fallback.
  final DateTime? drawnAt;

  final String? story; // Anecdote told by child; null = no anecdote

  /// Bounded-dimension derivative (max 1600px on the long side) for the
  /// artwork detail screen. `null` until generated, or if generation
  /// failed — a cache, never a data column of record: use
  /// [bestDisplayImagePath] rather than reading this field directly.
  final String? displayImagePath;

  /// Bounded-dimension derivative (max 640px) for the gallery grid.
  /// Same nullability contract as [displayImagePath]; use
  /// [bestThumbnailImagePath].
  final String? thumbnailImagePath;

  /// Dimensions recorded at capture time so the gallery masonry can
  /// reserve the final geometry before decoding the visible image.
  final int? imageWidth;
  final int? imageHeight;

  /// Optional child voice note (recorded story) attached to the
  /// masterpiece.
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

  /// The image to show at "display" fidelity (artwork detail screen)
  /// — the derivative when one exists, the untouched original
  /// otherwise, the thumbnail as a last resort (a converged row whose
  /// display derivative has not been fetched yet). **Nullable**: `null`
  /// only when nothing at all is available locally yet — a
  /// freshly-pulled row before even its thumbnail has downloaded.
  /// Callers must treat `null` as "pending", never as an error, and
  /// never render an empty tile for it.
  String? get bestDisplayImagePath =>
      displayImagePath ?? relativeImagePath ?? thumbnailImagePath;

  /// Same fallback as [bestDisplayImagePath], sized for the gallery
  /// grid.
  String? get bestThumbnailImagePath =>
      thumbnailImagePath ?? relativeImagePath ?? displayImagePath;

  /// True once every image this masterpiece will ever have on this
  /// device (original, display, or thumbnail) is definitively absent
  /// and not pending — i.e. [syncState] is [SyncState.downloadFailed].
  /// Used by the gallery to distinguish "still downloading" (show a
  /// pending tile) from "gave up" (show a retry affordance) — both
  /// cases already fall back to the same "no path yet" state, `null`,
  /// from [bestThumbnailImagePath].
  bool get imageDownloadFailed => syncState == SyncState.downloadFailed;

  /// True if this masterpiece has an audio story attached (either
  /// locally or remotely).
  bool get hasAudio => audioDurationMs != null || relativeAudioPath != null;

  /// True if the audio recording is stored locally on this device.
  bool get isAudioLocal => relativeAudioPath != null;

  /// `drawnAt`, `story`, `relativeAudioPath` and `audioDurationMs`
  /// follow the sentinel contract: omitted → kept as-is, `null` →
  /// cleared, a value → replaced. `addedAt` has no such sentinel — it
  /// is never cleared, only ever kept or replaced wholesale, matching
  /// its "never modifiable" contract.
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
