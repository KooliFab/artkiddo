import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as image;

import '../config/app_capabilities.dart';
import '../locale/locale_provider.dart';
import '../providers/core_providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../ui/formatters.dart';
import '../../domain/child.dart';
import '../children/children_providers.dart';
import '../../local/repositories/artworks_repository.dart';
import '../../domain/artwork.dart';

final artworksRepositoryProvider = Provider<ArtworksRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final vault = ref.watch(localVaultProvider);
  final capabilities = ref.watch(appCapabilitiesProvider);
  return DriftArtworksRepository(
    db,
    vault,
    deletionStrategy: capabilities.trash == TrashCapability.local
        ? ArtworkDeletionStrategy.localRecoverable
        : ArtworkDeletionStrategy.remoteTombstone,
  );
});

/// `keepAlive`, not persisted between launches: at startup the filter
/// is always `all`.
sealed class GalleryFilter {
  const GalleryFilter();

  String get scrollKey;
}

class AllChildren extends GalleryFilter {
  const AllChildren();

  @override
  String get scrollKey => 'all';

  @override
  bool operator ==(Object other) => other is AllChildren;
  @override
  int get hashCode => 0;
}

class OneChild extends GalleryFilter {
  final String childId;
  const OneChild(this.childId);

  @override
  String get scrollKey => 'child:$childId';

  @override
  bool operator ==(Object other) =>
      other is OneChild && other.childId == childId;
  @override
  int get hashCode => childId.hashCode;
}

class GalleryFilterNotifier extends Notifier<GalleryFilter> {
  @override
  GalleryFilter build() {
    ref.listen(allChildrenStreamProvider, (previous, next) {
      final children = next.value;
      if (children == null) return;
      final current = state;
      if (current is OneChild &&
          !children.any((c) => c.id == current.childId)) {
        final removedName = _lastKnownName(current.childId, previous?.value);
        state = const AllChildren();
        // Post the one-shot filter-reset banner through its own provider
        // (reactive via `watch`), instead of a plain field that the view
        // had to "consume" mid-build — which cleared it before the next
        // frame could render it.
        ref
            .read(galleryFilterResetBannerProvider.notifier)
            .show(removedName ?? '');
      }
    });
    return const AllChildren();
  }

  String? _lastKnownName(String childId, List<Child>? previous) {
    if (previous == null) return null;
    for (final c in previous) {
      if (c.id == childId) return c.name;
    }
    return null;
  }

  void setFilter(GalleryFilter filter) => state = filter;
}

final galleryFilterProvider =
    NotifierProvider<GalleryFilterNotifier, GalleryFilter>(
      GalleryFilterNotifier.new,
    );

/// One-shot `filterReset` banner: shown once when the filtered child
/// is deleted, dismissed explicitly by the user or by switching the
/// filter — never consumed as a side effect of a `build()`.
class GalleryFilterResetBannerNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void show(String childName) => state = childName;

  void clear() => state = null;
}

final galleryFilterResetBannerProvider =
    NotifierProvider<GalleryFilterResetBannerNotifier, String?>(
      GalleryFilterResetBannerNotifier.new,
    );

/// In-memory per-filter scroll offsets, reset at launch.
class GalleryScrollOffsets {
  final Map<String, double> _offsets = {};

  double read(String key) => _offsets[key] ?? 0;
  void write(String key, double value) => _offsets[key] = value;
}

final galleryScrollOffsetsProvider = Provider<GalleryScrollOffsets>(
  (ref) => GalleryScrollOffsets(),
);

/// Presentation-level artwork tile — distinct from the persisted
/// [Artwork] entity. Path resolution and existence check happen
/// once per batch here, not per-card.
class ArtworkTile {
  /// The already-resolved row lets the destination mount its matching
  /// Hero in the first route frame, rather than waiting for a second
  /// database read.
  final Artwork artwork;
  final String artworkId;
  final String childId;
  final String childName;
  final File imageFile;
  final bool imageExists;
  final DateTime addedAt;

  /// Date the child actually drew the artwork, if the parent set it.
  /// The card shows this preferentially, and the age is computed on
  /// the same basis: otherwise the same artwork would show two
  /// different ages depending on the screen.
  final DateTime? drawnAt;
  final String age;
  final String? story;
  final double aspectRatio;

  const ArtworkTile({
    required this.artwork,
    required this.artworkId,
    required this.childId,
    required this.childName,
    required this.imageFile,
    required this.imageExists,
    required this.addedAt,
    required this.drawnAt,
    required this.age,
    required this.story,
    required this.aspectRatio,
  });

  bool get hasAudio => artwork.hasAudio;
}

/// Keeps the gallery stable while images load. Ratios are computed
/// from the local thumbnail once, then reused for the lifetime of the
/// application. Remote or unreadable files deliberately fall back to
/// a square tile.
class ImageAspectRatioCache {
  final Map<String, double> _ratios = {};

  Future<double> forFile(File file, {required bool exists}) async {
    if (!exists || file.path.isEmpty) return 1;
    final cached = _ratios[file.path];
    if (cached != null) return cached;
    try {
      final decoded = image.decodeImage(await file.readAsBytes());
      if (decoded == null || decoded.height == 0) return 1;
      final ratio = decoded.width / decoded.height;
      _ratios[file.path] = ratio;
      return ratio;
    } catch (_) {
      return 1;
    }
  }
}

final imageAspectRatioCacheProvider = Provider<ImageAspectRatioCache>(
  (ref) => ImageAspectRatioCache(),
);

class GalleryTilesState {
  final List<ArtworkTile> tiles;
  final int totalCount;
  const GalleryTilesState({required this.tiles, required this.totalCount});
}

/// Watches artworks for the current filter and joins them with
/// their child, resolving file paths and computing ages once per
/// emission.
final galleryTilesProvider = StreamProvider<GalleryTilesState>((ref) async* {
  final filter = ref.watch(galleryFilterProvider);
  final childId = switch (filter) {
    AllChildren() => null,
    OneChild(childId: final id) => id,
  };
  final repository = ref.watch(artworksRepositoryProvider);
  final vault = ref.watch(localVaultProvider);
  final aspectRatioCache = ref.watch(imageAspectRatioCacheProvider);
  final locale = ref.watch(effectiveLocaleProvider);
  final l10n = await AppLocalizations.delegate.load(locale);

  final childrenById = <String, Child>{};
  ref.listen(allChildrenStreamProvider, (previous, next) {
    final list = next.value;
    if (list == null) return;
    childrenById
      ..clear()
      ..addEntries(list.map((c) => MapEntry(c.id, c)));
  }, fireImmediately: true);

  await for (final artworks in repository.watch(childId: childId)) {
    final tiles = <ArtworkTile>[];
    for (final m in artworks) {
      final child = childrenById[m.childId];
      // The grid reads the thumbnail derivative, falling back to the
      // untouched original when no derivative has been generated yet
      // (fresh capture before the best-effort step ran, or a still-
      // pending backfill row) — `bestThumbnailImagePath` makes that
      // fallback the caller's only concern, not a per-screen `if`.
      // `null` (a row pulled from another member's device whose
      // thumbnail hasn't downloaded yet, or whose download failed)
      // reuses the exact same "missing image" tile the grid already
      // renders for a vanished local file — never an empty cell.
      final thumbnailPath = m.bestThumbnailImagePath;
      final file = thumbnailPath != null
          ? await vault.resolveFile(thumbnailPath)
          : File('');
      final exists = thumbnailPath != null && await file.exists();
      final aspectRatio =
          m.imageWidth != null && m.imageHeight != null && m.imageHeight! > 0
          ? m.imageWidth! / m.imageHeight!
          : await aspectRatioCache.forFile(file, exists: exists);
      tiles.add(
        ArtworkTile(
          artwork: m,
          artworkId: m.id,
          childId: m.childId,
          childName: child?.name ?? '',
          imageFile: file,
          imageExists: exists,
          addedAt: m.addedAt,
          drawnAt: m.drawnAt,
          age: child != null
              ? Formatters.age(
                  l10n,
                  birthDate: child.birthDate,
                  addedAt: m.addedAt,
                  drawnAt: m.drawnAt,
                )
              : '',
          story: m.story,
          aspectRatio: aspectRatio,
        ),
      );
    }
    yield GalleryTilesState(tiles: tiles, totalCount: tiles.length);
  }
});

/// Highlighted card id after a successful capture — consumed once by
/// `HighlightOnce`.
class HighlightNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void highlight(String id) => state = id;

  void clear() => state = null;
}

final highlightedArtworkProvider = NotifierProvider<HighlightNotifier, String?>(
  HighlightNotifier.new,
);
