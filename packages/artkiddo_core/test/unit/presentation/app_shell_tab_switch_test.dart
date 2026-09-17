// Recovered during T5.1 cleanup: this test existed in artkiddo-cloud before
// the gallery/artwork screens moved into artkiddo_core (T3.4) and was
// dropped by the same commit that deduplicated the cloud test suite,
// without a matching migration. AppShell now lives in the core, so this is
// where the coverage belongs.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:artkiddo_core/artkiddo_core.dart';

void main() {
  late Directory tempRoot;
  late AppDatabase db;
  late LocalVault vault;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempRoot = await Directory.systemTemp.createTemp(
      'artkiddo_app_shell_test_',
    );
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

  testWidgets(
    'the app shell opens directly on the gallery without persistent navigation',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWith((ref) => db),
          localVaultProvider.overrideWith((ref) => vault),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('fr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const AppShell(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ArtKiddo'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsNothing);
    },
  );
}
