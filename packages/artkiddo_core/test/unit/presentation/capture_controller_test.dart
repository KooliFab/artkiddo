// Unit tests for [CaptureController] — the sensitive transitions called
// out by the lot 08 ticket: draft persistence across a child-creation
// round trip, and the double-tap guard on `save()`.
//
// Reference: `.scratch/aaa-ui-ux/design/contracts.md` §2.4, §2.6, §10 (C6, C7).

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:artkiddo_core/artkiddo_core.dart';

void main() {
  late Directory tempRoot;
  late Directory docsDir;
  late AppDatabase db;
  late LocalVault vault;
  late ProviderContainer container;

  const entry = CaptureEntry(origin: CaptureOrigin.galleryFab);

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp(
      'artkiddo_capture_controller_test_',
    );
    docsDir = Directory(p.join(tempRoot.path, 'docs'));
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
    'draft (photo + story) is identical before and after a child-editor round trip (C6)',
    () async {
      final controller = container.read(
        captureControllerProvider(entry).notifier,
      );
      final file = await makeSourceImage('drawing.jpg');

      await controller.photoPicked(file.path);
      controller.confirmPhoto();
      controller.updateStory('Un dinosaure vert.');

      final before = container.read(captureControllerProvider(entry));
      final beforeStory = before.draft!.story;
      final beforePath = before.draft!.temporaryImagePath;

      // Simulate the round trip to `childEditor` and back with a freshly
      // created child — `contracts.md` §2.3 `childCreated`.
      controller.childCreated('new-child-id', 'Léa');

      final after = container.read(captureControllerProvider(entry));
      expect(
        after.draft!.story,
        beforeStory,
        reason: 'story must survive the childEditor round trip',
      );
      expect(
        after.draft!.temporaryImagePath,
        beforePath,
        reason: 'photo path must survive the round trip',
      );
      expect(after.selectedChildId, 'new-child-id');
      expect(after.childCreatedBanner, 'Léa');
    },
  );

  test(
    'two rapid activations of save() leave only one call actually running (C7)',
    () async {
      final controller = container.read(
        captureControllerProvider(entry).notifier,
      );
      final file = await makeSourceImage('drawing2.jpg');

      await controller.photoPicked(file.path);
      controller.confirmPhoto();
      controller.selectChild(
        'some-child-id',
      ); // does not need to exist for this invariant

      // Fire twice without awaiting the first — the busy transition happens
      // synchronously before the first `await`, so the second call must be
      // a no-op (contracts.md §1.2, §10 C7).
      final first = controller.save();
      final second = controller.save();

      final secondResult = await second;
      await first;

      expect(
        secondResult,
        isA<ActionCancelled<String>>(),
        reason:
            'the second concurrent save() must be ignored, not queued or duplicated',
      );
    },
  );
}
