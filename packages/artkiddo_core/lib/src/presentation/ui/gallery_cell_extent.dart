import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

double galleryCellExtent(double columnWidth, double textScale) {
  final imageHeight = columnWidth * 4 / 3;

  const cardPadding =
      AppSpacing.s3 * 2; // rembourrage haut + bas, non mis à l'échelle
  final textWidth = columnWidth - AppSpacing.s3 * 2;
  final scaler = TextScaler.linear(textScale);

  double measure(TextStyle style, int maxLines) {
    final painter = TextPainter(
      text: TextSpan(text: 'Hg' * 40, style: style),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      textScaler: scaler,
    )..layout(maxWidth: textWidth);
    return painter.height;
  }

  const badgePadding = 2.0 * 2;
  final nameAndBadge =
      measure(AppTypography.bodyStrong, 2) +
      AppSpacing.s1 * textScale +
      measure(AppTypography.label, 2) +
      badgePadding * textScale;
  final storyBlock = measure(AppTypography.caption, 2);
  final dateBlock = measure(AppTypography.caption, 2);
  final spacing = AppSpacing.s1 * 2 * textScale;

  return imageHeight +
      cardPadding +
      nameAndBadge +
      storyBlock +
      dateBlock +
      spacing;
}
