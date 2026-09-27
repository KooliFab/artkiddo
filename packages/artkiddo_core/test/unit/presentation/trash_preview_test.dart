import 'dart:io';

import 'package:artkiddo_core/artkiddo_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

class _PreviewTrash implements TrashRepository {
  final bool available;
  _PreviewTrash(this.available);
  @override
  Future<ActionResult<List<TrashedArtwork>>> listTrash({
    String? scopeId,
  }) async => ActionSuccess([
    TrashedArtwork(
      id: 'photo',
      childId: 'child',
      childName: 'Lou',
      deletedAt: DateTime(2026),
      purgeAt: DateTime(2026, 2),
      previewPath: available ? 'photo.png' : null,
    ),
  ]);
  @override
  Future<ActionResult<int>> purgeExpired({DateTime? now}) async =>
      const ActionSuccess(0);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final available in [true, false]) {
    testWidgets(
      'trash preview remains usable at 320px (available: $available)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final dir = Directory.systemTemp.createTempSync('trash_preview_');
        File(
          '${dir.path}/photo.png',
        ).writeAsBytesSync(img.encodePng(img.Image(width: 4, height: 4)));
        addTearDown(() => dir.deleteSync(recursive: true));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appCapabilitiesProvider.overrideWithValue(AppCapabilities.local),
              trashRepositoryProvider.overrideWithValue(
                _PreviewTrash(available),
              ),
              localVaultProvider.overrideWithValue(
                LocalVault(documentsDirProvider: () async => dir),
              ),
              familyApiProvider.overrideWith(
                (ref) => throw StateError('no cloud'),
              ),
            ],
            child: MaterialApp(
              locale: const Locale('fr'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const TrashScreen(),
            ),
          ),
        );
        await tester.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(
          tester.element(find.byType(TrashScreen)),
        );
        expect(find.text('Lou'), findsOneWidget);
        if (available) {
          await tester.runAsync(
            () async => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics &&
                  widget.properties.label == l10n.trashPreviewOpen,
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(InteractiveViewer), findsOneWidget);
          await tester.tap(find.text(l10n.commonClose));
          await tester.pumpAndSettle();
          expect(find.byType(Dialog), findsNothing);
        } else {
          expect(find.text(l10n.trashPreviewUnavailable), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  }
}
