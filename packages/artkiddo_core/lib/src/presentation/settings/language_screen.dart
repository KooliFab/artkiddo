import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../locale/locale_provider.dart';
import '../theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';

/// `language` — three radio options — `screens.md` §9.4.
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final choice = ref.watch(localeChoiceProvider);
    final notifier = ref.read(localeChoiceProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsLanguageRow)),
      body: SafeArea(
        child: RadioGroup<AppLanguageChoice>(
          groupValue: choice,
          onChanged: (v) {
            if (v != null) notifier.setChoice(v);
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
            children: [
              _option(l10n.settingsLanguageSystem, AppLanguageChoice.system),
              _option(l10n.settingsLanguageFr, AppLanguageChoice.fr),
              _option(l10n.settingsLanguageEn, AppLanguageChoice.en),
            ],
          ),
        ),
      ),
    );
  }

  Widget _option(String label, AppLanguageChoice value) {
    return RadioListTile<AppLanguageChoice>(value: value, title: Text(label));
  }
}
