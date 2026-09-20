import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

enum StateBlockIntent { info, help, warning, error, success }

/// A single component declined into multiple intentions.
/// An `error` block always shows: what failed, what did not change, and the
/// exit action — never a raw technical message.
class StateBlock extends StatelessWidget {
  final StateBlockIntent intent;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const StateBlock({
    super.key,
    required this.intent,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  ({Color surface, Color ink, IconData icon}) get _style => switch (intent) {
    StateBlockIntent.info => (
      surface: AppColors.sageSurface,
      ink: AppColors.sageInk,
      icon: Icons.info_outline,
    ),
    StateBlockIntent.help => (
      surface: AppColors.lavenderSurface,
      ink: AppColors.lavenderInk,
      icon: Icons.lightbulb_outline,
    ),
    StateBlockIntent.warning => (
      surface: AppColors.warningSurface,
      ink: AppColors.warning,
      icon: Icons.warning_amber_outlined,
    ),
    StateBlockIntent.error => (
      surface: AppColors.dangerSurface,
      ink: AppColors.danger,
      icon: Icons.error_outline,
    ),
    StateBlockIntent.success => (
      surface: AppColors.successSurface,
      ink: AppColors.success,
      icon: Icons.check_circle_outline,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final style = _style;
    final isError = intent == StateBlockIntent.error;

    return Semantics(
      liveRegion: isError,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s4),
        decoration: BoxDecoration(
          color: style.surface,
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(style.icon, size: 32, color: style.ink),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.h3.copyWith(color: style.ink),
                      ),
                      if (body != null) ...[
                        const SizedBox(height: AppSpacing.s1),
                        // No truncated text without the ability to read it elsewhere,
                        // and a StateBlock body is not one of the named exceptions.
                        // Let it wrap freely instead of clipping on large text scales.
                        Text(
                          body!,
                          style: AppTypography.body.copyWith(color: style.ink),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if ((actionLabel != null && onAction != null) ||
                (secondaryLabel != null && onSecondary != null)) ...[
              const SizedBox(height: AppSpacing.s3),
              Wrap(
                spacing: AppSpacing.s2,
                runSpacing: AppSpacing.s1,
                children: [
                  if (actionLabel != null && onAction != null)
                    TextButton(
                      onPressed: onAction,
                      style: TextButton.styleFrom(
                        foregroundColor: style.ink,
                        minimumSize: const Size(kMinTapTarget, kMinTapTarget),
                      ),
                      child: Text(
                        actionLabel!,
                        style: AppTypography.button.copyWith(color: style.ink),
                      ),
                    ),
                  if (secondaryLabel != null && onSecondary != null)
                    TextButton(
                      onPressed: onSecondary,
                      style: TextButton.styleFrom(
                        foregroundColor: style.ink,
                        minimumSize: const Size(kMinTapTarget, kMinTapTarget),
                      ),
                      child: Text(
                        secondaryLabel!,
                        style: AppTypography.button.copyWith(color: style.ink),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Full-page empty state view.
class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.surfaceSunken,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: AppColors.borderStrong),
            ),
            const SizedBox(height: AppSpacing.s5),
            Text(title, style: AppTypography.h2, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.s2),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                body,
                style: AppTypography.body.copyWith(color: AppColors.inkMuted),
                textAlign: TextAlign.center,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.s6),
              _PrimaryEmptyAction(label: actionLabel!, onPressed: onAction!),
            ],
            if (secondaryLabel != null && onSecondary != null) ...[
              const SizedBox(height: AppSpacing.s2),
              TextButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _PrimaryEmptyAction extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _PrimaryEmptyAction({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.onAccent,
        minimumSize: const Size(kMinTapTarget, 52),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        textStyle: AppTypography.button,
      ),
      child: Text(label),
    );
  }
}

/// Offline banner shown on network-dependent surfaces.
class OfflineBanner extends StatelessWidget {
  final String label;
  const OfflineBanner({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 44,
      color: AppColors.warningSurface,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, size: 18, color: AppColors.warning),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: Text(
              label,
              style: AppTypography.label.copyWith(color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }
}
