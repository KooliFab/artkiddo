part of 'gallery_screen.dart';

class MosaicArtworkTile extends ConsumerStatefulWidget {
  final ArtworkTile tile;
  const MosaicArtworkTile({super.key, required this.tile});

  static const _minRatio = 0.60;
  static const _maxRatio = 1.70;

  /// The ratio a tile is displayed at. Extreme drawings are clamped (and
  /// shown uncropped inside that frame) so one panorama or scroll cannot
  /// dominate the wall. The feed's layout plan uses this same value.
  static double ratioOf(ArtworkTile tile) =>
      tile.aspectRatio.clamp(_minRatio, _maxRatio);

  @override
  ConsumerState<MosaicArtworkTile> createState() => _MosaicArtworkTileState();
}

class _MosaicArtworkTileState extends ConsumerState<MosaicArtworkTile> {
  OverlayEntry? _overlayEntry;
  final _peekKey = GlobalKey<_ArtworkPeekOverlayState>();
  bool _isPeeking = false;

  void _startPeek() async {
    if (_isPeeking) return;
    _isPeeking = true;
    HapticFeedback.mediumImpact();

    // Resolve display image file for a sharp zoom preview if already downloaded
    File previewFile = widget.tile.imageFile;
    final bestPath = widget.tile.artwork.bestDisplayImagePath;
    if (bestPath != null) {
      try {
        final vault = ref.read(localVaultProvider);
        final file = await vault.resolveFile(bestPath);
        if (file.existsSync()) {
          previewFile = file;
        }
      } catch (_) {}
    }

    if (!_isPeeking || !mounted) return;

    _overlayEntry?.remove();
    _overlayEntry = OverlayEntry(
      builder: (context) => _ArtworkPeekOverlay(
        key: _peekKey,
        tile: widget.tile,
        previewFile: previewFile,
        onDismiss: _endPeek,
      ),
    );

    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);

    if (widget.tile.hasAudio) {
      _startPeekAudio();
    }
  }

  Future<void> _startPeekAudio() async {
    try {
      final vault = ref.read(localVaultProvider);
      File? audioFile;
      final relPath = widget.tile.artwork.relativeAudioPath;
      if (relPath != null) {
        final f = await vault.resolveFile(relPath);
        if (f.existsSync()) {
          audioFile = f;
        }
      }

      if (audioFile == null &&
          !widget.tile.artwork.isAudioLocal &&
          widget.tile.artwork.hasAudio) {
        final fetcher = ref.read(remoteMediaFetcherProvider);
        await fetcher.ensureAudioDownloaded(widget.tile.artworkId);
        final repo = ref.read(artworksRepositoryProvider);
        final updated = await repo.getById(widget.tile.artworkId);
        if (updated?.relativeAudioPath != null) {
          final f = await vault.resolveFile(updated!.relativeAudioPath!);
          if (f.existsSync()) {
            audioFile = f;
          }
        }
      }

      if (_isPeeking && audioFile != null && audioFile.existsSync()) {
        final player = ref.read(audioPlayerServiceProvider);
        await player.setFilePath(audioFile.path);
        if (_isPeeking) {
          await player.play();
        }
      }
    } catch (e, st) {
      Log.e('Error loading peek audio', e, st, 'GalleryScreen');
    }
  }

  void _endPeek() {
    if (!_isPeeking) return;
    _isPeeking = false;

    try {
      final player = ref.read(audioPlayerServiceProvider);
      player.stop();
    } catch (_) {}

    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    if (_isPeeking) {
      _isPeeking = false;
      try {
        ref.read(audioPlayerServiceProvider).stop();
      } catch (_) {}
      _overlayEntry?.remove();
      _overlayEntry = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ratio = MosaicArtworkTile.ratioOf(widget.tile);
    final extreme = ratio != widget.tile.aspectRatio;
    final l10n = AppLocalizations.of(context);
    final date = widget.tile.drawnAt ?? widget.tile.addedAt;
    final label = widget.tile.story == null || widget.tile.story!.isEmpty
        ? l10n.a11yGalleryCard(widget.tile.childName, date, widget.tile.age)
        : l10n.a11yGalleryCardWithStory(
            widget.tile.childName,
            date,
            widget.tile.age,
            widget.tile.story!,
          );
    return Semantics(
      button: true,
      label: label,
      child: Hero(
        tag: 'artwork-${widget.tile.artworkId}',
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPressStart: (_) => _startPeek(),
            onLongPressEnd: (_) => _endPeek(),
            onLongPressCancel: () => _endPeek(),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.artwork),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ArtworkScreen(
                    artworkId: widget.tile.artworkId,
                    initialArtwork: widget.tile.artwork,
                    initialHeroFile: widget.tile.imageFile,
                  ),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.artwork),
                child: AspectRatio(
                  aspectRatio: ratio,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _TileImage(
                        file: widget.tile.imageFile,
                        exists: widget.tile.imageExists,
                        contain: extreme,
                      ),
                      if (widget.tile.hasAudio)
                        Positioned(
                          right: AppSpacing.s2,
                          bottom: AppSpacing.s2,
                          child: const ExcludeSemantics(
                            child: _TileAudioBadge(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AudioPulsingWaves extends StatefulWidget {
  const _AudioPulsingWaves();

  @override
  State<_AudioPulsingWaves> createState() => _AudioPulsingWavesState();
}

class _AudioPulsingWavesState extends State<_AudioPulsingWaves>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final v = _anim.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _bar(6 + 8 * v),
            const SizedBox(width: 3),
            _bar(14 - 8 * v),
            const SizedBox(width: 3),
            _bar(8 + 8 * (1 - v)),
            const SizedBox(width: 3),
            _bar(5 + 10 * v),
          ],
        );
      },
    );
  }

  Widget _bar(double height) {
    return Container(
      width: 3,
      height: height.clamp(4.0, 16.0),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _TileAudioBadge extends StatelessWidget {
  const _TileAudioBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: AppColors.overlay,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.surface.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: const Center(
        child: Icon(Icons.mic_rounded, size: 14, color: AppColors.surface),
      ),
    );
  }
}

class _TileImage extends StatelessWidget {
  final File file;
  final bool exists;
  final bool contain;
  const _TileImage({
    required this.file,
    required this.exists,
    required this.contain,
  });

  @override
  Widget build(BuildContext context) {
    if (!exists) {
      return const ColoredBox(
        color: AppColors.surfaceSunken,
        child: Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: AppColors.inkMuted,
          ),
        ),
      );
    }
    return ColoredBox(
      color: AppColors.surface,
      child: Image.file(
        file,
        fit: contain ? BoxFit.contain : BoxFit.cover,
        errorBuilder: (_, _, _) => const Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: AppColors.inkMuted,
          ),
        ),
      ),
    );
  }
}
