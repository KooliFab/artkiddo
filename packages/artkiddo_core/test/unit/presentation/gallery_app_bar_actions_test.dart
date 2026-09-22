import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artkiddo_core/artkiddo_core.dart';

/// The gallery app bar mixes two kinds of control, and the whole point of
/// this suite is that they never blur into one another:
///
/// * capability-gated (share, sync) — absent unless the capability is on
///   *and* the composition bound the action;
/// * local-default (people, settings) — always present, because each has an
///   account-free destination inside this package.
void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('fr'));
  });

  Widget appWith({
    CompositionActions actions = const CompositionActions(),
    AppCapabilities capabilities = AppCapabilities.local,
    List<Child> children = const <Child>[],
  }) {
    return ProviderScope(
      overrides: [
        compositionActionsProvider.overrideWithValue(actions),
        appCapabilitiesProvider.overrideWithValue(capabilities),
        allChildrenStreamProvider.overrideWith((ref) => Stream.value(children)),
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

  Child child(String id, String name) => Child(
    id: id,
    name: name,
    birthDate: DateTime(2021, 3, 14),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  group('local-default controls', () {
    testWidgets('settings and people are reachable in the account-free build, '
        'which binds no composition action at all', (tester) async {
      await tester.pumpWidget(appWith());
      await tester.pump();

      expect(find.byTooltip(l10n.settingsTitle), findsOneWidget);
      // No household in this build, so the people control names what it
      // actually opens: the children list.
      expect(find.byTooltip(l10n.childrenTitle), findsOneWidget);
      expect(find.byTooltip(l10n.familyTitle), findsNothing);
    });

    testWidgets('openSettings substitutes the destination without changing '
        'whether the control exists', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        appWith(actions: CompositionActions(openSettings: (_) => calls++)),
      );
      await tester.pump();

      await tester.tap(find.byTooltip(l10n.settingsTitle));
      await tester.pump();
      expect(calls, 1);
    });

    testWidgets('openFamilyHub relabels the people control to "Famille"', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        appWith(actions: CompositionActions(openFamilyHub: (_) => calls++)),
      );
      await tester.pump();

      expect(find.byTooltip(l10n.familyTitle), findsOneWidget);
      expect(find.byTooltip(l10n.childrenTitle), findsNothing);

      await tester.tap(find.byTooltip(l10n.familyTitle));
      await tester.pump();
      expect(calls, 1);
    });
  });

  group('capability-gated controls', () {
    testWidgets('no sync control without the remoteBackup capability, even '
        'when the action is bound', (tester) async {
      await tester.pumpWidget(
        appWith(actions: CompositionActions(syncPhotos: (_) {})),
      );
      await tester.pump();

      expect(find.byIcon(Icons.cloud_sync_outlined), findsNothing);
    });

    testWidgets('no sync control with the capability but no bound action', (
      tester,
    ) async {
      await tester.pumpWidget(appWith(capabilities: AppCapabilities.cloud));
      await tester.pump();

      expect(find.byIcon(Icons.cloud_sync_outlined), findsNothing);
    });

    testWidgets('sync appears when capability and action agree', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        appWith(
          capabilities: AppCapabilities.cloud,
          actions: CompositionActions(syncPhotos: (_) => calls++),
        ),
      );
      await tester.pump();

      final button = find.byTooltip(l10n.gallerySyncPhotos);
      expect(button, findsOneWidget);
      await tester.tap(button);
      await tester.pump();
      expect(calls, 1);
    });

    testWidgets('no share control in the account-free build', (tester) async {
      await tester.pumpWidget(appWith(children: [child('c1', 'Léa')]));
      await tester.pump();

      expect(find.byIcon(Icons.ios_share_outlined), findsNothing);
    });
  });

  group('share placement', () {
    // Regression: share lived in the filter bar, which only renders with two
    // or more children — so a one-child household had no way to share a
    // gallery link at all.
    testWidgets('share is reachable with a single child', (tester) async {
      await tester.pumpWidget(
        appWith(
          capabilities: AppCapabilities.cloud,
          actions: CompositionActions(openGalleryShare: (_, _, _) {}),
          children: [child('c1', 'Léa')],
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.ios_share_outlined), findsOneWidget);
      expect(
        tester.widget<TextButton>(find.byType(TextButton)).onPressed,
        isNotNull,
        reason: 'one artist and a readable vault means sharing is possible',
      );
    });

    testWidgets('share is disabled, not hidden, when there is no artist yet', (
      tester,
    ) async {
      await tester.pumpWidget(
        appWith(
          capabilities: AppCapabilities.cloud,
          actions: CompositionActions(openGalleryShare: (_, _, _) {}),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.ios_share_outlined), findsOneWidget);
      expect(
        tester.widget<TextButton>(find.byType(TextButton)).onPressed,
        isNull,
      );
    });
  });

  testWidgets('orders the app bar actions share, sync, people, settings', (
    tester,
  ) async {
    await tester.pumpWidget(
      appWith(
        capabilities: AppCapabilities.cloud,
        actions: CompositionActions(
          openGalleryShare: (_, _, _) {},
          openFamilyHub: (_) {},
          openSettings: (_) {},
          syncPhotos: (_) {},
        ),
        children: [child('c1', 'Léa')],
      ),
    );
    await tester.pump();

    double left(IconData icon) => tester.getTopLeft(find.byIcon(icon)).dx;

    expect(
      left(Icons.ios_share_outlined),
      lessThan(left(Icons.cloud_sync_outlined)),
    );
    expect(
      left(Icons.cloud_sync_outlined),
      lessThan(left(Icons.people_outline)),
    );
    expect(left(Icons.people_outline), lessThan(left(Icons.settings_outlined)));
  });
}
