import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artkiddo_core/artkiddo_core.dart';

/// Global settings are reachable from the gallery's own app bar (top right),
/// not from inside the family hub — but only when the composition actually
/// offers a settings destination.
void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('fr'));
  });

  Widget appWith(CompositionActions actions) {
    return ProviderScope(
      overrides: [
        compositionActionsProvider.overrideWithValue(actions),
        allChildrenStreamProvider.overrideWith(
          (ref) => Stream.value(const <Child>[]),
        ),
        galleryTilesProvider.overrideWith(
          (ref) => Stream.value(
            const GalleryTilesState(tiles: <ArtworkTile>[], totalCount: 0),
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
  }

  testWidgets('renders no settings control when the composition offers no '
      'openSettings destination', (tester) async {
    await tester.pumpWidget(appWith(const CompositionActions()));
    await tester.pump();

    expect(find.byTooltip(l10n.settingsTitle), findsNothing);
    expect(find.byIcon(Icons.settings_outlined), findsNothing);
  });

  testWidgets('renders a settings control that invokes openSettings', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      appWith(CompositionActions(openSettings: (context) => calls++)),
    );
    await tester.pump();

    final button = find.byTooltip(l10n.settingsTitle);
    expect(button, findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

    await tester.tap(button);
    await tester.pump();
    expect(calls, 1);
  });

  testWidgets('the family control is labelled "Famille" now that settings '
      'has its own button', (tester) async {
    await tester.pumpWidget(
      appWith(
        CompositionActions(
          openFamilyHub: (context) {},
          openSettings: (context) {},
        ),
      ),
    );
    await tester.pump();

    expect(find.byTooltip(l10n.familyTitle), findsOneWidget);
    expect(find.byTooltip(l10n.settingsTitle), findsOneWidget);
    expect(find.byTooltip(l10n.familyHubFamilyAndSettings), findsNothing);
  });

  testWidgets('renders no sync control when the composition offers no '
      'syncPhotos action', (tester) async {
    await tester.pumpWidget(appWith(const CompositionActions()));
    await tester.pump();

    expect(find.byTooltip(l10n.familyHubSyncPhotos), findsNothing);
    expect(find.byIcon(Icons.cloud_sync_outlined), findsNothing);
  });

  testWidgets('renders a sync control that invokes syncPhotos', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      appWith(CompositionActions(syncPhotos: (context) => calls++)),
    );
    await tester.pump();

    final button = find.byTooltip(l10n.familyHubSyncPhotos);
    expect(button, findsOneWidget);
    expect(find.byIcon(Icons.cloud_sync_outlined), findsOneWidget);

    await tester.tap(button);
    await tester.pump();
    expect(calls, 1);
  });

  testWidgets('orders the app bar actions sync, family, settings', (
    tester,
  ) async {
    await tester.pumpWidget(
      appWith(
        CompositionActions(
          openFamilyHub: (context) {},
          openSettings: (context) {},
          syncPhotos: (context) {},
        ),
      ),
    );
    await tester.pump();

    double left(IconData icon) => tester.getTopLeft(find.byIcon(icon)).dx;

    expect(
      left(Icons.cloud_sync_outlined),
      lessThan(left(Icons.people_outline)),
    );
    expect(left(Icons.people_outline), lessThan(left(Icons.settings_outlined)));
  });
}
