import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../theme/app_tokens.dart';

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
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        title: Text(title ?? l10n.commonDiscardTitle),
        content: Text(body ?? l10n.commonDiscardBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonContinueEditing),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.commonDiscard),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
