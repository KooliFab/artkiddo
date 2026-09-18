import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../async_action.dart';
import '../../domain/action_result.dart';
import '../theme/app_tokens.dart';
import '../ui/error_presenter.dart';
import '../ui/state_block.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../gallery/gallery_providers.dart';
import '../../domain/child.dart';
import 'child_editor_controller.dart';
import 'child_editor_screen.dart';
import 'children_providers.dart';

enum ChildAction { viewArtworks, edit, delete }

/// Modal sheet (compact) / anchored menu (medium/expanded).
Future<void> showChildActionsSheet(
  BuildContext context,
  WidgetRef ref,
  Child child,
  int artworkCount,
) async {
  final width = MediaQuery.of(context).size.width;
  if (AppBreakpoints.isCompact(width)) {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) =>
          _ChildActionsSheet(child: child, artworkCount: artworkCount),
    );
    return;
  }

  // At medium/expanded, this anchors a context menu on the tapped
  // child row instead of the compact full-width sheet.
  final renderBox = context.findRenderObject() as RenderBox?;
  final overlayBox =
      Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (renderBox == null || overlayBox == null) return;
  final position = RelativeRect.fromRect(
    Rect.fromPoints(
      renderBox.localToGlobal(
        renderBox.size.topRight(Offset.zero),
        ancestor: overlayBox,
      ),
      renderBox.localToGlobal(
        renderBox.size.bottomRight(Offset.zero),
        ancestor: overlayBox,
      ),
    ),
    Offset.zero & overlayBox.size,
  );
  final l10n = AppLocalizations.of(context);
  final action = await showMenu<ChildAction>(
    context: context,
    position: position,
    items: [
      PopupMenuItem(
        value: ChildAction.viewArtworks,
        child: Text(l10n.childrenActionsViewArtworks),
      ),
      PopupMenuItem(
        value: ChildAction.edit,
        child: Text(l10n.childrenActionsEdit),
      ),
      PopupMenuItem(
        value: ChildAction.delete,
        child: Text(
          l10n.childrenActionsDelete,
          style: const TextStyle(
            fontFamily: AppTypography.family,
            color: AppColors.danger,
          ),
        ),
      ),
    ],
  );
  if (action == null || !context.mounted) return;
  await _performChildAction(context, ref, action, child, artworkCount);
}

/// Shared by the sheet's `ListTile`s and the anchored menu's
/// selection — the four actions in one place, so compact and
/// medium/expanded stay behaviourally identical.
Future<void> _performChildAction(
  BuildContext context,
  WidgetRef ref,
  ChildAction action,
  Child child,
  int artworkCount,
) async {
  switch (action) {
    case ChildAction.viewArtworks:
      ref.read(galleryFilterProvider.notifier).setFilter(OneChild(child.id));
      Navigator.of(
        context,
        rootNavigator: true,
      ).popUntil((route) => route.isFirst);
    case ChildAction.edit:
      final result = await pushChildEditor(
        context,
        ChildEditorArgs(
          childId: child.id,
          origin: ChildEditorOrigin.childrenList,
        ),
      );
      if (!context.mounted) return;
      // An edit never confirmed itself either.
      if (result is ActionSuccess<String>) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).childEditorUpdated),
          ),
        );
      }
    case ChildAction.delete:
      showDialog<void>(
        context: context,
        builder: (ctx) =>
            _DeleteChildDialog(child: child, artworkCount: artworkCount),
      );
  }
}

class _ChildActionsSheet extends ConsumerWidget {
  final Child child;
  final int artworkCount;

  const _ChildActionsSheet({required this.child, required this.artworkCount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    Future<void> act(ChildAction action) async {
      Navigator.of(context).pop();
      await _performChildAction(context, ref, action, child, artworkCount);
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s6,
          AppSpacing.s4,
          AppSpacing.s6,
          AppSpacing.s6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.s4),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.accentSurface,
                  child: Text(
                    child.name.isNotEmpty ? child.name[0].toUpperCase() : '?',
                    style: AppTypography.h3.copyWith(
                      color: AppColors.accentPressed,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(child.name, style: AppTypography.h3),
                      Text(
                        l10n.childrenRowSubtitle(child.birthDate, artworkCount),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),
            ListTile(
              contentPadding: EdgeInsets.zero,
              minVerticalPadding: 16,
              leading: const Icon(Icons.grid_view_outlined),
              title: Text(l10n.childrenActionsViewArtworks),
              onTap: () => act(ChildAction.viewArtworks),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              minVerticalPadding: 16,
              leading: const Icon(Icons.edit_outlined),
              title: Text(l10n.childrenActionsEdit),
              onTap: () => act(ChildAction.edit),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              minVerticalPadding: 16,
              leading: const Icon(
                Icons.delete_outline,
                color: AppColors.danger,
              ),
              title: Text(
                l10n.childrenActionsDelete,
                style: const TextStyle(
                  fontFamily: AppTypography.family,
                  color: AppColors.danger,
                ),
              ),
              onTap: () => act(ChildAction.delete),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteChildDialog extends ConsumerStatefulWidget {
  final Child child;
  final int artworkCount;
  const _DeleteChildDialog({required this.child, required this.artworkCount});

  @override
  ConsumerState<_DeleteChildDialog> createState() => _DeleteChildDialogState();
}

class _DeleteChildDialogState extends ConsumerState<_DeleteChildDialog> {
  AsyncAction _state = const ActionIdle();

  Future<void> _delete() async {
    if (_state.isBusy) return;
    setState(() => _state = const ActionBusy());
    final repo = ref.read(childrenRepositoryProvider);
    final result = await repo.delete(widget.child.id);
    if (!mounted) return;
    switch (result) {
      case ActionSuccess():
        // The filter-orphan reset (and its one-shot filter-reset
        // banner) is owned entirely by the gallery filter notifier,
        // which reacts to the children stream. Resetting the filter
        // here too would race ahead of that listener and starve it
        // of the "was this the active filter" signal it needs to
        // post the banner.
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).childrenDeleted(widget.child.name),
            ),
          ),
        );
      case ActionFailed(failure: final f):
        setState(() => _state = ActionError(f));
      case ActionCancelled():
        setState(() => _state = const ActionIdle());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final busy = _state.isBusy;

    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        title: Text(l10n.childrenDeleteTitle(widget.child.name)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.childrenDeleteBody(widget.artworkCount)),
            if (_state case ActionError(failure: final f)) ...[
              const SizedBox(height: AppSpacing.s3),
              StateBlock(
                intent: ErrorPresenter.intentFor(f),
                title: l10n.childrenDeleteError(widget.child.name),
                actionLabel: l10n.commonRetry,
                onAction: _delete,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: busy ? null : _delete,
            child: busy ? Text(l10n.commonDeleting) : Text(l10n.commonDelete),
          ),
        ],
      ),
    );
  }
}
