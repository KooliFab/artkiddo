import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artkiddo_core/artkiddo_core.dart';

class _SeededCaptureController extends CaptureController {
  _SeededCaptureController(super.entry, this.initialState);

  final CaptureState initialState;

  @override
  CaptureState build() => initialState;
}

class _RecordingRescueExport extends VaultRescueExport {
  List<String>? receivedExtraFiles;

  @override
  Future<RescueExportResult> shareRescueArchive({
    List<String> extraFiles = const [],
    RescueProgress? onProgress,
  }) async {
    receivedExtraFiles = extraFiles;
    return const RescueExportResult(
      archives: [],
      includedFiles: 0,
      skippedFiles: 0,
    );
  }
}

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('fr'));
  });

  Widget appWith({
    required Stream<List<Child>> children,
    required Stream<GalleryTilesState> tiles,
  }) {
    return ProviderScope(
      overrides: [
        allChildrenStreamProvider.overrideWith((ref) => children),
        galleryTilesProvider.overrideWith((ref) => tiles),
      ],
      child: MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const GalleryScreen(),
      ),
    );
  }

  testWidgets(
    'gallery read error shows rescue state instead of first-launch state',
    (tester) async {
      await tester.pumpWidget(
        appWith(
          children: Stream<List<Child>>.error(
            Exception('migration failed'),
            StackTrace.current,
          ),
          tiles: Stream<GalleryTilesState>.error(
            Exception('migration failed'),
            StackTrace.current,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(StateBlock), findsOneWidget);
      expect(find.text(l10n.galleryVaultErrorBody), findsOneWidget);
      expect(find.text(l10n.galleryEmptyNoChildTitle), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.text(l10n.vaultRescueExportAction), findsOneWidget);
    },
  );

  testWidgets('a successful empty stream still shows first-launch state', (
    tester,
  ) async {
    await tester.pumpWidget(
      appWith(
        children: Stream.value(const <Child>[]),
        tiles: Stream.value(
          const GalleryTilesState(tiles: <ArtworkTile>[], totalCount: 0),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(l10n.galleryEmptyNoChildTitle), findsOneWidget);
    expect(find.byType(StateBlock), findsNothing);
  });

  testWidgets(
    'capture read error keeps save enabled and offers export of the draft',
    (tester) async {
      tester.view
        ..physicalSize = const Size(400, 800)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      const entry = CaptureEntry(origin: CaptureOrigin.galleryFab);
      const draftPath = '/tmp/artkiddo-in-flight.jpg';
      final rescueExport = _RecordingRescueExport();
      final state = CaptureState(
        step: CaptureStep.details,
        selectedChildId: 'child-1',
        draft: CaptureDraft(
          temporaryImagePath: draftPath,
          startedAt: DateTime(2026, 1, 1),
          cropped: true,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allChildrenStreamProvider.overrideWith(
              (ref) => Stream<List<Child>>.error(
                Exception('migration failed'),
                StackTrace.current,
              ),
            ),
            vaultRescueExportProvider.overrideWithValue(rescueExport),
            captureControllerProvider(
              entry,
            ).overrideWith(() => _SeededCaptureController(entry, state)),
          ],
          child: MaterialApp(
            locale: const Locale('fr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CaptureScreen(entry: entry),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(StateBlock), findsOneWidget);
      expect(find.text(l10n.captureArtistsUnavailableTitle), findsOneWidget);
      expect(find.text(l10n.captureNoChildTitle), findsNothing);
      expect(find.text(l10n.captureSave), findsOneWidget);

      final exportButton = find.text(l10n.vaultRescueExportAction);
      await tester.scrollUntilVisible(exportButton, 300);
      await tester.tap(exportButton);
      await tester.pump();
      expect(rescueExport.receivedExtraFiles, [draftPath]);
    },
  );
}
