// Backup statuses on screen (L10): the pastille on a gallery card, the line
// of the artwork sheet, and the rule that an artwork purged remotely then
// restored here never reads "Sauvegardé".

import 'dart:io';

import 'package:artkiddo_core/artkiddo_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

const _onDevice = ArtworkBackupStatus(ArtworkBackupState.onDevice);
const _inProgress = ArtworkBackupStatus(ArtworkBackupState.inProgress);
const _saved = ArtworkBackupStatus(ArtworkBackupState.saved);
const _missing = ArtworkBackupStatus(
  ArtworkBackupState.actionNeeded,
  reason: ArtworkBackupReason.missingFile,
);
const _failing = ArtworkBackupStatus(
  ArtworkBackupState.actionNeeded,
  reason: ArtworkBackupReason.repeatedFailure,
);
const _onlyHere = ArtworkBackupStatus(
  ArtworkBackupState.onDevice,
  reason: ArtworkBackupReason.remotePurged,
);

Widget _app(Widget home, {List<Override> overrides = const []}) =>
    ProviderScope(
      // A new scope per call: overrides of a mounted scope are not replaced.
      key: UniqueKey(),
      overrides: overrides,
      child: MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: home),
      ),
    );

const _cloud = AppCapabilities(
  remoteAccount: true,
  remoteBackup: true,
  household: false,
  webGalleryLinks: false,
  trash: TrashCapability.sharedRemote,
);

void main() {
  group('BackupStatusLine', () {
    Future<void> show(WidgetTester tester, ArtworkBackupStatus status) =>
        tester.pumpWidget(_app(BackupStatusLine(status: status)));

    testWidgets('the four states read as the decided labels', (tester) async {
      await show(tester, _onDevice);
      expect(find.text('Sur cet appareil'), findsOneWidget);
      expect(
        find.text('La photo d\'origine reste uniquement sur cet appareil.'),
        findsOneWidget,
      );

      await show(tester, _inProgress);
      expect(find.text('Sauvegarde en cours'), findsOneWidget);

      await show(tester, _saved);
      expect(find.text('Sauvegardé (qualité optimisée)'), findsOneWidget);
      expect(
        find.text('La photo d\'origine reste uniquement sur cet appareil.'),
        findsOneWidget,
        reason: 'saved never means the original is saved',
      );

      await show(tester, _failing);
      expect(find.text('Action nécessaire'), findsOneWidget);
    });

    testWidgets('a missing file is explained and the artwork is kept', (
      tester,
    ) async {
      await show(tester, _missing);
      expect(find.text('Action nécessaire'), findsOneWidget);
      expect(find.textContaining('introuvable'), findsOneWidget);
      expect(find.textContaining('reste dans la galerie'), findsOneWidget);
    });

    testWidgets('an artwork that exists only here never says "Sauvegardé"', (
      tester,
    ) async {
      await show(tester, _onlyHere);
      expect(find.text('Sur cet appareil'), findsOneWidget);
      expect(find.textContaining('n\'existe plus que sur celui-ci'), findsOne);
      expect(find.textContaining('Sauvegardé'), findsNothing);
    });
  });

  group('the card marker', () {
    ArtworkTile tile() {
      final artwork = Artwork(
        id: 'a1',
        childId: 'c1',
        addedAt: DateTime(2026, 1, 1),
      );
      return ArtworkTile(
        artwork: artwork,
        artworkId: artwork.id,
        childId: 'c1',
        childName: 'Léa',
        imageFile: File('/fake'),
        imageExists: false,
        addedAt: artwork.addedAt,
        drawnAt: null,
        age: '4 ans',
        story: null,
        aspectRatio: 1,
      );
    }

    Future<void> pumpTile(
      WidgetTester tester,
      ArtworkBackupStatus status, {
      required AppCapabilities capabilities,
    }) async {
      await tester.pumpWidget(
        _app(
          SizedBox(width: 200, child: MosaicArtworkTile(tile: tile())),
          overrides: [
            appCapabilitiesProvider.overrideWithValue(capabilities),
            artworkBackupStatusesProvider.overrideWith(
              (ref) => Stream.value({'a1': status}),
            ),
          ],
        ),
      );
      await tester.pump();
    }

    testWidgets('each state of a cloud app has its own marker', (tester) async {
      for (final (status, icon, label) in [
        (_onDevice, Icons.smartphone_rounded, 'Sur cet appareil'),
        (_inProgress, Icons.cloud_upload_outlined, 'Sauvegarde en cours'),
        (_saved, Icons.cloud_done_outlined, 'Sauvegardé (qualité optimisée)'),
        (_failing, Icons.error_outline_rounded, 'Action nécessaire'),
      ]) {
        await pumpTile(tester, status, capabilities: _cloud);
        expect(find.byIcon(icon), findsOneWidget, reason: label);
        expect(
          tester
              .widget<BackupStatusBadge>(find.byType(BackupStatusBadge))
              .state,
          status.state,
          reason: label,
        );
      }
    });

    testWidgets('without an account only an action needed is marked', (
      tester,
    ) async {
      await pumpTile(tester, _onDevice, capabilities: AppCapabilities.local);
      expect(find.byType(BackupStatusBadge), findsNothing);

      await pumpTile(tester, _missing, capabilities: AppCapabilities.local);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });
  });

  group('the artwork sheet', () {
    final artwork = Artwork(
      id: 'a1',
      childId: 'c1',
      relativeImagePath: 'artworks/a1.jpg',
      relativeAudioPath: 'audio/a1.m4a',
      audioDurationMs: 4000,
      addedAt: DateTime(2026, 1, 1),
    );

    Future<void> openSheet(
      WidgetTester tester,
      Artwork shown,
      ArtworkBackupStatus status, {
      AppCapabilities capabilities = _cloud,
    }) async {
      final docs = Directory.systemTemp.createTempSync('artkiddo_backup_ui_');
      addTearDown(() => docs.deleteSync(recursive: true));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localVaultProvider.overrideWithValue(
              LocalVault(documentsDirProvider: () async => docs),
            ),
            artworksRepositoryProvider.overrideWithValue(_OneArtwork(shown)),
            allChildrenStreamProvider.overrideWith(
              (ref) => Stream.value([
                Child(
                  id: 'c1',
                  name: 'Léa',
                  birthDate: DateTime(2021, 3, 14),
                  createdAt: DateTime(2026, 1, 1),
                  updatedAt: DateTime(2026, 1, 1),
                ),
              ]),
            ),
            appCapabilitiesProvider.overrideWithValue(capabilities),
            artworkBackupStatusesProvider.overrideWith(
              (ref) => Stream.value({shown.id: status}),
            ),
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
            home: ArtworkScreen(artworkId: shown.id),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('restored after a remote purge: on this device, and the '
        'voice is not said to be backed up', (tester) async {
      // The row is not acknowledged, as a restore leaves it.
      await openSheet(tester, artwork, _onlyHere);

      expect(find.text('Sur cet appareil'), findsOneWidget);
      expect(find.textContaining('n\'existe plus que sur celui-ci'), findsOne);
      expect(find.textContaining('Sauvegardé'), findsNothing);
      expect(find.text('Voix sauvegardée.'), findsNothing);
    });

    testWidgets('a row wrongly marked acknowledged does not make a purged '
        'artwork "saved"', (tester) async {
      await openSheet(
        tester,
        artwork.copyWith(syncState: SyncState.synced),
        _onlyHere,
      );

      expect(find.textContaining('Sauvegardé'), findsNothing);
      expect(find.text('Voix sauvegardée.'), findsNothing);
    });

    testWidgets('acknowledged: saved, voice backed up', (tester) async {
      await openSheet(
        tester,
        artwork.copyWith(syncState: SyncState.synced),
        _saved,
      );

      expect(find.text('Sauvegardé (qualité optimisée)'), findsOneWidget);
      expect(find.text('Voix sauvegardée.'), findsOneWidget);
    });

    testWidgets('no account: on this device, nothing about the cloud', (
      tester,
    ) async {
      await openSheet(
        tester,
        artwork,
        _onDevice,
        capabilities: AppCapabilities.local,
      );

      expect(find.text('Sur cet appareil'), findsOneWidget);
      expect(find.textContaining('Sauvegard'), findsNothing);
    });
  });
}

/// Only what the artwork sheet reads; any other call is a test failure.
class _OneArtwork implements ArtworksRepository {
  final Artwork artwork;
  _OneArtwork(this.artwork);

  @override
  Future<Artwork?> getById(String id) async => artwork;

  @override
  Stream<List<Artwork>> watch({String? childId}) => Stream.value([artwork]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
