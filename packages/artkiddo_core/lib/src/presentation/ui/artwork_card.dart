import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Gallery artwork card. Decoding is capped (`cacheWidth`) by the
/// caller; this widget never requests a full resolution decode.
class ArtworkCard extends StatelessWidget {
  final String?
  childName; // null when the gallery filter already names the child
  final String ageLabel;
  final String dateLabel;
  final String? story;
  final File? imageFile;
  final bool imageExists;
  final int cacheWidth;
  final String semanticLabel;
  final String imageMissingLabel;
  final VoidCallback onTap;
  final bool hasAudio;

  const ArtworkCard({
    super.key,
    required this.childName,
    required this.ageLabel,
    required this.dateLabel,
    required this.story,
    required this.imageFile,
    required this.imageExists,
    required this.cacheWidth,
    required this.semanticLabel,
    required this.imageMissingLabel,
    required this.onTap,
    this.hasAudio = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: AppColors.border, width: 1),
              boxShadow: AppShadows.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadii.lg),
                  ),
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildImage(),
                        if (hasAudio)
                          Positioned(
                            right: AppSpacing.s2,
                            bottom: AppSpacing.s2,
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: AppColors.overlay,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.surface.withValues(
                                    alpha: 0.35,
                                  ),
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
                                child: Icon(
                                  Icons.mic_rounded,
                                  size: 14,
                                  color: AppColors.surface,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.s3),
                  child: LayoutBuilder(
                    builder: (context, constraints) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: AppSpacing.s2,
                          runSpacing: AppSpacing.s1,
                          children: [
                            // A cell height budget founded on the worst
                            // case only holds if the content respects
                            // the same bounds. Name and badge are
                            // therefore capped at two lines, like the
                            // story and the date; the full value stays
                            // readable on the artwork detail.
                            if (childName != null)
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: constraints.maxWidth,
                                ),
                                child: Text(
                                  childName!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.bodyStrong,
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.s2,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accentSurface,
                                borderRadius: BorderRadius.circular(
                                  AppRadii.sm,
                                ),
                              ),
                              child: Text(
                                ageLabel,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.label.copyWith(
                                  color: AppColors.accentPressed,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (story != null && story!.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.s1),
                          Text(
                            '« $story »',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.inkMuted,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.s1),
                        // Without a bound, the date wraps
                        // indefinitely at large text scale factors and
                        // breaks out of the cell budget. Two lines are
                        // enough for the longest form, and the date
                        // stays fully readable on the artwork detail.
                        Text(
                          dateLabel,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (!imageExists || imageFile == null) {
      return _imageMissing();
    }
    return Image.file(
      imageFile!,
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      errorBuilder: (context, error, stack) => _imageMissing(),
    );
  }

  // The missing-image state requires an icon *and* a label — a single
  // marker (the icon alone) is not enough.
  Widget _imageMissing() {
    return Container(
      color: AppColors.surfaceSunken,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.broken_image_outlined,
              size: 28,
              color: AppColors.inkMuted,
            ),
            const SizedBox(height: AppSpacing.s1),
            Text(
              imageMissingLabel,
              style: AppTypography.caption.copyWith(color: AppColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
