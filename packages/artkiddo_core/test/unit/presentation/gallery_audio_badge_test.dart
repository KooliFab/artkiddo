import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:artkiddo_core/artkiddo_core.dart';

void main() {
  testWidgets('ArtworkCard affiche l’icône micro quand hasAudio est true', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 200,
              child: ArtworkCard(
                childName: 'Lea',
                ageLabel: '5 ans',
                dateLabel: 'Aujourd’hui',
                story: 'Mon dessin',
                imageFile: null,
                imageExists: false,
                cacheWidth: 400,
                semanticLabel: 'Dessin de Lea',
                imageMissingLabel: 'Image introuvable',
                onTap: () {},
                hasAudio: true,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
  });

  testWidgets(
    'ArtworkCard n’affiche pas l’icône micro quand hasAudio est false',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 200,
                child: ArtworkCard(
                  childName: 'Lea',
                  ageLabel: '5 ans',
                  dateLabel: 'Aujourd’hui',
                  story: 'Mon dessin',
                  imageFile: null,
                  imageExists: false,
                  cacheWidth: 400,
                  semanticLabel: 'Dessin de Lea',
                  imageMissingLabel: 'Image introuvable',
                  onTap: () {},
                  hasAudio: false,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.mic_rounded), findsNothing);
    },
  );

  test(
    'ArtworkTile.hasAudio reflète fidèlement la présence d’un audio sur le chef-d’œuvre',
    () {
      final withoutAudio = Artwork(
        id: 'm1',
        childId: 'c1',
        addedAt: DateTime(2026, 1, 1),
      );
      final withAudio = Artwork(
        id: 'm2',
        childId: 'c1',
        addedAt: DateTime(2026, 1, 1),
        audioDurationMs: 4200,
      );

      final tileNoAudio = ArtworkTile(
        artwork: withoutAudio,
        artworkId: withoutAudio.id,
        childId: 'c1',
        childName: 'Leo',
        imageFile: File('/fake'),
        imageExists: false,
        addedAt: withoutAudio.addedAt,
        drawnAt: null,
        age: '4 ans',
        story: null,
        aspectRatio: 1.0,
      );

      final tileWithAudio = ArtworkTile(
        artwork: withAudio,
        artworkId: withAudio.id,
        childId: 'c1',
        childName: 'Leo',
        imageFile: File('/fake'),
        imageExists: false,
        addedAt: withAudio.addedAt,
        drawnAt: null,
        age: '4 ans',
        story: null,
        aspectRatio: 1.0,
      );

      expect(tileNoAudio.hasAudio, isFalse);
      expect(tileWithAudio.hasAudio, isTrue);
    },
  );

  testWidgets(
    'Long press sur la tuile déclenche le zoom et démarre l’audio jusqu’au relâchement',
    (tester) async {
      final fakePlayer = FakeAudioPlayerService();
      final tempDir = Directory.systemTemp.createTempSync(
        'artkiddo_peek_test_',
      );
      final dummyAudioFile = File('${tempDir.path}/test_audio.m4a');
      dummyAudioFile.writeAsBytesSync(List.filled(200, 0));

      final artworkWithAudio = Artwork(
        id: 'm1',
        childId: 'c1',
        addedAt: DateTime(2026, 1, 1),
        relativeAudioPath: 'test_audio.m4a',
        audioDurationMs: 3000,
      );

      final tile = ArtworkTile(
        artwork: artworkWithAudio,
        artworkId: 'm1',
        childId: 'c1',
        childName: 'Leo',
        imageFile: File('${tempDir.path}/test.jpg'),
        imageExists: false,
        addedAt: artworkWithAudio.addedAt,
        drawnAt: null,
        age: '4 ans',
        story: 'Mon super dessin',
        aspectRatio: 1.0,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioPlayerServiceProvider.overrideWithValue(fakePlayer),
            localVaultProvider.overrideWithValue(
              LocalVault(documentsDirProvider: () async => tempDir),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 200,
                  child: MosaicArtworkTile(tile: tile),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Vérifier présence du badge audio
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(Hero).first),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 200));

      expect(fakePlayer.isPlaying, isTrue);

      // The peek names when and by whom above the artwork. No `drawnAt`
      // here, so it says the date is the day the artwork was added.
      expect(find.text('Added on January 1, 2026'), findsOneWidget);
      expect(find.text('Leo · 4 ans'), findsOneWidget);
      expect(find.text("Leo's voice"), findsOneWidget);

      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));

      expect(fakePlayer.isPlaying, isFalse);

      tempDir.deleteSync(recursive: true);
    },
  );
}
