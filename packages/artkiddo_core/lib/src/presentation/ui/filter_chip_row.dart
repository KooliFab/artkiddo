import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

class FilterChipItem {
  final String id; // null-id sentinel handled by caller ("" for "all")
  final String label;
  final bool selected;

  const FilterChipItem({
    required this.id,
    required this.label,
    required this.selected,
  });
}

class AppFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const AppFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.full),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: kMinTapTarget),
            child: Center(
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
                decoration: BoxDecoration(
                  color: selected ? AppColors.accentSurface : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.full),
                  border: Border.all(
                    color: selected ? AppColors.accent : AppColors.border,
                    width: selected ? 1 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: AppTypography.label.copyWith(
                        color: selected
                            ? AppColors.accentPressed
                            : AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
