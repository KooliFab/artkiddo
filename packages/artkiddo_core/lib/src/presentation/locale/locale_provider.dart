import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Language choices: follow system, French (FR-CA), or English (EN-CA).
/// The manual choice is persisted and applied immediately without
/// restart, while the navigation stack is preserved.
enum AppLanguageChoice { system, fr, en }

const _prefsKey = 'app_language_choice';

class LocaleNotifier extends Notifier<AppLanguageChoice> {
  @override
  AppLanguageChoice build() {
    _load();
    return AppLanguageChoice.system;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    state = switch (stored) {
      'fr' => AppLanguageChoice.fr,
      'en' => AppLanguageChoice.en,
      _ => AppLanguageChoice.system,
    };
  }

  Future<void> setChoice(AppLanguageChoice choice) async {
    state = choice;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, switch (choice) {
      AppLanguageChoice.system => 'system',
      AppLanguageChoice.fr => 'fr',
      AppLanguageChoice.en => 'en',
    });
  }
}

final localeChoiceProvider =
    NotifierProvider<LocaleNotifier, AppLanguageChoice>(LocaleNotifier.new);

/// Resolves the choice against the device locale — French device locale -> `fr`;
/// anything else -> `en`.
Locale resolveAppLocale(AppLanguageChoice choice, Locale deviceLocale) {
  switch (choice) {
    case AppLanguageChoice.fr:
      return const Locale('fr');
    case AppLanguageChoice.en:
      return const Locale('en');
    case AppLanguageChoice.system:
      return deviceLocale.languageCode == 'fr'
          ? const Locale('fr')
          : const Locale('en');
  }
}

/// The effective app [Locale], resolved from the stored choice. Widgets
/// needing the ICU locale derive it from
/// `AppLocalizations.of(context).localeName` via `Formatters`.
final effectiveLocaleProvider = Provider<Locale>((ref) {
  final choice = ref.watch(localeChoiceProvider);
  final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
  return resolveAppLocale(choice, deviceLocale);
});
