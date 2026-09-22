import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../local/logging/log.dart';

import '../async_action.dart';
import '../navigation/composition_actions.dart';
import '../providers/core_providers.dart';
import '../theme/app_tokens.dart';
import '../ui/app_button.dart';
import '../ui/state_block.dart';
import 'family_controller.dart';

/// Invite-only « Famille » screen: the fixed invite code (to share, in text
/// or QR), and the section to join another family (manual input or QR
/// scan). Family naming and the active-members list live in the cloud
/// composition's family-settings surface, not here — this screen is
/// deliberately the smallest, fully account-free-safe surface: invite out,
/// or join in.
class FamilyInviteScreen extends ConsumerStatefulWidget {
  const FamilyInviteScreen({super.key});

  @override
  ConsumerState<FamilyInviteScreen> createState() => _FamilyInviteScreenState();
}

class _FamilyInviteScreenState extends ConsumerState<FamilyInviteScreen> {
  late final TextEditingController _codeController;

  @override
  void initState() {
    super.initState();
    Log.d('📱 [FamilyInviteScreen] Opening', 'Navigation');
    _codeController = TextEditingController();
    if (!ref.read(appCapabilitiesProvider).household) return;
    Future.microtask(
      () => ref.read(familyControllerProvider.notifier).loadFamilyInfo(),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    _codeController.text = text;
    setState(() {});
  }

  Future<void> _scanCode() async {
    final scanFn = ref.read(compositionActionsProvider).openQrScanner;
    if (scanFn == null) return;
    final result = await scanFn(context);
    if (result == null || !mounted) return;
    _codeController.text = result;
    setState(() {});
    await _confirmAndJoin(result);
  }

  /// The single entry point into a join, from either the submit button or
  /// the QR scanner: shows the destructive-confirmation dialog first, and
  /// only calls [FamilyController.redeem] if the user actually confirms.
  Future<void> _confirmAndJoin(String code) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _JoinFamilyDialog(code: code),
    );
    if (confirmed != true || !mounted) return;
    await ref
        .read(familyControllerProvider.notifier)
        .redeem(code, discardPrevious: true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final capabilities = ref.watch(appCapabilitiesProvider);
    if (!capabilities.household) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.familyTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s4),
            child: StateBlock(
              intent: StateBlockIntent.info,
              title: l10n.settingsLocalNotice,
            ),
          ),
        ),
      );
    }
    final state = ref.watch(familyControllerProvider);
    final controller = ref.read(familyControllerProvider.notifier);
    final info = state.familyInfo;
    final loading = state.family.isBusy && info == null;
    final canSubmitCode =
        _codeController.text.trim().length >= 6 && !state.redeem.isBusy;
    final canScanQr =
        ref.watch(compositionActionsProvider).openQrScanner != null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.familyTitle)),
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.s4),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.familyInviteExplain,
                        style: AppTypography.body.copyWith(
                          color: AppColors.inkMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      if (info != null) ...[
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.s4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: QrImageView(
                              data: info.code,
                              size: 200,
                              backgroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        Text(
                          l10n.familyInviteCodeLabel,
                          style: AppTypography.label.copyWith(
                            color: AppColors.inkMuted,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s1),
                        Center(
                          child: SelectableText(
                            info.code,
                            style: AppTypography.mono.copyWith(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 4,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        AppButton(
                          label: l10n.familyInviteCopy,
                          variant: AppButtonVariant.secondary,
                          fullWidth: true,
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: info.code),
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.familyInviteCopied)),
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: AppSpacing.s6),
                      const Divider(),
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        l10n.familyJoinExplain,
                        style: AppTypography.body.copyWith(
                          color: AppColors.inkMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      _buildOutcomeBlock(l10n, state, controller),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _codeController,
                              textCapitalization: TextCapitalization.characters,
                              maxLength: 8,
                              enabled:
                                  !state.redeem.isBusy &&
                                  !state.convergence.isBusy,
                              decoration: InputDecoration(
                                hintText: l10n.familyJoinCodeHint,
                                counterText: '',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          TextButton(
                            onPressed: _pasteFromClipboard,
                            child: Text(l10n.accountCodePaste),
                          ),
                        ],
                      ),
                      if (canScanQr) ...[
                        const SizedBox(height: AppSpacing.s2),
                        AppButton(
                          label: l10n.familyScanButton,
                          variant: AppButtonVariant.secondary,
                          fullWidth: true,
                          icon: Icons.qr_code_scanner,
                          onPressed:
                              state.redeem.isBusy || state.convergence.isBusy
                              ? null
                              : _scanCode,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.s4),
                      AsyncActionButton(
                        action: state.joinReset.isBusy
                            ? state.joinReset
                            : state.convergence.isBusy
                            ? state.convergence
                            : state.redeem,
                        idleLabel: l10n.familyJoinButton,
                        busyLabel: state.joinReset.isBusy
                            ? l10n.familyJoinDiscarding
                            : state.convergence.isBusy
                            ? l10n.familyJoinConverging
                            : l10n.familyJoinChecking,
                        fullWidth: true,
                        enabled: canSubmitCode,
                        onPressed: () =>
                            _confirmAndJoin(_codeController.text.trim()),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildOutcomeBlock(
    AppLocalizations l10n,
    FamilyState state,
    FamilyController controller,
  ) {
    if (state.redeem case ActionError()) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.s3),
        child: StateBlock(
          intent: StateBlockIntent.error,
          title: l10n.errorNetworkTitle,
          body: l10n.errorNetworkBody,
        ),
      );
    }
    if (state.joinReset case ActionError()) {
      // The join itself already committed server-side by this point —
      // only the local vault reset failed, so retrying re-runs just that
      // step (FamilyController.retryJoinReset), never a fresh redeem.
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.s3),
        child: StateBlock(
          intent: StateBlockIntent.error,
          title: l10n.familyJoinResetError,
          actionLabel: l10n.commonRetry,
          onAction: controller.retryJoinReset,
        ),
      );
    }
    if (state.convergence case ActionError()) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.s3),
        child: StateBlock(
          intent: StateBlockIntent.warning,
          title: l10n.settingsBackupBlocked,
        ),
      );
    }
    final outcome = state.redeemOutcome;
    if (outcome == null) return const SizedBox.shrink();
    return switch (outcome.state) {
      RedeemState.ok => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.s3),
        child: StateBlock(
          intent: StateBlockIntent.success,
          title: l10n.familyJoinSuccess,
        ),
      ),
      RedeemState.invalidCode => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.s3),
        child: StateBlock(
          intent: StateBlockIntent.error,
          title: l10n.familyJoinInvalidCode,
        ),
      ),
    };
  }
}

enum _JoinStep { summary, confirm }

/// Two-step destructive confirmation shown before every join — both entry
/// points ([_FamilyInviteScreenState._confirmAndJoin]) go through this,
/// never straight into [FamilyController.redeem]. Pops `true` only once the
/// user has seen the local-content bilan (step 1) and explicitly
/// acknowledged the loss (step 2, gated by a checkbox); `false` or a
/// dismissed dialog means "do nothing".
///
/// Deliberately makes no server call of its own: [FamilyController.joinImpact]
/// is read-only local content counts plus a membership check, never a
/// redemption. Showing this for a code that turns out to be invalid, or
/// the caller's own family, is harmless — [FamilyController.redeem] still
/// makes that determination itself and touches nothing in either case.
class _JoinFamilyDialog extends ConsumerStatefulWidget {
  final String code;
  const _JoinFamilyDialog({required this.code});

  @override
  ConsumerState<_JoinFamilyDialog> createState() => _JoinFamilyDialogState();
}

class _JoinFamilyDialogState extends ConsumerState<_JoinFamilyDialog> {
  _JoinStep _step = _JoinStep.summary;
  bool _confirmed = false;
  bool _impactLoaded = false;
  bool _impactFailed = false;
  JoinImpact? _impact;

  @override
  void initState() {
    super.initState();
    _loadImpact();
  }

  Future<void> _loadImpact() async {
    if (mounted) {
      setState(() {
        _impactLoaded = false;
        _impactFailed = false;
        _impact = null;
      });
    }
    ref
        .read(familyControllerProvider.notifier)
        .joinImpact()
        .then((impact) {
          if (!mounted) return;
          setState(() {
            _impact = impact;
            _impactLoaded = true;
          });
        })
        .catchError((_) {
          if (!mounted) return;
          setState(() {
            _impactFailed = true;
            _impactLoaded = true;
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      title: Text(l10n.familyJoinConfirmTitle),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: _step == _JoinStep.summary
              ? _buildSummary(l10n)
              : _buildConfirm(l10n),
        ),
      ),
      actions: _step == _JoinStep.summary
          ? [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.commonCancel),
              ),
              TextButton(
                onPressed: _impactFailed
                    ? _loadImpact
                    : _impactLoaded && _impact?.isAlone != null
                    ? () => setState(() => _step = _JoinStep.confirm)
                    : null,
                child: Text(_impactFailed ? l10n.commonRetry : l10n.commonNext),
              ),
            ]
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.commonCancel),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: _confirmed
                    ? () => Navigator.of(context).pop(true)
                    : null,
                child: Text(
                  _impact?.isAlone == false
                      ? l10n.familyJoinConfirmActionLeave
                      : l10n.familyJoinConfirmAction,
                ),
              ),
            ],
    );
  }

  List<Widget> _buildSummary(AppLocalizations l10n) {
    final impact = _impact;
    return [
      Text(l10n.familyJoinConfirmIntro),
      const SizedBox(height: AppSpacing.s3),
      if (impact == null && !_impactFailed)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.s4),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_impactFailed)
        Text(l10n.familyJoinConfirmCheckFailedWarning)
      else if (impact?.isAlone == null)
        Text(l10n.familyJoinConfirmCheckFailedWarning)
      else
        Text(
          '${l10n.familyJoinImpactChildren(impact!.childCount)} · '
          '${l10n.familyJoinImpactArtworks(impact.artworkCount)}',
          style: AppTypography.bodyStrong,
        ),
      const SizedBox(height: AppSpacing.s3),
      Text(
        l10n.familyJoinInviteInsteadHint,
        style: AppTypography.caption.copyWith(color: AppColors.inkMuted),
      ),
    ];
  }

  List<Widget> _buildConfirm(AppLocalizations l10n) {
    // Reached only once _impactLoaded is true (step 1 gates the "Next"
    // button on it) — isAlone can still be null (the membership check
    // itself failed), which picks the third, most conservative warning.
    final warning = switch (_impact?.isAlone) {
      true => l10n.familyJoinConfirmPurgeWarning,
      false => l10n.familyJoinConfirmLeaveWarning,
      null => l10n.familyJoinConfirmCheckFailedWarning,
    };
    return [
      Container(
        padding: const EdgeInsets.all(AppSpacing.s3),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Text(
          warning,
          style: AppTypography.body.copyWith(color: AppColors.danger),
        ),
      ),
      const SizedBox(height: AppSpacing.s3),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _confirmed,
        onChanged: (v) => setState(() => _confirmed = v ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(l10n.familyJoinConfirmCheck),
      ),
    ];
  }
}
