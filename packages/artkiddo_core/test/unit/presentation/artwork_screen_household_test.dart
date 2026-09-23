import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:artkiddo_core/artkiddo_core.dart';

/// Only the roster matters here; any other call is a test failure.
class _RosterFamilyApi implements FamilyApi {
  int rosterCalls = 0;

  @override
  Future<List<FamilyMember>> listFamilyMembers() async {
    rosterCalls++;
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Regression: opening an artwork under `household` loaded the family roster
/// from `initState`. The load flips the family controller to busy before its
/// first await, and Riverpod rejects a provider change while the tree is
/// building ("Tried to modify a provider while the widget tree was building").
void main() {
  late Directory tempRoot;
  late AppDatabase db;
  late LocalVault vault;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('artkiddo_artwork_hh_');
    final docsDir = Directory(p.join(tempRoot.path, 'docs'))
      ..createSync(recursive: true);
    db = AppDatabase.forTesting(
      NativeDatabase(File(p.join(tempRoot.path, 'test.sqlite'))),
    );
    vault = LocalVault(documentsDirProvider: () async => docsDir);
  });

  tearDown(() async {
    await db.close();
    if (await tempRoot.exists()) await tempRoot.delete(recursive: true);
  });

  testWidgets('opening an artwork loads the roster after the first frame', (
    tester,
  ) async {
    final api = _RosterFamilyApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((ref) => db),
          localVaultProvider.overrideWith((ref) => vault),
          appCapabilitiesProvider.overrideWithValue(
            const AppCapabilities(
              remoteAccount: false,
              remoteBackup: false,
              household: true,
              webGalleryLinks: false,
              trash: TrashCapability.local,
            ),
          ),
          familyApiProvider.overrideWithValue(api),
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
          home: const ArtworkScreen(artworkId: 'missing'),
        ),
      ),
    );
    await tester.pump();

    // `pumpWidget` ran the first frame and its post-frame callbacks: the
    // roster is requested once, and no provider changed mid-build.
    expect(tester.takeException(), isNull);
    expect(api.rosterCalls, 1);
  });
}
