// The archive screen (L11): a shared ZIP is never presented as a kept backup,
// and a partial export is called partial.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artkiddo_core/artkiddo_core.dart';

class _FakeExporter extends VaultArchiveExporter {
  final Future<VaultArchiveExport> Function() onShare;

  _FakeExporter(AppDatabase db, this.onShare)
    : super(db, LocalVault(), appVersion: 'test');

  @override
  Future<VaultArchiveExport> shareArchive({ArchiveProgress? onProgress}) =>
      onShare();
}

class _FakeImporter extends VaultArchiveImporter {
  final Future<VaultArchiveImportResult> Function() onImport;

  _FakeImporter(AppDatabase db, this.onImport) : super(db, LocalVault());

  @override
  Future<VaultArchiveImportResult> importArchive(File archive) => onImport();
}

const _id = '22222222-2222-4222-8222-222222222222';

VaultArchiveExport _export({List<ArchiveMissing> missing = const []}) =>
    VaultArchiveExport(
      archive: File('export.zip'),
      childCount: 1,
      artworkCount: 2,
      mediaCount: 2,
      missing: missing,
    );

final _keptBackup = RegExp('sauvegard|backup|backed up', caseSensitive: false);

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<AppLocalizations> pump(
    WidgetTester tester, {
    required Locale locale,
    Future<VaultArchiveExport> Function()? onShare,
    Future<VaultArchiveImportResult> Function()? onImport,
    bool withPicker = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultArchiveExporterProvider.overrideWithValue(
            _FakeExporter(db, onShare ?? () async => _export()),
          ),
          vaultArchiveImporterProvider.overrideWithValue(
            _FakeImporter(db, onImport ?? () async => throw StateError('no')),
          ),
          if (withPicker)
            vaultArchivePickerProvider.overrideWithValue(
              () async => File('picked.zip'),
            ),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const VaultArchiveScreen(),
        ),
      ),
    );
    return AppLocalizations.delegate.load(locale);
  }

  for (final locale in const [Locale('fr'), Locale('en')]) {
    group(locale.languageCode, () {
      testWidgets('a complete export never says the data is kept', (
        tester,
      ) async {
        final l10n = await pump(tester, locale: locale);
        await tester.tap(find.text(l10n.vaultArchiveExportAction));
        await tester.pumpAndSettle();

        expect(find.text(l10n.vaultArchiveExportDone), findsOneWidget);
        expect(l10n.vaultArchiveExportDone, isNot(contains(_keptBackup)));
        expect(l10n.vaultArchiveIntro, isNot(contains(_keptBackup)));
        expect(find.textContaining(_keptBackup), findsNothing);
      });

      testWidgets('a partial export says so', (tester) async {
        final l10n = await pump(
          tester,
          locale: locale,
          onShare: () async => _export(
            missing: const [
              ArchiveMissing(
                mediaId: _id,
                role: MediaRole.original,
                path: 'artworks/x.jpg',
              ),
            ],
          ),
        );
        await tester.tap(find.text(l10n.vaultArchiveExportAction));
        await tester.pumpAndSettle();

        expect(find.text(l10n.vaultArchiveExportPartial(1)), findsOneWidget);
        expect(find.text(l10n.vaultArchiveExportDone), findsNothing);
        expect(l10n.vaultArchiveExportPartial(1), isNot(contains(_keptBackup)));
      });

      testWidgets('a failed export is reported', (tester) async {
        final l10n = await pump(
          tester,
          locale: locale,
          onShare: () async => throw const FileSystemException('boom'),
        );
        await tester.tap(find.text(l10n.vaultArchiveExportAction));
        await tester.pumpAndSettle();

        expect(find.text(l10n.vaultArchiveExportFailed), findsOneWidget);
      });

      testWidgets('without a file chooser the import control is absent', (
        tester,
      ) async {
        final l10n = await pump(tester, locale: locale);
        expect(find.text(l10n.vaultArchiveImportAction), findsNothing);
      });

      testWidgets('an import reports what it did, and what it kept aside', (
        tester,
      ) async {
        final l10n = await pump(
          tester,
          locale: locale,
          withPicker: true,
          onImport: () async => const VaultArchiveImportResult(
            addedChildren: 1,
            addedArtworks: 2,
            filesWritten: 2,
            keptAside: 3,
            unchanged: 0,
          ),
        );
        await tester.tap(find.text(l10n.vaultArchiveImportAction));
        await tester.pumpAndSettle();

        expect(
          find.textContaining(l10n.vaultArchiveImportDone(2, 1)),
          findsOneWidget,
        );
        expect(
          find.textContaining(l10n.vaultArchiveImportKeptAside(3)),
          findsOneWidget,
        );
      });

      testWidgets('a refused archive shows its reason', (tester) async {
        final l10n = await pump(
          tester,
          locale: locale,
          withPicker: true,
          onImport: () async => throw const VaultArchiveImportException(
            VaultArchiveFailure.unsupportedVersion,
            'formatVersion 2',
          ),
        );
        await tester.tap(find.text(l10n.vaultArchiveImportAction));
        await tester.pumpAndSettle();

        expect(find.text(l10n.vaultArchiveImportUnsupported), findsOneWidget);
      });

      testWidgets('a re-import of known data says nothing changed', (
        tester,
      ) async {
        final l10n = await pump(
          tester,
          locale: locale,
          withPicker: true,
          onImport: () async => const VaultArchiveImportResult(
            addedChildren: 0,
            addedArtworks: 0,
            filesWritten: 0,
            keptAside: 0,
            unchanged: 5,
          ),
        );
        await tester.tap(find.text(l10n.vaultArchiveImportAction));
        await tester.pumpAndSettle();

        expect(find.text(l10n.vaultArchiveImportNothingNew), findsOneWidget);
      });
    });
  }

  testWidgets('the settings screen reaches the archive screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.tap(find.text('Export and import'));
    await tester.pumpAndSettle();
    expect(find.byType(VaultArchiveScreen), findsOneWidget);
  });
}
