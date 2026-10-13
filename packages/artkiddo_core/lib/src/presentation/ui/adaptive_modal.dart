import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// How a modal opens on a compact (phone) width.
enum CompactPresentation {
  /// A modal bottom sheet, for short content or a quick choice.
  sheet,

  /// A full-screen page that slides up and closes with X, for a form.
  fullScreen,
}

/// Opens a one-off modal the same way everywhere: [compact] on a phone
/// width, a centered dialog at most [maxWidth] wide from
/// [AppBreakpoints.isCompact]'s threshold up.
///
/// One breakpoint and one dialog shape for every modal, rather than each
/// entry point choosing its own.
Future<T?> showAdaptiveModal<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  CompactPresentation compact = CompactPresentation.sheet,
  double maxWidth = 560,
  bool barrierDismissible = true,
}) {
  final size = MediaQuery.sizeOf(context);
  if (AppBreakpoints.isCompact(size.width)) {
    return switch (compact) {
      CompactPresentation.sheet => showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        builder: builder,
      ),
      CompactPresentation.fullScreen => Navigator.of(
        context,
      ).push<T>(MaterialPageRoute(fullscreenDialog: true, builder: builder)),
    };
  }
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: size.height * 0.88,
        ),
        child: builder(dialogContext),
      ),
    ),
  );
}
