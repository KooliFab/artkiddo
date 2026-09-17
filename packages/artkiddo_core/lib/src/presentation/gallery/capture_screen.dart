import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../async_action.dart';
import '../../local/logging/log.dart';
import '../../domain/action_result.dart';
import '../theme/app_tokens.dart';
import '../ui/app_button.dart';
import '../utils/app_settings_launcher.dart';
import '../ui/discard_guard.dart';
import '../ui/error_presenter.dart';
import '../ui/state_block.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../children/child_editor_controller.dart';
import '../children/child_editor_screen.dart';
import '../children/children_providers.dart';
import '../../domain/child.dart' as domain;
import 'camera_capture_screen.dart';
import 'capture_controller.dart';

class CaptureScreen extends ConsumerStatefulWidget {
  final CaptureEntry entry;
  final ImageSource? initialSource;
  const CaptureScreen({super.key, required this.entry, this.initialSource});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  late final TextEditingController _storyController;
  bool _detailsExpanded = false;
  bool _sheetOpen = false;
  bool _cropping = false;

  @override
  void initState() {
    super.initState();
    Log.d(
      '📱 [CaptureScreen] Opening (origin: ${widget.entry.origin.name})',
      'Navigation',
    );
    _storyController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final source = widget.initialSource;
      if (source == null) {
        _openSourceSheet();
      } else {
        _acquirePhoto(source);
      }
    });
  }

  @override
  void dispose() {
    _storyController.dispose();
    super.dispose();
  }

  CaptureController get _controller =>
      ref.read(captureControllerProvider(widget.entry).notifier);

  Future<void> _openSourceSheet() async {
    if (_sheetOpen || !mounted) return;
    final state = ref.read(captureControllerProvider(widget.entry));
    if (state.step != CaptureStep.sourceChoice) return;
    if (state.pickingPhoto) return; // gallery picker already open
    _sheetOpen = true;
    try {
      final result = await showModalBottomSheet<ImageSource>(
        context: context,
        isDismissible: true,
        builder: (ctx) => _SourceChoiceSheet(entry: widget.entry),
      );
      if (!mounted) return;
      if (result == null) {
        final current = ref.read(captureControllerProvider(widget.entry));
        if (current.draft == null) {
          Navigator.of(context).pop(const ActionCancelled<String>());
        }
        return;
      }
      await _acquirePhoto(result);
    } finally {
      _sheetOpen = false;
    }
  }

  Future<void> _acquirePhoto(ImageSource source) async {
    if (source != ImageSource.camera) {
      await _controller.chooseSource(source);
      return;
    }
    final outcome = await Navigator.of(context).push<CameraCaptureOutcome>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const CameraCaptureScreen(),
      ),
    );
    if (!mounted) return;
    switch (outcome) {
      case CameraCaptureSuccess(path: final path):
        await _controller.photoPicked(path, source: ImageSource.camera);
      case CameraCaptureDenied():
        _controller.reportCameraDenied();
      case CameraCaptureCancelled():
      case null:
        _controller.pickerCancelled();
    }
  }

  Future<void> _handleRetake() async {
    final state = ref.read(captureControllerProvider(widget.entry));
    if (state.lastSource == ImageSource.camera) {
      await _controller.discardDraftForRetake();
      if (mounted) await _acquirePhoto(ImageSource.camera);
    } else {
      await _controller.retakeSameSource();
    }
  }

  Future<void> _triggerCrop() async {
    if (_cropping) return;
    _cropping = true;
    try {
      final l10n = AppLocalizations.of(context);
      await _controller.cropDraft(cropTitle: l10n.captureIosCropTitle);
    } finally {
      _cropping = false;
    }
  }

  Future<void> _handleBack() async {
    final state = ref.read(captureControllerProvider(widget.entry));
    if (state.isRecording) {
      await _controller.cancelRecording();
      return;
    }
    switch (state.step) {
      case CaptureStep.sourceChoice:
        Navigator.of(context).pop(const ActionCancelled<String>());
      case CaptureStep.review:
        final confirmed = await DiscardGuard.confirmDiscard(
          context,
          title: AppLocalizations.of(context).captureDiscardPhotoTitle,
          body: AppLocalizations.of(context).captureDiscardPhotoBody,
        );
        if (confirmed) await _controller.backToSourceChoice();
      case CaptureStep.details:
        if (!state.isDirty) {
          await _controller.backToReviewFromDetails();
          return;
        }
        final confirmed = await DiscardGuard.confirmDiscard(
          context,
          title: AppLocalizations.of(context).captureDiscardTitle,
          body: AppLocalizations.of(context).captureDiscardBody,
        );
        if (confirmed) {
          await _controller.discardDraft();
          if (mounted) {
            Navigator.of(context).pop(const ActionCancelled<String>());
          }
        }
    }
  }

  Future<void> _handleSave() async {
    final result = await _controller.save();
    if (!mounted) return;
    if (result is ActionSuccess<String>) {
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(captureControllerProvider(widget.entry));

    ref.listen(captureControllerProvider(widget.entry), (previous, next) {
      if (next.step == CaptureStep.sourceChoice &&
          !_sheetOpen &&
          !next.pickingPhoto) {
        _openSourceSheet();
      }
      if (next.step == CaptureStep.review &&
          next.draft != null &&
          !next.draft!.cropped &&
          !next.reviewLoading &&
          !next.reviewUnreadable &&
          !_cropping) {
        _triggerCrop();
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (state.save.isBusy) return; // Retour ignoré pendant submitting
        await _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.captureTitle),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: state.save.isBusy ? null : _handleBack,
          ),
        ),
        body: switch (state.step) {
          CaptureStep.sourceChoice => state.pickingPhoto
              ? const Center(child: CircularProgressIndicator())
              : const SizedBox.shrink(),
          CaptureStep.review => _buildReview(l10n, state),
          CaptureStep.details => _buildDetails(l10n, state),
        },
      ),
    );
  }

  Widget _buildReview(AppLocalizations l10n, CaptureState state) {
    if (state.reviewLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.reviewUnreadable) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s4),
          child: StateBlock(
            intent: StateBlockIntent.error,
            title: l10n.captureReviewUnreadable,
            actionLabel: l10n.captureReviewRetake,
            onAction: _controller.backToSourceChoice,
          ),
        ),
      );
    }
    final draft = state.draft;
    if (draft == null) return const SizedBox.shrink();

    if (!draft.cropped) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: Column(
        children: [
          if (state.reviewTooLarge)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.s3),
              child: StateBlock(
                intent: StateBlockIntent.warning,
                title: l10n.captureReviewTooLarge,
              ),
            ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(AppSpacing.s4),
              color: AppColors.paper,
              child: Image.file(
                File(draft.temporaryImagePath),
                fit: BoxFit.contain,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.s4),
            child: AppButton(
              label: l10n.captureReviewRetake,
              variant: AppButtonVariant.secondary,
              onPressed: _handleRetake,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetails(AppLocalizations l10n, CaptureState state) {
    final draft = state.draft;
    if (draft == null) return const Center(child: CircularProgressIndicator());
    final childrenAsync = ref.watch(allChildrenStreamProvider);
    final children = childrenAsync.value ?? const <domain.Child>[];
    final noChild = children.isEmpty;
    final artistRequired =
        children.length >= 2 && state.selectedChildId == null;
    final canSave = state.selectedChildId != null && !state.isRecording;

    if (_storyController.text != draft.story && _storyController.text.isEmpty) {
      _storyController.text = draft.story;
    }

    final saveBar = AsyncActionButton(
      action: state.save,
      idleLabel: l10n.captureSave,
      busyLabel: l10n.commonSaving,
      fullWidth: true,
      enabled: canSave,
      disabledReason: state.isRecording
          ? l10n.captureAudioRecording
          : (canSave ? null : l10n.captureArtistRequired),
      onPressed: _handleSave,
    );

    final banners = <Widget>[
      if (state.childCreatedBanner != null) ...[
        StateBlock(
          intent: StateBlockIntent.success,
          title: l10n.captureChildCreated(state.childCreatedBanner!),
        ),
        const SizedBox(height: AppSpacing.s3),
      ],
      if (state.save case ActionError(failure: final f)) ...[
        StateBlock(
          intent: ErrorPresenter.intentFor(f),
          title: ErrorPresenter.present(l10n, f).title,
          body: ErrorPresenter.present(l10n, f).body,
          actionLabel: l10n.commonRetry,
          onAction: _handleSave,
        ),
        const SizedBox(height: AppSpacing.s3),
      ],
    ];

    final formFields = <Widget>[
      Text(
        l10n.captureArtistLabel,
        style: AppTypography.label.copyWith(color: AppColors.inkMuted),
      ),
      const SizedBox(height: AppSpacing.s1),
      if (noChild)
        StateBlock(
          intent: StateBlockIntent.help,
          title: l10n.captureNoChildTitle,
          body: l10n.captureNoChildBody,
          actionLabel: l10n.captureArtistAddChild,
          onAction: () => _openChildEditor(context),
        )
      else
        _buildArtistPicker(l10n, state, children),
      if (artistRequired && state.artistErrorShown) ...[
        const SizedBox(height: AppSpacing.s1),
        Text(
          l10n.captureArtistRequired,
          style: AppTypography.caption.copyWith(color: AppColors.danger),
        ),
      ],
      const SizedBox(height: AppSpacing.s4),
      _buildAudioStoryCard(context, l10n, state),
      const SizedBox(height: AppSpacing.s4),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: AppSpacing.s2),
        initiallyExpanded: _detailsExpanded || draft.story.isNotEmpty,
        onExpansionChanged: (expanded) =>
            setState(() => _detailsExpanded = expanded),
        title: Text(l10n.captureAnecdoteTitle, style: AppTypography.bodyStrong),
        subtitle: Text(
          l10n.captureAnecdoteSubtitle,
          style: AppTypography.caption.copyWith(color: AppColors.inkMuted),
        ),
        children: [
          TextField(
            controller: _storyController,
            maxLines: 3,
            minLines: 3,
            maxLength: 500,
            enabled: !state.save.isBusy,
            decoration: InputDecoration(hintText: l10n.captureStoryHint),
            onChanged: _controller.updateStory,
          ),
        ],
      ),
      Text(
        l10n.captureAddedToday(DateTime.now()),
        style: AppTypography.caption.copyWith(color: AppColors.inkMuted),
      ),
    ];

    final thumbnail = Center(
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            child: Container(
              height: 120,
              color: AppColors.surfaceSunken,
              child: Image.file(
                File(draft.temporaryImagePath),
                fit: BoxFit.contain,
              ),
            ),
          ),
          TextButton(
            onPressed: _controller.backToReviewFromDetails,
            child: Text(l10n.captureDetailsViewLarge),
          ),
        ],
      ),
    );

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (AppBreakpoints.isCompact(constraints.maxWidth)) {
            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.s4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...banners,
                        thumbnail,
                        const SizedBox(height: AppSpacing.s1),
                        ...formFields,
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.s4),
                    child: saveBar,
                  ),
                ),
              ],
            );
          }

          final wideImage = Container(
            color: AppColors.surfaceSunken,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.lg),
              child: Image.file(
                File(draft.temporaryImagePath),
                fit: BoxFit.contain,
              ),
            ),
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.s4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: SizedBox(
                    height: constraints.maxHeight - AppSpacing.s4 * 2,
                    child: wideImage,
                  ),
                ),
                const SizedBox(width: AppSpacing.s5),
                Expanded(
                  flex: 5,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...banners,
                        ...formFields,
                        const SizedBox(height: AppSpacing.s4),
                        saveBar,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildArtistPicker(
    AppLocalizations l10n,
    CaptureState state,
    List<domain.Child> children,
  ) {
    final selected = state.selectedChildId != null
        ? children.where((c) => c.id == state.selectedChildId).firstOrNull
        : null;

    return InkWell(
      onTap: () => _openArtistSheet(children, state.selectedChildId),
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(
            color: AppColors.borderStrong,
            width: selected == null ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.accentSurface,
              child: selected != null
                  ? Text(
                      selected.name[0].toUpperCase(),
                      style: const TextStyle(
                        fontFamily: AppTypography.family,
                        color: AppColors.accentPressed,
                      ),
                    )
                  : const Icon(
                      Icons.person_outline,
                      size: 18,
                      color: AppColors.inkMuted,
                    ),
            ),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Text(
                selected?.name ?? l10n.captureArtistChoose,
                style: selected != null
                    ? AppTypography.body
                    : AppTypography.body.copyWith(color: AppColors.inkDisabled),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.inkMuted),
          ],
        ),
      ),
    );
  }

  Future<void> _openArtistSheet(
    List<domain.Child> children,
    String? selectedId,
  ) async {
    final l10n = AppLocalizations.of(context);
    final result = await showModalBottomSheet<String?>(
      context: context,
      builder: (ctx) => SafeArea(
        child: RadioGroup<String>(
          groupValue: selectedId,
          onChanged: (v) => Navigator.of(ctx).pop(v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final child in children)
                ListTile(
                  leading: Radio<String>(value: child.id),
                  title: Text(child.name),
                  onTap: () => Navigator.of(ctx).pop(child.id),
                ),
              ListTile(
                leading: const Icon(Icons.add),
                title: Text(l10n.captureArtistAddChild),
                onTap: () => Navigator.of(ctx).pop('__add__'),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    if (result == '__add__') {
      await _openChildEditor(context);
    } else {
      _controller.selectChild(result);
    }
  }

  Future<void> _openChildEditor(BuildContext context) async {
    final result = await pushChildEditor(
      context,
      const ChildEditorArgs(origin: ChildEditorOrigin.captureDraft),
    );
    if (!mounted) return;
    if (result is ActionSuccess<String>) {
      final children =
          ref.read(allChildrenStreamProvider).value ?? const <domain.Child>[];
      final created = children.where((c) => c.id == result.value).firstOrNull;
      _controller.childCreated(result.value, created?.name ?? '');
    }
  }

  Widget _buildAudioStoryCard(
    BuildContext context,
    AppLocalizations l10n,
    CaptureState state,
  ) {
    final draft = state.draft;
    final hasAudio = draft?.temporaryAudioPath != null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(
          color: state.isRecording ? AppColors.accent : AppColors.borderStrong,
          width: state.isRecording ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.micPermission == PermissionStatus.denied) ...[
            StateBlock(
              intent: StateBlockIntent.warning,
              title: l10n.captureAudioMicPermissionDeniedTitle,
              body: l10n.captureAudioMicPermissionDeniedBody,
              actionLabel: l10n.commonOpenSettings,
              onAction: AppSettingsLauncher.open,
            ),
          ] else if (state.isRecording) ...[
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.s2),
                Text(
                  l10n.captureAudioRecording,
                  style: AppTypography.bodyStrong.copyWith(
                    color: AppColors.accent,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_formatDuration(state.recordingDurationMs)} / 02:00',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s3),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: state.soundLevel.clamp(0.05, 1.0),
                backgroundColor: AppColors.surfaceSunken,
                valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: AppSpacing.s3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.close, size: 18),
                  label: Text(l10n.captureAudioCancel),
                  onPressed: _controller.cancelRecording,
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.stop, size: 18),
                  label: Text(l10n.captureAudioStop),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                  ),
                  onPressed: _controller.stopRecording,
                ),
              ],
            ),
          ] else if (hasAudio) ...[
            Row(
              children: [
                const Icon(Icons.mic, color: AppColors.accent),
                const SizedBox(width: AppSpacing.s2),
                Expanded(
                  child: Text(
                    l10n.captureAudioCardTitle,
                    style: AppTypography.bodyStrong,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s2,
                    vertical: AppSpacing.s1,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentSurface,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Text(
                    _formatDuration(draft!.audioDurationMs ?? 0),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.accentPressed,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s3),
            Row(
              children: [
                IconButton.filled(
                  icon: Icon(
                    state.isPlayingAudio ? Icons.pause : Icons.play_arrow,
                  ),
                  onPressed: _controller.togglePlayback,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.onAccent,
                  ),
                ),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value:
                              (draft.audioDurationMs != null &&
                                  draft.audioDurationMs! > 0)
                              ? (state.playbackPositionMs /
                                        draft.audioDurationMs!)
                                    .clamp(0.0, 1.0)
                              : 0.0,
                          backgroundColor: AppColors.surfaceSunken,
                          valueColor: const AlwaysStoppedAnimation(
                            AppColors.accent,
                          ),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s1),
                      Text(
                        '${_formatDuration(state.playbackPositionMs)} / ${_formatDuration(draft.audioDurationMs ?? 0)}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s2),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.s2,
              runSpacing: AppSpacing.s1,
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s2,
                    ),
                  ),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(l10n.captureAudioReRecord),
                  onPressed: () => _handleReRecord(context, l10n),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s2,
                    ),
                  ),
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: AppColors.danger,
                  ),
                  label: Text(
                    l10n.captureAudioDelete,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                  onPressed: () => _handleDeleteAudio(context, l10n),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                const Icon(Icons.mic_none_outlined, color: AppColors.inkMuted),
                const SizedBox(width: AppSpacing.s2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.captureAudioCardTitle,
                        style: AppTypography.bodyStrong,
                      ),
                      Text(
                        l10n.captureAudioCardSubtitle,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s3),
            OutlinedButton.icon(
              icon: const Icon(Icons.mic, color: AppColors.accent),
              label: Text(
                l10n.captureAudioRecord,
                style: const TextStyle(color: AppColors.accent),
              ),
              onPressed: _controller.startRecording,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleReRecord(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        title: Text(l10n.captureAudioReRecordConfirmTitle),
        content: Text(l10n.captureAudioReRecordConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.captureAudioReRecord),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _controller.startRecording();
    }
  }

  Future<void> _handleDeleteAudio(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        title: Text(l10n.captureAudioDeleteConfirmTitle),
        content: Text(l10n.captureAudioDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _controller.deleteAudio();
    }
  }

  String _formatDuration(int ms) {
    final totalSeconds = (ms / 1000).floor();
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _SourceChoiceSheet extends ConsumerWidget {
  final CaptureEntry entry;
  const _SourceChoiceSheet({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(captureControllerProvider(entry));
    final permissions = state.permissions;
    final cameraDenied = permissions.camera == PermissionStatus.denied;
    final photosDenied = permissions.photos == PermissionStatus.denied;
    final bothDenied = cameraDenied && photosDenied;

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
            Text(l10n.captureTitle, style: AppTypography.h2),
            const SizedBox(height: AppSpacing.s3),
            if (bothDenied) ...[
              StateBlock(
                intent: StateBlockIntent.warning,
                title: l10n.permissionBothDeniedTitle,
                body: l10n.permissionBothDeniedBody,
                actionLabel: l10n.commonOpenSettings,
                onAction: () {
                  AppSettingsLauncher.open();
                },
              ),
              const SizedBox(height: AppSpacing.s3),
            ] else if (cameraDenied || photosDenied) ...[
              StateBlock(
                intent: StateBlockIntent.warning,
                title: cameraDenied
                    ? l10n.permissionCameraDeniedTitle
                    : l10n.permissionPhotosDeniedTitle,
                body: cameraDenied
                    ? l10n.permissionCameraDeniedBody
                    : l10n.permissionPhotosDeniedBody,
                actionLabel: l10n.commonOpenSettings,
                onAction: () {
                  AppSettingsLauncher.open();
                },
              ),
              const SizedBox(height: AppSpacing.s3),
            ],
            ListTile(
              enabled: !cameraDenied,
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(l10n.captureSourceCameraTitle),
              subtitle: Text(
                cameraDenied
                    ? l10n.permissionCameraReason
                    : l10n.captureSourceCameraBody,
              ),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              enabled: !photosDenied,
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.captureSourceGalleryTitle),
              subtitle: Text(
                photosDenied
                    ? l10n.permissionPhotosReason
                    : l10n.captureSourceGalleryBody,
              ),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            const SizedBox(height: AppSpacing.s2),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.commonCancel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
