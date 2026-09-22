import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../children/trash_screen.dart';
import '../theme/app_tokens.dart';
import 'about_screen.dart';
import 'debug_settings_screen.dart';
import 'language_screen.dart';

/// The account-free settings surface.
///
/// Every row here is `local-only` (`docs/architecture/feature-matrix.md`):
/// language, about, the recoverable local trash, and — in debug builds —
/// the debug tools. None of them needs a capability, a composition, an
/// account, or a network, which is why this screen is the *default*
/// destination of the gallery's settings control rather than something a
/// composition has to supply (ADR 0016).
///
/// A composition with remote capabilities substitutes its own richer
/// settings surface through `CompositionActions.openSettings`; it is then
/// responsible for keeping these local rows reachable from it.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s4,
                AppSpacing.s2,
                AppSpacing.s4,
                AppSpacing.s3,
              ),
              child: Text(
                l10n.settingsLocalNotice,
                style: AppTypography.caption.copyWith(
                  color: AppColors.inkMuted,
                ),
              ),
            ),
            _SectionLabel(l10n.settingsGroupApp),
            _SettingsRow(
              icon: Icons.translate_outlined,
              label: l10n.settingsLanguageRow,
              onTap: () => _push(context, const LanguageScreen()),
            ),
            _SettingsRow(
              icon: Icons.delete_outline,
              label: l10n.trashTitle,
              onTap: () => _push(context, const TrashScreen()),
            ),
            _SettingsRow(
              icon: Icons.info_outline,
              label: l10n.settingsAboutRow,
              onTap: () => _push(context, const AboutScreen()),
            ),
            if (kDebugMode)
              _SettingsRow(
                icon: Icons.bug_report_outlined,
                label: l10n.settingsDebugRow,
                onTap: () => _push(context, const DebugSettingsScreen()),
              ),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s4,
        AppSpacing.s3,
        AppSpacing.s4,
        AppSpacing.s1,
      ),
      child: Text(
        label,
        style: AppTypography.label.copyWith(color: AppColors.inkMuted),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minVerticalPadding: 16,
      leading: Icon(icon, color: AppColors.ink),
      title: Text(label, style: AppTypography.body),
      trailing: const Icon(Icons.chevron_right, color: AppColors.inkMuted),
      onTap: onTap,
    );
  }
}
