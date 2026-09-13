import 'package:flutter/material.dart';

import '../async_action.dart';
import '../theme/app_tokens.dart';

enum AppButtonVariant { primary, secondary, tertiary, share, destructive }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final String? disabledReason;
  final bool fullWidth;
  final IconData? icon;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.disabledReason,
    this.fullWidth = false,
    this.icon,
  });

  bool get _isTextLike =>
      variant == AppButtonVariant.tertiary ||
      variant == AppButtonVariant.destructive;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final button = _buildButton(disabled);
    final sized = fullWidth
        ? SizedBox(width: double.infinity, child: button)
        : button;

    if (!disabled || disabledReason == null) return sized;

    return Column(
      crossAxisAlignment: fullWidth
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        sized,
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.s1),
          child: Text(
            disabledReason!,
            style: AppTypography.caption.copyWith(color: AppColors.inkMuted),
          ),
        ),
      ],
    );
  }

  Widget _buildButton(bool disabled) {
    final height = _isTextLike ? 48.0 : 52.0;
    final foreground = switch (variant) {
      AppButtonVariant.primary => AppColors.onAccent,
      AppButtonVariant.secondary => AppColors.ink,
      AppButtonVariant.tertiary => AppColors.accent,
      AppButtonVariant.share => AppColors.onAccent,
      AppButtonVariant.destructive => AppColors.danger,
    };
    final background = switch (variant) {
      AppButtonVariant.primary => AppColors.accent,
      AppButtonVariant.secondary => AppColors.surface,
      AppButtonVariant.share => AppColors.share,
      _ => Colors.transparent,
    };
    final side = variant == AppButtonVariant.secondary
        ? const BorderSide(color: AppColors.borderStrong, width: 1)
        : BorderSide.none;

    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(kMinTapTarget, height)),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: _isTextLike ? 12 : 24),
      ),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return AppColors.disabledBg;
        if (states.contains(WidgetState.pressed)) {
          return switch (variant) {
            AppButtonVariant.primary => AppColors.accentPressed,
            AppButtonVariant.share => AppColors.sharePressed,
            _ => AppColors.accentSurface,
          };
        }
        return background;
      }),
      elevation: const WidgetStatePropertyAll(0),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return Colors.transparent;
        return switch (variant) {
          AppButtonVariant.primary => AppColors.accentPressed.withValues(
            alpha: 0.16,
          ),
          AppButtonVariant.share => AppColors.sharePressed.withValues(
            alpha: 0.18,
          ),
          _ => AppColors.accent.withValues(alpha: 0.08),
        };
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return AppColors.inkDisabled;
        return foreground;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return const BorderSide(color: AppColors.border, width: 1);
        }
        return side;
      }),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
      ),
      textStyle: WidgetStatePropertyAll(AppTypography.button),
      splashFactory: NoSplash.splashFactory,
    );

    final content = icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: AppSpacing.s2),
              Text(label),
            ],
          );

    return ElevatedButton(
      onPressed: disabled ? null : onPressed,
      style: style,
      child: content,
    );
  }
}

class AsyncActionButton extends StatelessWidget {
  final AsyncAction action;
  final String idleLabel;
  final String busyLabel;
  final VoidCallback onPressed;
  final AppButtonVariant variant;
  final String? disabledReason;
  final bool fullWidth;
  final bool enabled;

  const AsyncActionButton({
    super.key,
    required this.action,
    required this.idleLabel,
    required this.busyLabel,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.disabledReason,
    this.fullWidth = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final busy = action.isBusy;

    if (busy) {
      final height =
          variant == AppButtonVariant.tertiary ||
              variant == AppButtonVariant.destructive
          ? 48.0
          : 52.0;
      final busyBackground = variant == AppButtonVariant.share
          ? AppColors.share
          : AppColors.accent;
      final busyForeground = AppColors.onAccent;
      final content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: busyForeground,
            ),
          ),
          const SizedBox(width: AppSpacing.s2),
          Text(busyLabel),
        ],
      );
      return Semantics(
        liveRegion: true,
        child: SizedBox(
          width: fullWidth ? double.infinity : null,
          height: height,
          child: ElevatedButton(
            onPressed: () {}, // focusable but inert while busy — no double-tap.
            style: ElevatedButton.styleFrom(
              backgroundColor: busyBackground,
              foregroundColor: busyForeground,
              elevation: 0,
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              textStyle: AppTypography.button,
            ),
            child: content,
          ),
        ),
      );
    }

    return AppButton(
      label: idleLabel,
      onPressed: enabled ? onPressed : null,
      variant: variant,
      disabledReason: enabled ? null : disabledReason,
      fullWidth: fullWidth,
    );
  }
}
