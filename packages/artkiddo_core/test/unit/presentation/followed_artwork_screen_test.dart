import 'package:artkiddo_core/artkiddo_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app(FollowedArtwork artwork, FakeAudioPlayerService player) =>
      ProviderScope(
        overrides: [audioPlayerServiceProvider.overrideWithValue(player)],
        child: MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FollowedArtworkScreen(artwork: artwork),
        ),
      );

  testWidgets('shows the child, the household and the story, read-only', (
    tester,
  ) async {
    final player = FakeAudioPlayerService();
    await tester.pumpWidget(
      app(
        FollowedArtwork(
          id: 'a1',
          familyId: 'f1',
          familyName: 'Anne',
          childId: 'tom',
          childName: 'Tom',
          addedAt: DateTime(2026, 10, 12),
          story: 'Un dragon',
          audioUri: Uri.parse('https://media.example.test/a1.m4a'),
          audioDuration: const Duration(seconds: 4),
        ),
        player,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tom'), findsOneWidget);
    expect(find.text('Famille Anne'), findsOneWidget);
    expect(find.text('« Un dragon »'), findsOneWidget);
    expect(player.currentUri, Uri.parse('https://media.example.test/a1.m4a'));

    // Nothing that edits, deletes, records or shares.
    for (final icon in [
      Icons.edit_outlined,
      Icons.delete_outline_rounded,
      Icons.mic_none_rounded,
      Icons.ios_share_rounded,
    ]) {
      expect(find.byIcon(icon), findsNothing);
    }
  });

  testWidgets('an unnamed household and a missing image are stated', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        FollowedArtwork(
          id: 'a2',
          familyId: 'f1',
          familyName: null,
          childId: 'tom',
          childName: 'Tom',
          addedAt: DateTime(2026, 10, 12),
        ),
        FakeAudioPlayerService(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Famille suivie'), findsOneWidget);
    expect(
      find.text("L'image de ce dessin n'est pas disponible pour le moment."),
      findsOneWidget,
    );
  });
}
