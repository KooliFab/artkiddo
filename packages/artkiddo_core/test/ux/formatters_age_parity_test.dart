// Pins `Formatters.age()`, the formatter the app actually uses.
//
// Each case fixes the expected string, in both languages, for a
// (birth, added) pair: any other surface that shows an age must produce
// exactly the same string.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:artkiddo_core/artkiddo_core.dart';

Future<AppLocalizations> _l10n(String languageCode) =>
    AppLocalizations.delegate.load(Locale(languageCode));

void main() {
  group('Formatters.age — chaînes de référence', () {
    test('1 mois exact, français — attendu "1 mois"', () async {
      final l10n = await _l10n('fr');
      final result = Formatters.age(
        l10n,
        birthDate: DateTime(2026, 7, 3),
        addedAt: DateTime(2026, 8, 3),
      );
      expect(result, '1 mois');
    });

    test(
      '1 mois exact, anglais — attendu "1 month" (singulier correct)',
      () async {
        final l10n = await _l10n('en');
        final result = Formatters.age(
          l10n,
          birthDate: DateTime(2026, 7, 3),
          addedAt: DateTime(2026, 8, 3),
        );
        expect(result, '1 month');
      },
    );

    test(
      'avant la naissance, français — attendu "Avant la naissance"',
      () async {
        final l10n = await _l10n('fr');
        final result = Formatters.age(
          l10n,
          birthDate: DateTime(2026, 9, 3),
          addedAt: DateTime(2026, 8, 3),
        );
        expect(result, 'Avant la naissance');
      },
    );

    test('moins de 1 mois, français — attendu "Moins de 1 mois"', () async {
      final l10n = await _l10n('fr');
      final result = Formatters.age(
        l10n,
        birthDate: DateTime(2026, 8, 28),
        addedAt: DateTime(2026, 9, 3),
      );
      expect(result, 'Moins de 1 mois');
    });

    test('jeu de démonstration Léa — attendu "5 ans et 5 mois"', () async {
      final l10n = await _l10n('fr');
      final result = Formatters.age(
        l10n,
        birthDate: DateTime(2021, 3, 14),
        addedAt: DateTime(2026, 9, 3),
      );
      expect(result, '5 ans et 5 mois');
    });

    test('jeu de démonstration Noah — attendu "2 ans et 10 mois"', () async {
      final l10n = await _l10n('fr');
      final result = Formatters.age(
        l10n,
        birthDate: DateTime(2023, 11, 2),
        addedAt: DateTime(2026, 9, 3),
      );
      expect(result, '2 ans et 10 mois');
    });
  });
}
