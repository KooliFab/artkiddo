part of 'artwork_screen.dart';

class _StoryEditorSheet extends ConsumerStatefulWidget {
  final String artworkId;
  final String initialStory;
  const _StoryEditorSheet({
    required this.artworkId,
    required this.initialStory,
  });

  @override
  ConsumerState<_StoryEditorSheet> createState() => _StoryEditorSheetState();
}

class _StoryEditorSheetState extends ConsumerState<_StoryEditorSheet> {
  late final TextEditingController _controller;
  AsyncAction _save = const ActionIdle();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialStory);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isDirty => _controller.text.trim() != widget.initialStory.trim();

  Future<void> _save0() async {
    // D45: isBusy guard to prevent duplicate saves while in-flight.
    if (_save.isBusy) return;
    setState(() => _save = const ActionBusy());
    final repo = ref.read(artworksRepositoryProvider);
    final text = _controller.text.trim();
    final result = await repo.updateStory(
      id: widget.artworkId,
      story: text.isEmpty ? null : text,
    );
    if (!mounted) return;
    if (result is ActionSuccess) {
      Navigator.of(context).pop(text);
    } else if (result is ActionFailed<void>) {
      setState(() => _save = ActionError(result.failure));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DiscardGuard(
      isDirty: _isDirty && !_save.isBusy,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.s6,
            right: AppSpacing.s6,
            top: AppSpacing.s4,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.artworkStoryEdit, style: AppTypography.h2),
              const SizedBox(height: AppSpacing.s3),
              if (_save case ActionError())
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                  child: StateBlock(
                    intent: StateBlockIntent.error,
                    title: l10n.artworkStoryError,
                  ),
                ),
              TextField(
                controller: _controller,
                maxLines: 3,
                minLines: 3,
                maxLength: 500,
                autofocus: true,
                enabled: !_save.isBusy,
                decoration: InputDecoration(hintText: l10n.artworkStoryHint),
              ),
              const SizedBox(height: AppSpacing.s4),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: l10n.commonCancel,
                      variant: AppButtonVariant.secondary,
                      onPressed: _save.isBusy
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(
                    child: AsyncActionButton(
                      action: _save,
                      idleLabel: l10n.commonSave,
                      busyLabel: l10n.commonSaving,
                      onPressed: _save0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
