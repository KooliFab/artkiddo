part of 'gallery_screen.dart';

class _ArtworkPeekOverlay extends StatefulWidget {
  final ArtworkTile tile;
  final File previewFile;
  final VoidCallback onDismiss;

  const _ArtworkPeekOverlay({
    super.key,
    required this.tile,
    required this.previewFile,
    required this.onDismiss,
  });

  @override
  State<_ArtworkPeekOverlay> createState() => _ArtworkPeekOverlayState();
}

class _ArtworkPeekOverlayState extends State<_ArtworkPeekOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.standard,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.88,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: AppMotion.curve));
    _controller.forward();
  }

  void dismiss(VoidCallback onDone) {
    if (!mounted) {
      onDone();
      return;
    }
    _controller.reverse().then((_) {
      if (mounted) onDone();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final maxWidth = math.min(size.width * 0.88, 480.0);
    final maxHeight = size.height * 0.72;

    return Material(
      color: Colors.transparent,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onDismiss,
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(color: AppColors.peekScrim),
                ),
              ),
            ),
          ),
          ScaleTransition(
            scale: _scaleAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: maxWidth,
                    maxHeight: maxHeight,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PeekHeader(tile: widget.tile),
                      const SizedBox(height: AppSpacing.s3),
                      Flexible(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadii.lg),
                            boxShadow: AppShadows.peekCard,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: AspectRatio(
                            aspectRatio: widget.tile.aspectRatio.clamp(
                              0.55,
                              1.8,
                            ),
                            child: widget.tile.imageExists
                                ? Image.file(
                                    widget.previewFile,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const Center(
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        size: 40,
                                        color: AppColors.inkMuted,
                                      ),
                                    ),
                                  )
                                : const ColoredBox(
                                    color: AppColors.surfaceSunken,
                                    child: Center(
                                      child: Icon(
                                        Icons.image_not_supported_outlined,
                                        color: AppColors.inkMuted,
                                        size: 40,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      if (widget.tile.hasAudio) ...[
                        const SizedBox(height: AppSpacing.s3),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s4,
                            vertical: AppSpacing.s2 + 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadii.full),
                            boxShadow: AppShadows.peekPill,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const _AudioPulsingWaves(),
                              const SizedBox(width: AppSpacing.s2 + 2),
                              Text(
                                widget.tile.childName.isNotEmpty
                                    ? AppLocalizations.of(
                                        context,
                                      ).galleryPeekVoiceOf(
                                        widget.tile.childName,
                                      )
                                    : AppLocalizations.of(
                                        context,
                                      ).galleryPeekListening,
                                style: AppTypography.bodyStrong.copyWith(
                                  color: AppColors.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (widget.tile.story != null &&
                          widget.tile.story!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.s2),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s4,
                          ),
                          child: Text(
                            '« ${widget.tile.story} »',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: AppTypography.body.copyWith(
                              color: AppColors.onImmersive.withValues(
                                alpha: 0.92,
                              ),
                              fontStyle: FontStyle.italic,
                              shadows: AppShadows.textOnImageStrong,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// When and by whom, above the peeked artwork: the two facts a parent
/// looks for first, readable on the blurred backdrop without opening it.
class _PeekHeader extends StatelessWidget {
  final ArtworkTile tile;
  const _PeekHeader({required this.tile});

  static const _shadows = AppShadows.textOnImage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final drawnAt = tile.drawnAt;
    // Say which date this is (CONTEXT.md invariant 3): the parent-supplied
    // drawing date, or only the day it was added.
    final date = drawnAt != null
        ? l10n.artworkDrawnOn(drawnAt)
        : l10n.artworkAddedOn(tile.addedAt);
    final artist = [
      if (tile.childName.isNotEmpty) tile.childName,
      if (tile.age.isNotEmpty) tile.age,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            date,
            textAlign: TextAlign.center,
            style: AppTypography.h3.copyWith(
              color: AppColors.onImmersive,
              shadows: _shadows,
            ),
          ),
          if (artist.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s1),
            Text(
              artist,
              textAlign: TextAlign.center,
              style: AppTypography.bodyStrong.copyWith(
                color: AppColors.onImmersive.withValues(alpha: 0.88),
                shadows: _shadows,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
