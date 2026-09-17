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
import 'foyer_controller.dart';

/// Single « Famille » screen: family name, fixed invite code (to share, in text or QR),
/// and section to join another family (manual input or QR scan).
class FamilyScreen extends ConsumerStatefulWidget {
  const FamilyScreen({super.key});

  @override
  ConsumerState<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends ConsumerState<FamilyScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  String? _lastLoadedName;

  @override
  void initState() {
    super.initState();
    Log.d('📱 [FamilyScreen] Opening', 'Navigation');
    _nameController = TextEditingController();
    _codeController = TextEditingController();
    if (!ref.read(appCapabilitiesProvider).household) return;
    Future.microtask(
      () => ref.read(foyerControllerProvider.notifier).loadFamilyInfo(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _syncNameField(FamilyInfo info) {
    if (_lastLoadedName == info.name) return;
    _lastLoadedName = info.name;
    _nameController.text = info.name ?? '';
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
    await ref.read(foyerControllerProvider.notifier).redeem(result);
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
    final state = ref.watch(foyerControllerProvider);
    final controller = ref.read(foyerControllerProvider.notifier);
    final info = state.familyInfo;
    if (info != null) _syncNameField(info);
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
                        l10n.familyNameLabel,
                        style: AppTypography.label.copyWith(
                          color: AppColors.inkMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s1),
                      TextField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        enabled: !state.rename.isBusy,
                        decoration: InputDecoration(
                          hintText: l10n.familyNameHint,
                        ),
                        onSubmitted: (value) =>
                            controller.renameFamily(value.trim()),
                      ),
                      const SizedBox(height: AppSpacing.s2),
                      AsyncActionButton(
                        action: state.rename,
                        idleLabel: l10n.commonSave,
                        busyLabel: l10n.commonSaving,
                        variant: AppButtonVariant.tertiary,
                        onPressed: () => controller.renameFamily(
                          _nameController.text.trim(),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s6),
                      const Divider(),
                      const SizedBox(height: AppSpacing.s4),
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
                      _buildOutcomeBlock(l10n, state),
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
                        action: state.convergence.isBusy
                            ? state.convergence
                            : state.redeem,
                        idleLabel: l10n.familyJoinButton,
                        busyLabel: state.convergence.isBusy
                            ? l10n.familyJoinConverging
                            : l10n.familyJoinChecking,
                        fullWidth: true,
                        enabled: canSubmitCode,
                        onPressed: () =>
                            controller.redeem(_codeController.text.trim()),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildOutcomeBlock(AppLocalizations l10n, FoyerState state) {
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
