import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

final effectiveLocaleProvider = Provider<Locale>((ref) {
  final choice = ref.watch(localeChoiceProvider);
  final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
  return resolveAppLocale(choice, deviceLocale);
});
