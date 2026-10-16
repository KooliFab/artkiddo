part of 'gallery_screen.dart';

/// A read-only tile for an artwork of a followed household: network image,
/// audio marker, no backup badge and no peek (the peek plays local files).
class FollowedMosaicTile extends StatelessWidget {
  final FollowedArtwork artwork;
  const FollowedMosaicTile({super.key, required this.artwork});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final natural = FollowedFeedItem(artwork).aspectRatio;
    final ratio = MosaicArtworkTile.clampRatio(natural);
    final uri = artwork.thumbnailUri ?? artwork.imageUri;
    return Semantics(
      button: true,
      label: l10n.a11yFollowedGalleryCard(
        artwork.childName,
        followedFamilyLabel(l10n, artwork.familyName),
        artwork.drawnAt ?? artwork.addedAt,
      ),
      child: Hero(
        tag: FollowedArtworkScreen.heroTag(artwork.id),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.artwork),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => FollowedArtworkScreen(artwork: artwork),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.artwork),
              child: AspectRatio(
                aspectRatio: ratio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _NetworkTileImage(uri: uri, contain: ratio != natural),
                    if (artwork.hasAudio)
                      const Positioned(
                        right: AppSpacing.s2,
                        bottom: AppSpacing.s2,
                        child: ExcludeSemantics(child: _TileAudioBadge()),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NetworkTileImage extends StatelessWidget {
  final Uri? uri;
  final bool contain;
  const _NetworkTileImage({required this.uri, required this.contain});

  @override
  Widget build(BuildContext context) {
    const missing = ColoredBox(
      color: AppColors.surfaceSunken,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: AppColors.inkMuted,
        ),
      ),
    );
    final source = uri;
    if (source == null) return missing;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Decode at the tile's size, not the source's, to keep memory flat on
        // a long wall.
        final cacheWidth =
            (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context))
                .round();
        return ColoredBox(
          color: AppColors.surface,
          child: Image.network(
            source.toString(),
            fit: contain ? BoxFit.contain : BoxFit.cover,
            cacheWidth: cacheWidth > 0 ? cacheWidth : null,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const ColoredBox(color: AppColors.surfaceSunken),
            errorBuilder: (_, _, _) => missing,
          ),
        );
      },
    );
  }
}

/// End of the wall while followed households have more to load: a spinner,
/// or a retry when the last page failed.
class _FollowedFeedFooter extends ConsumerWidget {
  final double margin;
  const _FollowedFeedFooter({required this.margin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final feed = ref.watch(followedFeedProvider);
    if (feed.hasError && !feed.hasValue) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: margin),
        child: StateBlock(
          intent: StateBlockIntent.warning,
          title: l10n.galleryFollowedLoadFailed,
          actionLabel: l10n.commonRetry,
          onAction: () => ref.read(followedFeedProvider.notifier).refresh(),
        ),
      );
    }
    final state = feed.value;
    if (state == null || !state.hasMore) return const SizedBox.shrink();
    if (state.loadMoreFailed) {
      return Center(
        child: TextButton(
          onPressed: () => ref.read(followedFeedProvider.notifier).loadMore(),
          child: Text(l10n.galleryFollowedLoadMoreRetry),
        ),
      );
    }
    return const Center(child: CircularProgressIndicator());
  }
}
