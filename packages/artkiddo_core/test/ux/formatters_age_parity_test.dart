// Lot 05 (QA) — C21/C22 (contracts.md §10) contre le code réellement utilisé
// par l'app, `Formatters.age()` (lib/core/ui/formatters.dart), et non contre
// `AgeCalculator` (lib/core/utils/age_calculator.dart), qui n'est référencé
// nulle part dans lib/ hors de son propre fichier — voir le rapport QA,
// « AgeCalculator est du code mort testé par erreur ».
//
// Chaque cas ici a un équivalent calculé à la main dans
// `web/src/components/GalleryApp.astro` (fonction `formatAge`), pour
// vérifier C22 : même chaîne, mêmes deux langues, même couple
// (naissance, ajout).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:artkiddo_core/artkiddo_core.dart';

Future<AppLocalizations> _l10n(String languageCode) =>
    AppLocalizations.delegate.load(Locale(languageCode));

void main() {
  group('Formatters.age — parité avec la galerie web (C21/C22)', () {
    test('1 mois exact, français — web dit "1 mois"', () async {
      final l10n = await _l10n('fr');
      final result = Formatters.age(
        l10n,
        birthDate: DateTime(2026, 7, 3),
        addedAt: DateTime(2026, 8, 3),
      );
      expect(result, '1 mois');
    });

    test(
      '1 mois exact, anglais — web dit "1 month" (singulier correct)',
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
      'avant la naissance, français — web dit "Avant la naissance"',
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

    test('moins de 1 mois, français — web dit "Moins de 1 mois"', () async {
      final l10n = await _l10n('fr');
      final result = Formatters.age(
        l10n,
        birthDate: DateTime(2026, 8, 28),
        addedAt: DateTime(2026, 9, 3),
      );
      expect(result, 'Moins de 1 mois');
    });

    test(
      'jeu de démonstration Léa (qa-fixtures.ts) — web dit "5 ans et 5 mois"',
      () async {
        final l10n = await _l10n('fr');
        final result = Formatters.age(
          l10n,
          birthDate: DateTime(2021, 3, 14),
          addedAt: DateTime(2026, 9, 3),
        );
        expect(result, '5 ans et 5 mois');
      },
    );

    test(
      'jeu de démonstration Noah (qa-fixtures.ts) — web dit "2 ans et 10 mois"',
      () async {
        final l10n = await _l10n('fr');
        final result = Formatters.age(
          l10n,
          birthDate: DateTime(2023, 11, 2),
          addedAt: DateTime(2026, 9, 3),
        );
        expect(result, '2 ans et 10 mois');
      },
    );
  });
}
