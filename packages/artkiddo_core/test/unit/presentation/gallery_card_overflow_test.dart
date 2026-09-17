// Preuve d'absence de debordement pour D30 et D46
// (`.scratch/aaa-ui-ux/review-ui-ux.md`).
//
// Le lead demandait une capture de la galerie a 2 colonnes, filtre « Tous »,
// anecdote de 2 lignes, aux facteurs de texte 1,0 et 2,0. Une assertion
// automatisee est une preuve plus forte qu'une image : elle couvre plusieurs
// largeurs et facteurs, elle est reproductible, et elle echoue au prochain
// changement de mise en page au lieu de vieillir en silence.
//
// Flutter leve une exception de rendu des qu'un `RenderFlex` deborde ; le
// test echoue donc si la carte ne tient pas dans la hauteur que la grille
// lui alloue.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artkiddo_core/artkiddo_core.dart';

void main() {
  // Configuration par defaut signalee par D46 : filtre « Tous », donc le nom
  // de l'enfant est affiche a cote du badge d'age en deux parties, ce qui
  // fait passer le badge a la ligne ; plus une anecdote de deux lignes.
  Widget card() => ArtworkCard(
    childName: 'Lea',
    ageLabel: '5 ans et 5 mois',
    dateLabel: 'Ajoute le 3 septembre 2026',
    story: "C'est notre maison, avec le chat sur le toit et un tres grand soleil derriere",
    imageFile: null,
    imageExists: false,
    cacheWidth: 400,
    semanticLabel: 'Dessin de Lea, ajoute le 3 septembre 2026',
    imageMissingLabel: 'Image introuvable',
    onTap: () {},
  );

  // Largeurs de la spec : 320 et 390 en compact (2 colonnes), 834 en
  // tablette (4 colonnes). Facteurs de 1,0 au maximum supporte de 2,0.
  const layouts = <(double, int)>[(320, 2), (390, 2), (834, 4)];
  const scales = <double>[1.0, 1.3, 1.6, 2.0];

  for (final layout in layouts) {
    for (final scale in scales) {
      testWidgets('la carte tient dans sa cellule a ${layout.$1.toInt()} dp, facteur $scale', (tester) async {
        final width = layout.$1;
        final columns = layout.$2;
        // Memes valeurs que la grille de production.
        final margin = width < 600 ? 16.0 : 24.0;
        final gutter = width < 600 ? 12.0 : 16.0;
        final columnWidth = (width - margin * 2 - gutter * (columns - 1)) / columns;
        final extent = galleryCellExtent(columnWidth, scale);

        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: MaterialApp(
              home: Scaffold(
                body: Center(
                  child: SizedBox(width: columnWidth, height: extent, child: card()),
                ),
              ),
            ),
          ),
        );

        // Un debordement de rendu est remonte comme exception par le binding.
        expect(tester.takeException(), isNull);
      });
    }
  }
}
