// Covers two more sensitive transitions named by the lot 08 ticket:
// genuine anecdote erasure (not just an omitted field), and that a
// failure result never leaks a raw exception string to the presentation
// layer.
//
// Reference: `.scratch/aaa-ui-ux/design/contracts.md` §1.3, §4.2, §6,
// §10 (C1).

import 'dart:io';
import 'dart:ui';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:artkiddo_core/artkiddo_core.dart';

void main() {
  late Directory tempRoot;
  late AppDatabase db;
  late LocalVault vault;
  late MasterpiecesRepository repo;
  late String childId;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('artkiddo_artwork_story_test_');
    final docsDir = Directory(p.join(tempRoot.path, 'docs'));
    await docsDir.create(recursive: true);
    db = AppDatabase.forTesting(NativeDatabase(File(p.join(tempRoot.path, 'test.sqlite'))));
    vault = LocalVault(documentsDirProvider: () async => docsDir);
    repo = DriftMasterpiecesRepository(db, vault);

    // The masterpieces table has a foreign key on childId (PRAGMA
    // foreign_keys = ON), so a real child row is required first.
    final childrenRepo = DriftChildrenRepository(db, vault);
    final childResult = await childrenRepo.create(name: 'Léa', birthDate: DateTime(2021, 3, 14));
    childId = (childResult as ActionSuccess<String>).value;
  });

  tearDown(() async {
    await db.close();
    if (await tempRoot.exists()) await tempRoot.delete(recursive: true);
  });

  test('clearing a story (updateStory(null)) durably erases it, not merely omits it', () async {
    final sourceFile = File(p.join(tempRoot.path, 'source.jpg'));
    await sourceFile.writeAsString('bytes');

    final createResult = await repo.create(
      childId: childId,
      sourceImageFile: sourceFile,
      addedAt: DateTime(2026, 9, 1),
      story: 'Un dinosaure vert.',
    );
    final id = (createResult as ActionSuccess<String>).value;

    final clearResult = await repo.updateStory(id: id, story: null);
    expect(clearResult, isA<ActionSuccess<void>>());

    final reread = await repo.getById(id);
    expect(reread!.story, isNull, reason: 'the anecdote must be genuinely erased, not left unchanged');

    // copyWith() called with no argument must still preserve the
    // (already-null) value rather than resurrecting the old text.
    final unchanged = reread.copyWith();
    expect(unchanged.story, isNull);
  });

  test('a presented failure never contains the raw exception text', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('fr'));
    const failure = LocalWriteFailure(cause: 'SqliteException(1): near line 42: no such table: oops');

    final presented = ErrorPresenter.present(l10n, failure);

    expect(presented.title, isNot(contains('SqliteException')));
    expect(presented.body ?? '', isNot(contains('SqliteException')));
    expect(presented.title, l10n.errorLocalWriteTitle);
  });

  test('updating audio replaces previous audio atomically without touching story', () async {
    final sourceImg = File(p.join(tempRoot.path, 'source_img.jpg'));
    await sourceImg.writeAsString('image-bytes');
    final audio1 = File(p.join(tempRoot.path, 'voice1.m4a'));
    await audio1.writeAsString('voice-bytes-1');

    final createResult = await repo.create(
      childId: childId,
      sourceImageFile: sourceImg,
      sourceAudioFile: audio1,
      audioDurationMs: 12000,
      addedAt: DateTime(2026, 9, 1),
      story: 'Mon histoire',
    );
    final id = (createResult as ActionSuccess<String>).value;

    final initial = await repo.getById(id);
    expect(initial!.hasAudio, isTrue);
    expect(initial.audioDurationMs, 12000);
    expect(initial.story, 'Mon histoire');
    final oldAudioPath = initial.relativeAudioPath!;

    // Atomic replacement with audio2
    final audio2 = File(p.join(tempRoot.path, 'voice2.m4a'));
    await audio2.writeAsString('voice-bytes-2');

    final updateResult = await repo.updateAudio(
      id: id,
      sourceAudioFile: audio2,
      durationMs: 25000,
    );
    expect(updateResult, isA<ActionSuccess<void>>());

    final updated = await repo.getById(id);
    expect(updated!.hasAudio, isTrue);
    expect(updated.audioDurationMs, 25000);
    expect(updated.relativeAudioPath, isNot(oldAudioPath));
    expect(updated.story, 'Mon histoire', reason: 'Story is preserved when audio is updated');

    // Clear audio
    final clearResult = await repo.clearAudio(id);
    expect(clearResult, isA<ActionSuccess<void>>());

    final cleared = await repo.getById(id);
    expect(cleared!.hasAudio, isFalse);
    expect(cleared.audioDurationMs, isNull);
    expect(cleared.relativeAudioPath, isNull);
    expect(cleared.story, 'Mon histoire', reason: 'Story is still preserved when audio is cleared');
  });
}
