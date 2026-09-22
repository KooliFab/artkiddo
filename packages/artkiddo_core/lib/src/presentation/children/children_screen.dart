import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/action_result.dart';
import '../theme/app_tokens.dart';
import '../ui/child_row.dart';
import '../ui/state_block.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'child_actions_sheet.dart';
import 'child_editor_controller.dart';
import 'child_editor_screen.dart';
import 'children_providers.dart';

/// Children management screen.
class ChildrenScreen extends ConsumerWidget {
  const ChildrenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final childrenAsync = ref.watch(allChildrenStreamProvider);
    final countsAsync = ref.watch(artworkCountByChildProvider);

    return Scaffold(
      // No settings affordance here: this screen manages children. Settings
      // (language, about, trash, debug) are one tap from the gallery's own
      // app bar instead of being reachable only by first opening this list.
      appBar: AppBar(title: Text(l10n.childrenTitle)),
      body: SafeArea(
        child: childrenAsync.when(
          loading: () => ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.s4),
            itemCount: 3,
            itemBuilder: (context, i) => Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.s3),
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surfaceSunken,
                borderRadius: BorderRadius.circular(AppRadii.lg),
              ),
            ),
          ),
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s4),
              child: StateBlock(
                intent: StateBlockIntent.error,
                title: l10n.childrenErrorTitle,
                actionLabel: l10n.commonRetry,
                // Invalidate stream on retry so the query re-executes.
                onAction: () => ref.invalidate(allChildrenStreamProvider),
              ),
            ),
          ),
          data: (children) {
            if (children.isEmpty) {
              return EmptyStateView(
                icon: Icons.face_outlined,
                title: l10n.childrenEmptyTitle,
                body: l10n.childrenEmptyBody,
                actionLabel: l10n.childrenAdd,
                onAction: () => _openEditor(
                  context,
                  ref,
                  const ChildEditorArgs(origin: ChildEditorOrigin.childrenList),
                ),
              );
            }
            final counts = countsAsync.value ?? const {};
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s4,
                AppSpacing.s2,
                AppSpacing.s4,
                96,
              ),
              itemCount: children.length + 1,
              separatorBuilder: (context, i) =>
                  const SizedBox(height: AppSpacing.s3),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s1),
                    child: Text(
                      l10n.childrenHelp,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                  );
                }
                final child = children[index - 1];
                final count = counts[child.id] ?? 0;
                return ChildRow(
                  name: child.name,
                  subtitle: l10n.childrenRowSubtitle(child.birthDate, count),
                  onTap: () =>
                      showChildActionsSheet(context, ref, child, count),
                );
              },
            );
          },
        ),
      ),
      // Shown at every breakpoint. This used to be compact-only because the
      // shell's navigation rail hosted the "add" action at medium/expanded;
      // the shell is a single gallery surface now, so hiding it there left a
      // non-empty list with no way to add a child at all.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(
          context,
          ref,
          const ChildEditorArgs(origin: ChildEditorOrigin.childrenList),
        ),
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.onAccent,
        icon: const Icon(Icons.add),
        label: Text(l10n.childrenAdd),
      ),
    );
  }

  // Shows the confirmation banner required on successful creation/edit.
  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    ChildEditorArgs args,
  ) async {
    final l10n = AppLocalizations.of(context);
    final result = await pushChildEditor(context, args);
    if (!context.mounted) return;
    if (result is ActionSuccess<String>) {
      final children = ref.read(allChildrenStreamProvider).value ?? const [];
      final created = children.where((c) => c.id == result.value).firstOrNull;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.childEditorCreated(created?.name ?? ''))),
      );
    }
  }
}
