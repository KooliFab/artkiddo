// Regression tests for D02/D03/D09 in `CaptureController`
// (`.scratch/aaa-ui-ux/review-ui-ux.md`):
//
// - D09: `save()` gated on `!state.save.isIdle`, so a failed save left the
//   state `ActionError` forever and "Réessayer" became permanently inert.
// - D03: the step-3 Retour handler called `retakePhoto()` for a *blank*
//   draft too, which cleared the draft and sent the user to the dead
//   step-1 screen instead of back to step 2 with the photo intact.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:artkiddo_core/artkiddo_core.dart';

void main() {
  late Directory tempRoot;
  late AppDatabase db;
  late LocalVault vault;
  late ProviderContainer container;
  late String childId;

  const entry = CaptureEntry(origin: CaptureOrigin.galleryFab);

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp(
      'artkiddo_capture_regression_test_',
    );
    final docsDir = Directory(p.join(tempRoot.path, 'docs'));
    await docsDir.create(recursive: true);
    db = AppDatabase.forTesting(
      NativeDatabase(File(p.join(tempRoot.path, 'test.sqlite'))),
    );
    vault = LocalVault(documentsDirProvider: () async => docsDir);

    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWith((ref) => db),
        localVaultProvider.overrideWith((ref) => vault),
      ],
    );

    // Foreign key on `childId` — a real row is required for save() to
    // succeed (PRAGMA foreign_keys = ON).
    final childrenRepo = DriftChildrenRepository(db, vault);
    final childResult = await childrenRepo.create(
      name: 'Léa',
      birthDate: DateTime(2021, 3, 14),
    );
    childId = (childResult as ActionSuccess<String>).value;
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    if (await tempRoot.exists()) await tempRoot.delete(recursive: true);
  });

  Future<File> makeSourceImage(String name) async {
    final file = File(p.join(tempRoot.path, name));
    await file.writeAsString('fake-bytes');
    return file;
  }

  test(
    'save() stays retryable after a failure — "Réessayer" is not inert forever (D09)',
    () async {
      final controller = container.read(
        captureControllerProvider(entry).notifier,
      );
      final file = await makeSourceImage('drawing.jpg');

      await controller.photoPicked(file.path);
      controller.confirmPhoto();
      controller.selectChild(childId);

      // Force the first attempt to fail: the source file the draft points
      // at is gone by the time `save()` reads it.
      await file.delete();
      final first = await controller.save();
      expect(first, isA<ActionFailed<String>>());
      expect(
        container.read(captureControllerProvider(entry)).save,
        isA<ActionError>(),
        reason: 'state must be ActionError, not reset to idle, after a failure',
      );

      // Recreate the file (as if the user freed up space / fixed whatever
      // failed) and press "Réessayer" again. The old `isIdle` guard made
      // this a permanent no-op once the state was `ActionError`.
      await file.writeAsString('fake-bytes');
      final retry = await controller.save();
      expect(
        retry,
        isA<ActionSuccess<String>>(),
        reason:
            'a retry after a failed save must actually run, not be silently ignored',
      );
    },
  );

  test(
    'Retour from a blank step-3 draft returns to step 2 with the photo intact (D03)',
    () async {
      final controller = container.read(
        captureControllerProvider(entry).notifier,
      );
      final file = await makeSourceImage('drawing2.jpg');

      await controller.photoPicked(file.path);
      controller.confirmPhoto();

      final before = container.read(captureControllerProvider(entry));
      expect(before.step, CaptureStep.details);
      expect(
        before.isDirty,
        isFalse,
        reason:
            'no manual artist choice and an empty anecdote is the "blank draft" case',
      );
      final draftPath = before.draft!.temporaryImagePath;

      // This is what `capture_screen.dart`'s `_handleBack` calls for the
      // blank-draft branch of `navigation.md` §3.
      controller.backToReviewFromDetails();

      final after = container.read(captureControllerProvider(entry));
      expect(
        after.step,
        CaptureStep.review,
        reason: 'must land on step 2, not the dead step-1 screen',
      );
      expect(
        after.draft,
        isNotNull,
        reason:
            'the draft must survive — the old retakePhoto() call destroyed it',
      );
      expect(after.draft!.temporaryImagePath, draftPath);
      expect(
        await File(draftPath).exists(),
        isTrue,
        reason: 'the photo file itself must not be deleted',
      );
    },
  );

  test(
    'a manually selected artist makes the step-3 draft dirty (D04 precondition for D03)',
    () async {
      final controller = container.read(
        captureControllerProvider(entry).notifier,
      );
      final file = await makeSourceImage('drawing3.jpg');

      await controller.photoPicked(file.path);
      controller.confirmPhoto();
      expect(container.read(captureControllerProvider(entry)).isDirty, isFalse);

      controller.selectChild(childId);
      expect(
        container.read(captureControllerProvider(entry)).isDirty,
        isTrue,
        reason:
            'a manual artist choice must make the draft dirty, unlike an automatic preselection',
      );
    },
  );
}
