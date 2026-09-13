import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../async_action.dart';
import '../../local/logging/log.dart';
import '../../domain/action_result.dart';
import '../theme/app_tokens.dart';
import '../ui/app_button.dart';
import '../ui/discard_guard.dart';
import '../ui/error_presenter.dart';
import '../ui/formatters.dart';
import '../ui/state_block.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'child_editor_controller.dart';

Future<ActionResult<String>?> pushChildEditor(
  BuildContext context,
  ChildEditorArgs args,
) {
  final width = MediaQuery.of(context).size.width;
  if (AppBreakpoints.isCompact(width)) {
    return Navigator.of(context).push<ActionResult<String>>(
      MaterialPageRoute(builder: (_) => ChildEditorScreen(args: args)),
    );
  }
  return showDialog<ActionResult<String>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: ChildEditorScreen(args: args),
      ),
    ),
  );
}

class ChildEditorScreen extends ConsumerStatefulWidget {
  final ChildEditorArgs args;

  const ChildEditorScreen({super.key, required this.args});

  @override
  ConsumerState<ChildEditorScreen> createState() => _ChildEditorScreenState();
}

class _ChildEditorScreenState extends ConsumerState<ChildEditorScreen> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    Log.d(
      '📱 [ChildEditorScreen] Opening (${widget.args.childId == null ? 'create' : 'edit'})',
      'Navigation',
    );
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context, DateTime? current) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime(now.year - 3, now.month, now.day),
      firstDate: DateTime(now.year - 18, now.month, now.day),
      lastDate: now,
    );
    if (picked != null) {
      ref
          .read(childEditorControllerProvider(widget.args).notifier)
          .updateBirthDate(picked);
    }
  }

  Future<void> _handleSave() async {
    final controller = ref.read(
      childEditorControllerProvider(widget.args).notifier,
    );
    final result = await controller.save();
    if (!mounted) return;
    switch (result) {
      case ActionSuccess(value: final id):
        Navigator.of(context).pop(ActionSuccess<String>(id));
      case ActionCancelled():
        break; // validation errors shown inline
      case ActionFailed():
        break; // error block shown inline, form intact
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(childEditorControllerProvider(widget.args));
    final isCreate = widget.args.childId == null;

    if (_nameController.text != state.name &&
        !_nameController.value.composing.isValid) {}
    if (_nameController.text.isEmpty && state.name.isNotEmpty) {
      _nameController.text = state.name;
    }

    final nameError = state.attemptedSubmit
        ? (state.errors.contains(ChildFieldError.nameEmpty)
              ? l10n.childEditorErrorNameEmpty
              : state.errors.contains(ChildFieldError.nameTooLong)
              ? l10n.childEditorErrorNameTooLong
              : null)
        : null;
    final nameDuplicateWarning =
        state.attemptedSubmit &&
            state.errors.contains(ChildFieldError.nameDuplicate)
        ? l10n.childEditorWarnNameDuplicate
        : null;

    final birthDateError = state.attemptedSubmit
        ? (state.errors.contains(ChildFieldError.birthDateMissing)
              ? l10n.childEditorErrorBirthDateMissing
              : state.errors.contains(ChildFieldError.birthDateFuture)
              ? l10n.childEditorErrorBirthDateFuture
              : state.errors.contains(ChildFieldError.birthDateTooOld)
              ? l10n.childEditorErrorBirthDateTooOld
              : null)
        : null;

    final canSave =
        state.name.trim().isNotEmpty &&
        state.birthDate != null &&
        !state.loading;

    return DiscardGuard(
      isDirty: state.isDirty && !state.save.isBusy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            isCreate ? l10n.childEditorTitleCreate : l10n.childEditorTitleEdit,
          ),
        ),
        body: state.loading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSpacing.s4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.args.origin ==
                                ChildEditorOrigin.captureDraft) ...[
                              StateBlock(
                                intent: StateBlockIntent.info,
                                title: l10n.childEditorFromDraft,
                              ),
                              const SizedBox(height: AppSpacing.s4),
                            ],
                            if (state.save case ActionError(
                              failure: final failure,
                            )) ...[
                              StateBlock(
                                intent: ErrorPresenter.intentFor(failure),
                                title: l10n.childEditorErrorWrite,
                                actionLabel: l10n.commonRetry,
                                onAction: _handleSave,
                              ),
                              const SizedBox(height: AppSpacing.s4),
                            ],
                            Text(
                              l10n.childEditorNameLabel,
                              style: AppTypography.label.copyWith(
                                color: AppColors.inkMuted,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s1),
                            TextField(
                              controller: _nameController,
                              autofocus: isCreate,
                              textCapitalization: TextCapitalization.words,
                              enabled: !state.save.isBusy,
                              maxLength: 40,
                              decoration: InputDecoration(
                                hintText: l10n.childEditorNameHint,
                                errorText: nameError,
                                counterText: '',
                              ),
                              onChanged: (v) => ref
                                  .read(
                                    childEditorControllerProvider(
                                      widget.args,
                                    ).notifier,
                                  )
                                  .updateName(v),
                            ),
                            if (nameDuplicateWarning != null) ...[
                              const SizedBox(height: AppSpacing.s1),
                              Text(
                                nameDuplicateWarning,
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.warning,
                                ),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.s4),
                            Text(
                              l10n.childEditorBirthDateLabel,
                              style: AppTypography.label.copyWith(
                                color: AppColors.inkMuted,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s1),
                            InkWell(
                              onTap: state.save.isBusy
                                  ? null
                                  : () => _pickDate(context, state.birthDate),
                              child: Container(
                                constraints: const BoxConstraints(
                                  minHeight: 64,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.s4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.sm,
                                  ),
                                  border: Border.all(
                                    color: birthDateError != null
                                        ? AppColors.danger
                                        : AppColors.borderStrong,
                                    width: birthDateError != null ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        state.birthDate != null
                                            ? Formatters.date(
                                                l10n,
                                                state.birthDate!,
                                              )
                                            : l10n.childEditorBirthDateChoose,
                                        style: state.birthDate != null
                                            ? AppTypography.body
                                            : AppTypography.body.copyWith(
                                                color: AppColors.inkDisabled,
                                              ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right,
                                      color: AppColors.inkMuted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (birthDateError != null) ...[
                              const SizedBox(height: AppSpacing.s1),
                              Text(
                                birthDateError,
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.danger,
                                ),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.s2),
                            Text(
                              l10n.childEditorBirthDateHelp,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.s4),
                        child: AsyncActionButton(
                          action: state.save,
                          idleLabel: l10n.commonSave,
                          busyLabel: l10n.commonSaving,
                          fullWidth: true,
                          enabled: canSave,
                          disabledReason: canSave
                              ? null
                              : l10n.childEditorSaveDisabledReason,
                          onPressed: _handleSave,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
