// Lot 05 (QA) — réponse à la réserve du lot 10 (review-ui-ux.md §5) :
// « le web calcule la date via Intl.DateTimeFormat(dateStyle: 'long') alors
// que le mobile impose le motif `d MMMM y` [...] cohérent, mais obtenu par
// deux chemins différents : à confirmer par la QA plutôt qu'à supposer. »
//
// Exécute Formatters.date() (code réel de l'app) sur un jeu de dates et
// compare à la sortie déjà observée pour Intl.DateTimeFormat(dateStyle:
// 'long') en fr-CA/en-CA (vérifiée séparément dans Chrome, cf. rapport QA :
// "3 septembre 2026" / "September 3, 2026").
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:artkiddo_core/src/presentation/ui/formatters.dart';
import 'package:artkiddo_core/l10n/generated/app_localizations.dart';

Future<AppLocalizations> _l10n(String languageCode) =>
    AppLocalizations.delegate.load(Locale(languageCode));

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_CA');
    await initializeDateFormatting('en_CA');
  });

  group(
    'Formatters.date — parité avec Intl.DateTimeFormat(dateStyle: long) côté web',
    () {
      test('3 septembre 2026, français', () async {
        final l10n = await _l10n('fr');
        expect(Formatters.date(l10n, DateTime(2026, 9, 3)), '3 septembre 2026');
      });

      test('September 3, 2026, anglais', () async {
        final l10n = await _l10n('en');
        expect(
          Formatters.date(l10n, DateTime(2026, 9, 3)),
          'September 3, 2026',
        );
      });

      test(
        '1er du mois, français — vérifie l\'absence de zéro superflu et du "1er"',
        () async {
          final l10n = await _l10n('fr');
          // Intl.DateTimeFormat('fr-CA', {dateStyle:'long'}) rend "1 septembre 2026"
          // (chiffre nu, pas "1er") — cas limite fréquent de divergence FR.
          expect(
            Formatters.date(l10n, DateTime(2026, 9, 1)),
            '1 septembre 2026',
          );
        },
      );

      test(
        '28 août 2026, français (jeu de démonstration qa-fixtures.ts)',
        () async {
          final l10n = await _l10n('fr');
          expect(Formatters.date(l10n, DateTime(2026, 8, 28)), '28 août 2026');
        },
      );
    },
  );
}
