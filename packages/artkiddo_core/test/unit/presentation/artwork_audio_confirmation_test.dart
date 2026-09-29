import 'dart:io';
import 'package:artkiddo_core/artkiddo_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _ArtworkRepo implements ArtworksRepository {
  _ArtworkRepo({required bool cached})
    : artwork = Artwork(
        id: 'a',
        childId: 'c',
        addedAt: DateTime(2026),
        relativeAudioPath: cached ? 'voice.m4a' : null,
        audioDurationMs: 1000,
      );
  final Artwork artwork;
  @override
  Future<Artwork?> getById(String id) async => artwork;
  @override
  Stream<List<Artwork>> watch({String? childId}) => Stream.value([artwork]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final cached in [true, false]) {
    testWidgets(
      're-record confirms replacement and cancellation preserves voice (cached: $cached)',
      (tester) async {
        tester.view.physicalSize = const Size(390, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final dir = Directory.systemTemp.createTempSync('audio_ui_');
        File('${dir.path}/voice.m4a').writeAsBytesSync([1, 2]);
        addTearDown(() => dir.deleteSync(recursive: true));
        final repo = _ArtworkRepo(cached: cached);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appCapabilitiesProvider.overrideWithValue(AppCapabilities.local),
              localVaultProvider.overrideWithValue(
                LocalVault(documentsDirProvider: () async => dir),
              ),
              artworksRepositoryProvider.overrideWithValue(repo),
              allChildrenStreamProvider.overrideWith((ref) => Stream.value([])),
              audioPlayerServiceProvider.overrideWithValue(
                FakeAudioPlayerService(),
              ),
              audioRecorderServiceProvider.overrideWithValue(
                FakeAudioRecorderService(),
              ),
            ],
            child: MaterialApp(
              locale: const Locale('fr'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const ArtworkScreen(artworkId: 'a'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final label = AppLocalizations.of(
          tester.element(find.byType(ArtworkScreen)),
        );
        await tester.ensureVisible(find.text(label.captureAudioReRecord).last);
        await tester.tap(find.text(label.captureAudioReRecord).last);
        await tester.pumpAndSettle();
        expect(
          find.text(label.captureAudioReRecordConfirmBody),
          findsOneWidget,
        );
        await tester.tap(find.text(label.commonCancel));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(repo.artwork.audioDurationMs, 1000);
        expect(find.text(label.artworkAudioBackupPending), findsNothing);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  }
}
