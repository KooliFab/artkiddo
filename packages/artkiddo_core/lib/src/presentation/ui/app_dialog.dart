import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../theme/app_tokens.dart';

/// The dismissive action of a dialog: a neutral text button placed first,
/// on the left of [DialogConfirmButton] (Material and Apple HIG order).
///
/// Neutral ink rather than accent, so the way out never competes with the
/// action the dialog is asking about.
class DialogCancelButton extends StatelessWidget {
  final VoidCallback? onPressed;

  /// Defaults to the common "Cancel" label.
  final String? label;

  const DialogCancelButton({super.key, required this.onPressed, this.label});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(foregroundColor: AppColors.ink),
      child: Text(label ?? AppLocalizations.of(context).commonCancel),
    );
  }
}

/// The affirmative action of a dialog: filled, placed last.
///
/// A [destructive] confirmation is filled in danger red so it never reads
/// as the safe choice. While [busy] it stays filled, shows a spinner and
/// ignores taps, so the dialog cannot be confirmed twice.
class DialogConfirmButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool destructive;
  final bool busy;

  const DialogConfirmButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.destructive = false,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final background = destructive ? AppColors.danger : AppColors.accent;
    return FilledButton(
      onPressed: busy ? () {} : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: AppColors.onAccent,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
      ),
      child: busy
          ? Semantics(
              liveRegion: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.onAccent,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s2),
                  Text(label),
                ],
              ),
            )
          : Text(label),
    );
  }
}

/// A two-button confirmation: cancel on the left, [confirmLabel] on the
/// right. Resolves to `true` only when the user confirmed; dismissing the
/// dialog any other way counts as cancel.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? body,
  required String confirmLabel,
  String? cancelLabel,
  bool destructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: body == null ? null : Text(body),
      actions: [
        DialogCancelButton(
          label: cancelLabel,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        DialogConfirmButton(
          label: confirmLabel,
          destructive: destructive,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
