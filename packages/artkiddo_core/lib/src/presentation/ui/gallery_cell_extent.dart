import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Gallery grid cell height.
///
/// A fixed `childAspectRatio` can't honor the rule "image 3:4 plus a text
/// block of intrinsic height"; the cell overflowed on every tile. No
/// staggered-grid dependency is in scope, so every cell is sized on the
/// **worst case** of its content.
///
/// The first version of this budget was wrong twice. It computed the image
/// height as `width * 3/4`, when an `AspectRatio(3/4)` renders an image
/// **taller than it is wide** — `width * 4/3` — 100px short at a 173px
/// column. And it scaled guessed line heights, without accounting for the
/// font's real metrics or the number of lines.
///
/// Text heights are now **measured** with `TextPainter` rather than
/// estimated: it's the only way to guarantee the worst case is computed
/// accurately, which the "worst case" approach requires to be worth
/// anything. The three blocks are bounded to two lines, and the card
/// applies the same bounds, or the budget wouldn't hold.
double galleryCellExtent(double columnWidth, double textScale) {
  // `AspectRatio(3 / 4)`: width-to-height ratio, so portrait.
  final imageHeight = columnWidth * 4 / 3;

  const cardPadding = AppSpacing.s3 * 2; // top + bottom padding, not scaled
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

  // Name and age badge. The `Wrap` puts them on two lines as soon as the
  // name is shown next to a two-part age — the common case with the "all"
  // filter. The badge isn't plain text: it has its own typography and a
  // vertical padding of 2 on each side, which a budget computed on the
  // name's style alone left out. The badge is budgeted at two lines: a
  // long age ("11 years and 11 months") next to a long first name really
  // does wrap, which a single-line measurement missed.
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
