import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../local/logging/log.dart';

import '../async_action.dart';
import '../navigation/composition_actions.dart';
import '../navigation/pending_intent.dart';
import '../providers/core_providers.dart';
import '../theme/app_tokens.dart';
import '../ui/app_button.dart';
import '../ui/error_presenter.dart';
import '../ui/state_block.dart';
import 'share_controller.dart';

/// `share` — modal sheet (compact) / dialog (>=600) — `screens.md` §10.
Future<void> showShareSheet(
  BuildContext context, {
  required String childId,
  required String childName,
  VoidCallback? sendImage,
}) {
  Log.d('📱 [ShareSheet] Opening', 'Navigation');
  final width = MediaQuery.of(context).size.width;
  final args = ShareArgs(
    childId: childId,
    childName: childName,
    sendImage: sendImage,
  );
  if (width >= 600) {
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: _ShareSheetContent(args: args),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ShareSheetContent(args: args),
  );
}

class _ShareSheetContent extends ConsumerWidget {
  final ShareArgs args;
  const _ShareSheetContent({required this.args});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final capabilities = ref.watch(appCapabilitiesProvider);
    if (!capabilities.webGalleryLinks) {
      return _buildLocalShare(context, l10n);
    }
    final state = ref.watch(shareControllerProvider(args));
    final controller = ref.read(shareControllerProvider(args).notifier);
    final creating = state.create.isBusy || state.backup.isBusy;
    final childName = state.resolvedChildName ?? args.childName;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s6,
          AppSpacing.s4,
          AppSpacing.s6,
          AppSpacing.s6,
        ),
        child: PopScope(
          canPop: !creating,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      l10n.shareTitle(childName),
                      style: AppTypography.h2,
                    ),
                  ),
                  if (!creating)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.s1),
              Text(
                l10n.shareWarning,
                style: AppTypography.body.copyWith(color: AppColors.inkMuted),
              ),
              const SizedBox(height: AppSpacing.s4),
              if (state.loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.s8),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                _buildBody(context, ref, l10n, state, controller, childName),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocalShare(BuildContext context, AppLocalizations l10n) {
    final sendImage = args.sendImage;
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.shareImageHeading, style: AppTypography.h2),
            const SizedBox(height: AppSpacing.s2),
            Text(
              l10n.shareImageBody,
              style: AppTypography.body.copyWith(color: AppColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.s4),
            AppButton(
              label: l10n.shareImageHeading,
              variant: AppButtonVariant.share,
              fullWidth: true,
              onPressed: sendImage == null
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      sendImage();
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    ShareState state,
    ShareController controller,
    String childName,
  ) {
    // The child having been deleted mid-flow is its own state, not a
    // silent empty list.
    if (state.step == ShareStep.childMissing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StateBlock(
            intent: StateBlockIntent.error,
            title: l10n.shareChildMissing,
            actionLabel: l10n.commonClose,
            onAction: () => Navigator.of(context).pop(),
          ),
        ],
      );
    }

    if (state.step == ShareStep.signedOut) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StateBlock(
            intent: StateBlockIntent.help,
            title: l10n.shareSignedOutTitle,
            body: l10n.shareSignedOutBody,
          ),
          const SizedBox(height: AppSpacing.s4),
          AppButton(
            label: l10n.shareSignedOutAction,
            fullWidth: true,
            onPressed: () {
              ref
                  .read(pendingIntentProvider.notifier)
                  .pose(ShareChildGalleryIntent(args.childId));
              Navigator.of(context).pop();
              ref.read(compositionActionsProvider).openAccount?.call(context);
            },
          ),
          // Only offered when share was opened from the artwork
          // detail for a specific piece.
          if (args.sendImage != null) ...[
            const SizedBox(height: AppSpacing.s2),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  args.sendImage!();
                },
                child: Text(l10n.shareSignedOutAlternative),
              ),
            ),
          ],
        ],
      );
    }

    // `choice` and `linkReady` both show the offline banner and the
    // "send this image" block — factored above the step-specific
    // content.
    final children = <Widget>[
      if (state.offline) ...[
        OfflineBanner(label: l10n.settingsOffline),
        const SizedBox(height: AppSpacing.s3),
      ],
    ];

    if (!state.childHasSyncedArtworks && state.step == ShareStep.choice) {
      if (state.backup case ActionError(failure: final failure)) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s3),
            child: StateBlock(
              intent: ErrorPresenter.intentFor(failure),
              title: ErrorPresenter.present(l10n, failure).title,
              body: l10n.settingsBackupFailed,
            ),
          ),
        );
      }
      children.add(
        StateBlock(
          intent: StateBlockIntent.warning,
          title: l10n.shareNotSyncedTitle(childName),
          body: l10n.shareNotSyncedBody,
          actionLabel: l10n.shareNotSyncedAction,
          onAction: state.backup.isBusy ? null : controller.backupNow,
        ),
      );
      if (state.backup.isBusy) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s3),
            child: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: AppSpacing.s2),
                Text(l10n.shareBackupRunning),
              ],
            ),
          ),
        );
      }
    } else if (state.step == ShareStep.linkReady && state.links.isNotEmpty) {
      if (state.create case ActionError(failure: final f)) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s3),
            child: StateBlock(
              intent: ErrorPresenter.intentFor(f),
              title: ErrorPresenter.present(l10n, f).title,
              actionLabel: ErrorPresenter.present(l10n, f).actionLabel,
              onAction: controller.createLink,
            ),
          ),
        );
      }
      children.add(Text(l10n.shareExistingHeading, style: AppTypography.h3));
      children.add(const SizedBox(height: AppSpacing.s2));
      for (final link in state.links) {
        children.add(_LinkRow(link: link, controller: controller));
        children.add(const SizedBox(height: AppSpacing.s3));
      }
    } else {
      if (state.create case ActionError(failure: final f)) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s3),
            child: StateBlock(
              intent: ErrorPresenter.intentFor(f),
              title: ErrorPresenter.present(l10n, f).title,
              actionLabel: ErrorPresenter.present(l10n, f).actionLabel,
              onAction: controller.createLink,
            ),
          ),
        );
      }
      children.addAll([
        Text(l10n.shareGalleryHeading, style: AppTypography.h3),
        const SizedBox(height: AppSpacing.s1),
        Text(
          l10n.shareGalleryBody(childName),
          style: AppTypography.body.copyWith(color: AppColors.inkMuted),
        ),
        const SizedBox(height: AppSpacing.s3),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.sharingIncludeAudio, style: AppTypography.body),
          subtitle: Text(
            l10n.sharingIncludeAudioSubtitle,
            style: AppTypography.caption.copyWith(color: AppColors.inkMuted),
          ),
          value: state.newLinkIncludeAudio,
          onChanged: state.create.isBusy
              ? null
              : controller.setNewLinkIncludeAudio,
        ),
        const SizedBox(height: AppSpacing.s3),
        AsyncActionButton(
          action: state.create,
          idleLabel: l10n.shareGalleryCreate,
          busyLabel: l10n.shareGalleryCreating,
          variant: AppButtonVariant.share,
          fullWidth: true,
          enabled:
              state.childHasSyncedArtworks &&
              !state.offline &&
              !state.backup.isBusy,
          disabledReason: state.offline ? l10n.settingsOffline : null,
          onPressed: controller.createLink,
        ),
      ]);
    }

    // A second, clearly separated block, visible only when entered
    // from the artwork detail.
    if (args.sendImage != null) {
      children.addAll([
        const SizedBox(height: AppSpacing.s5),
        const Divider(color: AppColors.border),
        const SizedBox(height: AppSpacing.s3),
        Text(l10n.shareImageHeading, style: AppTypography.h3),
        const SizedBox(height: AppSpacing.s1),
        Text(
          l10n.shareImageBody,
          style: AppTypography.body.copyWith(color: AppColors.inkMuted),
        ),
        const SizedBox(height: AppSpacing.s2),
        Text(
          l10n.shareDifference,
          style: AppTypography.caption.copyWith(color: AppColors.inkMuted),
        ),
        const SizedBox(height: AppSpacing.s3),
        AppButton(
          label: l10n.shareImageHeading,
          variant: AppButtonVariant.share,
          fullWidth: true,
          onPressed: () {
            Navigator.of(context).pop();
            args.sendImage!();
          },
        ),
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

/// One row of the existing-links list — up to 5, each with its own
/// copy/revoke action, and its own busy/error rendering for the
/// revoke: the old code fired-and-forgot `revokeLink`, with no
/// spinner and no error path, so a failed revoke looked identical to
/// a successful one.
class _LinkRow extends ConsumerWidget {
  final ShareLink link;
  final ShareController controller;
  const _LinkRow({required this.link, required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(shareControllerProvider(controller.args));
    final revoking = state.revoke.isBusy;
    // The plaintext URL only ever exists, server-side, in the
    // link-creation call's one-time response — a link this device did
    // not itself create (cached locally at creation time) has no URL
    // to show, copy or send. Revoking stays available regardless: it
    // never needed the URL, only the link's `id`.
    final url = link.url;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (url != null) ...[
          StateBlock(
            intent: StateBlockIntent.success,
            title: l10n.shareLinkReadyTitle,
            body: url,
          ),
          const SizedBox(height: AppSpacing.s1),
          Text(
            l10n.shareLinkReadyCreatedOn(link.createdAt),
            style: AppTypography.caption.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: AppSpacing.s2),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: l10n.commonCopy,
                  variant: AppButtonVariant.secondary,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: url));
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(l10n.commonCopied)));
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: AppButton(
                  label: l10n.commonSend,
                  variant: AppButtonVariant.share,
                  onPressed: () {
                    SharePlus.instance.share(
                      ShareParams(
                        text: l10n.shareMessage(
                          state.resolvedChildName ?? controller.args.childName,
                          url,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ] else ...[
          StateBlock(
            intent: StateBlockIntent.help,
            title: l10n.shareLinkReadyTitle,
            body: l10n.shareLinkOtherDeviceBody,
          ),
          const SizedBox(height: AppSpacing.s1),
          Text(
            l10n.shareLinkReadyCreatedOn(link.createdAt),
            style: AppTypography.caption.copyWith(color: AppColors.inkMuted),
          ),
        ],
        const SizedBox(height: AppSpacing.s2),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.sharingIncludeAudio, style: AppTypography.body),
          subtitle: Text(
            l10n.sharingIncludeAudioSubtitle,
            style: AppTypography.caption.copyWith(color: AppColors.inkMuted),
          ),
          value: link.includeAudio,
          onChanged: state.updatingLinkIds.contains(link.id) || revoking
              ? null
              : (val) => controller.updateLinkIncludeAudio(link.id, val),
        ),
        const SizedBox(height: AppSpacing.s2),
        if (state.revoke case ActionError(failure: final f))
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s2),
            child: StateBlock(
              intent: ErrorPresenter.intentFor(f),
              title: l10n.shareRevokeError,
              actionLabel: l10n.commonRetry,
              onAction: () => controller.revokeLink(link.id),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: revoking
                ? null
                : () => _confirmRevoke(context, controller, link.id),
            child: Text(
              revoking ? l10n.shareRevoking : l10n.shareRevoke,
              style: TextStyle(
                fontFamily: AppTypography.family,
                color: revoking ? AppColors.inkDisabled : AppColors.danger,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmRevoke(
    BuildContext context,
    ShareController controller,
    String linkId,
  ) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) =>
          _RevokeDialog(controller: controller, linkId: linkId, l10n: l10n),
    );
  }
}

/// The revoke confirmation dialog itself watches `revoke`'s state so
/// it can go `busy` and non-dismissible, then close only once the
/// service has actually confirmed the revoke.
class _RevokeDialog extends ConsumerStatefulWidget {
  final ShareController controller;
  final String linkId;
  final AppLocalizations l10n;
  const _RevokeDialog({
    required this.controller,
    required this.linkId,
    required this.l10n,
  });

  @override
  ConsumerState<_RevokeDialog> createState() => _RevokeDialogState();
}

class _RevokeDialogState extends ConsumerState<_RevokeDialog> {
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final state = ref.watch(shareControllerProvider(widget.controller.args));
    final busy = state.revoke.isBusy;

    ref.listen(shareControllerProvider(widget.controller.args), (
      previous,
      next,
    ) {
      final wasBusy = previous?.revoke.isBusy ?? false;
      if (_confirmed && wasBusy && next.revoke is ActionDone && mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        // The link's disappearance is one signal, the confirmation
        // banner is a second, deliberate one. It is only posted here,
        // after the service confirms, never on the dialog's own
        // close.
        messenger.showSnackBar(SnackBar(content: Text(l10n.shareRevoked)));
      }
    });

    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        title: Text(l10n.shareRevokeTitle),
        content: Text(l10n.shareRevokeBody),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: busy
                ? null
                : () {
                    setState(() => _confirmed = true);
                    widget.controller.revokeLink(widget.linkId);
                  },
            child: Text(busy ? l10n.shareRevoking : l10n.shareRevoke),
          ),
        ],
      ),
    );
  }
}
