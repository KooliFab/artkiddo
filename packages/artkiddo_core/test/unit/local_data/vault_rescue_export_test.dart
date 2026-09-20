import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:artkiddo_core/artkiddo_core.dart';

void main() {
  late Directory root;
  late Directory documents;
  late Directory temporary;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('artkiddo_rescue_export_');
    documents = Directory(p.join(root.path, 'documents'))
      ..createSync(recursive: true);
    temporary = Directory(p.join(root.path, 'temporary'))
      ..createSync(recursive: true);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<File> write(String relativePath, String contents) async {
    final file = File(p.join(documents.path, relativePath));
    await file.parent.create(recursive: true);
    return file..writeAsStringSync(contents);
  }

  Future<Set<String>> archiveNames(RescueExportResult result) async {
    final names = <String>{};
    for (final archiveFile in result.archives) {
      final archive = ZipDecoder().decodeBytes(await archiveFile.readAsBytes());
      names.addAll(archive.files.map((file) => file.name));
    }
    return names;
  }

  test(
    'exports originals, fallback derivatives, audio, and an in-flight file',
    () async {
      await write('masterpieces/one.jpg', 'original');
      await write('masterpieces_derivatives/one_display.jpg', 'cached-copy');
      await write('masterpieces_derivatives/two_display.jpg', 'fallback');
      await write('audio/two.m4a', 'voice');
      final draft = File(p.join(root.path, 'draft.jpg'))
        ..writeAsStringSync('in-flight');

      final result = await VaultRescueExport(
        documentsDirectoryProvider: () async => documents,
        temporaryDirectoryProvider: () async => temporary,
      ).exportRescueArchive(extraFiles: [draft.path]);

      expect(result.includedFiles, 4);
      expect(result.skippedFiles, 0);
      expect(await archiveNames(result), {
        'LISEZ-MOI.txt',
        'masterpieces/one.jpg',
        'masterpieces_derivatives/two_display.jpg',
        'audio/two.m4a',
        'en-cours/draft.jpg',
      });
    },
  );

  test(
    'counts an unreadable file and continues with a valid archive',
    () async {
      final good = await write('masterpieces/good.jpg', 'good');
      final bad = await write('masterpieces/bad.jpg', 'bad');

      final result = await VaultRescueExport(
        documentsDirectoryProvider: () async => documents,
        temporaryDirectoryProvider: () async => temporary,
        canRead: (file) async => file.path != bad.path,
      ).exportRescueArchive();

      expect(result.includedFiles, 1);
      expect(result.skippedFiles, 1);
      expect(await archiveNames(result), {
        'LISEZ-MOI.txt',
        p.posix.join('masterpieces', p.basename(good.path)),
      });
    },
  );

  test('splits parts by byte budget rather than child metadata', () async {
    await write('masterpieces/one.jpg', '12345');
    await write('masterpieces/two.jpg', '67890');

    final result = await VaultRescueExport(
      documentsDirectoryProvider: () async => documents,
      temporaryDirectoryProvider: () async => temporary,
      partBudgetBytes: 5,
    ).exportRescueArchive();

    expect(result.archives, hasLength(2));
    expect(await archiveNames(result), {
      'LISEZ-MOI.txt',
      'masterpieces/one.jpg',
      'masterpieces/two.jpg',
    });
  });

  test(
    'refuses before writing when the temporary volume is too full',
    () async {
      await write('masterpieces/large.jpg', '12345');

      final result = VaultRescueExport(
        documentsDirectoryProvider: () async => documents,
        temporaryDirectoryProvider: () async => temporary,
        availableSpace: (directory) async => 1,
      );

      await expectLater(
        result.exportRescueArchive(),
        throwsA(isA<RescueExportInsufficientSpaceException>()),
      );
      expect(
        temporary.listSync().whereType<Directory>(),
        isEmpty,
        reason:
            'no archive directory should remain after the preflight refusal',
      );
    },
  );
}
