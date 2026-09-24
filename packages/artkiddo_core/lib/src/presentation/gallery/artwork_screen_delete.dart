part of 'artwork_screen.dart';

/// D18: `screens.md` §5 `deleting`/`deleteError` — the dialog stays open
/// (non-dismissible) with a `busy` button while the repository call is in
/// flight, and only pops `true` once the deletion is actually confirmed.
/// A failure keeps the dialog open with a retryable error block, exactly
/// like `_DeleteChildDialog` / `_RevokeDialog`.
class _DeleteArtworkDialog extends ConsumerStatefulWidget {
  final String artworkId;
  final bool hasSyncedCopy;
  const _DeleteArtworkDialog({
    required this.artworkId,
    required this.hasSyncedCopy,
  });

  @override
  ConsumerState<_DeleteArtworkDialog> createState() =>
      _DeleteArtworkDialogState();
}

class _DeleteArtworkDialogState extends ConsumerState<_DeleteArtworkDialog> {
  AsyncAction _state = const ActionIdle();

  Future<void> _delete() async {
    if (_state.isBusy) return;
    setState(() => _state = const ActionBusy());
    final repo = ref.read(artworksRepositoryProvider);
    final result = await repo.delete(widget.artworkId);
    if (!mounted) return;
    switch (result) {
      case ActionSuccess():
        Navigator.of(context).pop(true);
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
        title: Text(l10n.artworkDeleteTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.artworkDeleteBody),
            if (widget.hasSyncedCopy) ...[
              const SizedBox(height: AppSpacing.s2),
              Text(
                l10n.artworkDeleteCloudNotice,
                style: AppTypography.caption.copyWith(
                  color: AppColors.inkMuted,
                ),
              ),
            ],
            if (_state case ActionError(failure: final f)) ...[
              const SizedBox(height: AppSpacing.s3),
              StateBlock(
                intent: ErrorPresenter.intentFor(f),
                title: l10n.artworkDeleteError,
                actionLabel: l10n.commonRetry,
                onAction: _delete,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: busy ? null : _delete,
            child: Text(busy ? l10n.commonDeleting : l10n.commonDelete),
          ),
        ],
      ),
    );
  }
}
