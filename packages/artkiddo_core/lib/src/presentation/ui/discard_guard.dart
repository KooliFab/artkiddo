import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import 'app_dialog.dart';

/// Intercepts Back/Close on a dirty form and only lets the positive answer
/// through the dialog "Discard changes?".
///
/// Used by capture, child editor and story editing.
class DiscardGuard extends StatelessWidget {
  final bool isDirty;
  final Widget child;
  final String? title;
  final String? body;

  const DiscardGuard({
    super.key,
    required this.isDirty,
    required this.child,
    this.title,
    this.body,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !isDirty) return;
        final confirmed = await confirmDiscard(
          context,
          title: title,
          body: body,
        );
        if (confirmed && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: child,
    );
  }

  static Future<bool> confirmDiscard(
    BuildContext context, {
    String? title,
    String? body,
  }) async {
    final l10n = AppLocalizations.of(context);
    return showConfirmDialog(
      context,
      title: title ?? l10n.commonDiscardTitle,
      body: body ?? l10n.commonDiscardBody,
      cancelLabel: l10n.commonContinueEditing,
      confirmLabel: l10n.commonDiscard,
      destructive: true,
    );
  }
}
