import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../async_action.dart';
import '../theme/app_tokens.dart';
import '../ui/app_button.dart';
import '../ui/state_block.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../local/repositories/trash_repository.dart';
import 'trash_controller.dart';

/// Trash screen displaying recoverable deleted items and purge actions.
class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(trashControllerProvider);

    // Restore and purge are single, list-wide AsyncActions. Failures
    // are surfaced as SnackBars rather than attributed to one row's
    // inline banner, which would need per-row action state this screen
    // does not carry.
    ref.listen(trashControllerProvider, (previous, next) {
      final wasRestoreError = previous?.restore is ActionError;
      final wasPurgeError = previous?.purge is ActionError;
      final wasPurgeAllError = previous?.purgeAll is ActionError;
      if (!wasRestoreError && next.restore is ActionError) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.trashRestoreError)));
      }
      if (!wasPurgeError && next.purge is ActionError) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.trashPurgeError)));
      }
      if (!wasPurgeAllError && next.purgeAll is ActionError) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.trashPurgeAllError)));
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.trashTitle),
        actions: [
          if (state.isParent && state.items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: l10n.trashPurgeAll,
              onPressed: state.purgeAll.isBusy
                  ? null
                  : () => _confirmPurgeAll(context, ref, l10n),
            ),
        ],
      ),
      body: SafeArea(child: _buildBody(context, ref, l10n, state)),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    TrashState state,
  ) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s4),
          child: StateBlock(
            intent: StateBlockIntent.error,
            title: l10n.trashErrorTitle,
            actionLabel: l10n.commonRetry,
            onAction: () =>
                ref.read(trashControllerProvider.notifier).refresh(),
          ),
        ),
      );
    }

    if (state.items.isEmpty) {
      return EmptyStateView(
        icon: Icons.delete_outline,
        title: l10n.trashEmptyTitle,
        body: l10n.trashEmptyBody,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s4,
        AppSpacing.s2,
        AppSpacing.s4,
        96,
      ),
      itemCount: state.items.length,
      separatorBuilder: (context, i) => const SizedBox(height: AppSpacing.s3),
      itemBuilder: (context, index) =>
          _TrashRow(item: state.items[index], isParent: state.isParent),
    );
  }

  void _confirmPurgeAll(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _PurgeAllDialog(l10n: l10n),
    );
  }
}

class _TrashRow extends ConsumerWidget {
  final TrashedArtwork item;
  final bool isParent;
  const _TrashRow({required this.item, required this.isParent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(trashControllerProvider);
    final restoring = state.restore.isBusy && state.busyItemId == item.id;
    final purging = state.purge.isBusy && state.busyItemId == item.id;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.childName, style: AppTypography.body),
          const SizedBox(height: AppSpacing.s1),
          Text(
            l10n.trashItemDeletedOn(item.deletedAt),
            style: AppTypography.caption.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: AppSpacing.s1),
          // Every trashed item shows its own countdown — the condition
          // placing automatic purge as defensible, not optional decoration.
          Text(
            l10n.trashItemPurgeOn(item.purgeAt),
            style: AppTypography.caption.copyWith(color: AppColors.danger),
          ),
          if (isParent) ...[
            const SizedBox(height: AppSpacing.s2),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: restoring ? l10n.trashRestoring : l10n.trashRestore,
                    variant: AppButtonVariant.secondary,
                    onPressed: (restoring || purging)
                        ? null
                        : () => ref
                              .read(trashControllerProvider.notifier)
                              .restore(item.id),
                  ),
                ),
                const SizedBox(width: AppSpacing.s2),
                Expanded(
                  child: AppButton(
                    label: purging ? l10n.trashPurging : l10n.trashPurge,
                    variant: AppButtonVariant.destructive,
                    onPressed: (restoring || purging)
                        ? null
                        : () => _confirmPurge(context, ref, l10n, item.id),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _confirmPurge(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    String masterpieceId,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _PurgeDialog(l10n: l10n, masterpieceId: masterpieceId),
    );
  }
}

class _PurgeDialog extends ConsumerWidget {
  final AppLocalizations l10n;
  final String masterpieceId;
  const _PurgeDialog({required this.l10n, required this.masterpieceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      title: Text(l10n.trashPurgeConfirmTitle),
      content: Text(l10n.trashPurgeConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          onPressed: () {
            Navigator.of(context).pop();
            ref.read(trashControllerProvider.notifier).purge(masterpieceId);
          },
          child: Text(l10n.trashPurge),
        ),
      ],
    );
  }
}

class _PurgeAllDialog extends ConsumerWidget {
  final AppLocalizations l10n;
  const _PurgeAllDialog({required this.l10n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(trashControllerProvider);
    final busy = state.purgeAll.isBusy;

    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        title: Text(l10n.trashPurgeAllConfirmTitle),
        content: Text(l10n.trashPurgeAllConfirmBody),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: busy
                ? null
                : () async {
                    await ref.read(trashControllerProvider.notifier).purgeAll();
                    if (context.mounted) Navigator.of(context).pop();
                  },
            child: Text(l10n.trashPurgeAll),
          ),
        ],
      ),
    );
  }
}
