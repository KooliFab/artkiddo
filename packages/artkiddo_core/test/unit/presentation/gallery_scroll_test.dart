import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artkiddo_core/artkiddo_core.dart';

/// Regression: scrolling to the end of a long gallery bounced the list back
/// up, so the oldest artworks were unreachable. The feed's extent must be
/// exact, not estimated, so the bottom stays where the finger left it.
void main() {
  const ratios = [0.62, 1.0, 1.55, 0.75, 1.3, 0.9, 1.7, 0.6, 1.2];

  List<ArtworkTile> tiles(int count) => [
    for (var i = 0; i < count; i++)
      () {
        // Spread over six months, newest first, so the old per-month
        // grouping would have produced six stacked grids.
        final addedAt = DateTime(2026, 9, 20).subtract(Duration(days: i));
        final artwork = Artwork(id: 'a$i', childId: 'c1', addedAt: addedAt);
        return ArtworkTile(
          artwork: artwork,
          artworkId: artwork.id,
          childId: 'c1',
          childName: 'Léa',
          imageFile: File(''),
          imageExists: false,
          addedAt: addedAt,
          drawnAt: null,
          age: '5 ans',
          story: null,
          aspectRatio: ratios[i % ratios.length],
        );
      }(),
  ];

  Widget app(List<ArtworkTile> items) => ProviderScope(
    overrides: [
      appCapabilitiesProvider.overrideWithValue(AppCapabilities.local),
      allChildrenStreamProvider.overrideWith(
        (ref) => Stream.value([
          Child(
            id: 'c1',
            name: 'Léa',
            birthDate: DateTime(2021, 3, 14),
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        ]),
      ),
      galleryTilesProvider.overrideWith(
        (ref) => Stream.value(
          GalleryTilesState(tiles: items, totalCount: items.length),
        ),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const GalleryScreen(),
    ),
  );

  testWidgets('the end of a long feed is reachable and stays put', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app(tiles(150)));
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable).first;
    final position = tester.state<ScrollableState>(scrollable).position;

    // Drag in finger-sized steps, as a parent would, until the viewport
    // stops moving: an estimated extent keeps growing or shrinking here.
    var previous = -1.0;
    for (var i = 0; i < 400 && position.pixels != previous; i++) {
      previous = position.pixels;
      await tester.drag(scrollable, const Offset(0, -600));
      await tester.pumpAndSettle();
    }

    final bottom = position.pixels;
    expect(bottom, position.maxScrollExtent);

    // Nothing may pull the viewport back up once the parent stopped.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(position.pixels, bottom);
    expect(position.maxScrollExtent, bottom);

    // And the oldest artwork is on screen.
    expect(
      find.bySemanticsLabel(RegExp('^Dessin de Léa')).evaluate(),
      isNotEmpty,
    );
    final last = find.byWidgetPredicate(
      (w) => w is Hero && w.tag == 'artwork-a149',
    );
    expect(last, findsOneWidget);
  });

  testWidgets('the month shows only while the feed moves', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app(tiles(150)));
    await tester.pumpAndSettle();

    final month = find.textContaining(RegExp(r'^\S+ 2026$'));
    double opacity() => tester
        .widget<AnimatedOpacity>(
          find.ancestor(of: month, matching: find.byType(AnimatedOpacity)),
        )
        .opacity;

    // At rest, at the top: no month over the newest artworks.
    expect(month, findsNothing);

    final gesture = await tester.startGesture(const Offset(195, 600));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(month, findsOneWidget);
    expect(opacity(), 1);

    await gesture.up();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(opacity(), 0);
  });
}
