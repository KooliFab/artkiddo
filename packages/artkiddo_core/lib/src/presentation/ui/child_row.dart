import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// A single tap target for the whole child row; opens child actions.
/// No competing icons.
class ChildRow extends StatelessWidget {
  final String name;
  final String subtitle;
  final VoidCallback onTap;

  /// Index into [AppChildColors]; see `childColorIndexes`.
  final int colorIndex;

  const ChildRow({
    super.key,
    required this.name,
    required this.subtitle,
    required this.onTap,
    this.colorIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: AppShadows.sm,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s4,
            vertical: AppSpacing.s3,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: AppSizes.avatar / 2,
                backgroundColor: AppChildColors.surface(colorIndex),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: AppTypography.h3.copyWith(
                    color: AppChildColors.ink(colorIndex),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTypography.h3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}
