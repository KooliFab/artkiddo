import 'dart:async';

import 'package:artkiddo_core/artkiddo_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _DeleteRepo implements ArtworksRepository {
  bool deleted = false;
  final artwork = Artwork(
    id: 'photo',
    childId: 'child',
    addedAt: DateTime(2026),
    syncState: SyncState.downloadFailed,
  );
  @override
  Future<Artwork?> getById(String id) async => artwork;
  @override
  Stream<List<Artwork>> watch({String? childId}) => Stream.value([artwork]);
  @override
  Future<ActionResult<void>> delete(String id) async {
    deleted = true;
    return const ActionSuccess(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final backup in [true, false]) {
    testWidgets(
      'durable deletion schedules backup without waiting (backup: $backup)',
      (tester) async {
        tester.view.physicalSize = const Size(390, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final repo = _DeleteRepo();
        final remote = Completer<void>();
        var scheduled = 0;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appCapabilitiesProvider.overrideWithValue(
                AppCapabilities(
                  remoteAccount: false,
                  remoteBackup: backup,
                  household: false,
                  webGalleryLinks: false,
                  trash: backup
                      ? TrashCapability.sharedRemote
                      : TrashCapability.local,
                ),
              ),
              artworksRepositoryProvider.overrideWithValue(repo),
              allChildrenStreamProvider.overrideWith((ref) => Stream.value([])),
              compositionActionsProvider.overrideWithValue(
                CompositionActions(
                  onArtworkDeleted: (id) async {
                    expect(repo.deleted, true);
                    expect(id, 'photo');
                    scheduled++;
                    await remote.future;
                  },
                ),
              ),
            ],
            child: MaterialApp(
              locale: const Locale('fr'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ArtworkScreen(artworkId: 'photo'),
                      ),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(
          tester.element(find.byType(ArtworkScreen)),
        );
        await tester.tap(find.byTooltip(l10n.artworkDelete));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.commonDelete));
        await tester.pumpAndSettle();
        expect(repo.deleted, true);
        expect(scheduled, backup ? 1 : 0);
        expect(find.text('Open'), findsOneWidget);
        remote.complete();
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
