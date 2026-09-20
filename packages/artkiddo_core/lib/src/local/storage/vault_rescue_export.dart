import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:disk_space_plus/disk_space_plus.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'local_vault_paths.dart';

typedef RescueProgress = void Function(int completed, int total);
typedef RescueReadCheck = Future<bool> Function(File file);
typedef RescueAvailableSpace = Future<int?> Function(Directory directory);

String formatRescueBytes(int bytes, String localeName) {
  final value = bytes / (1024 * 1024 * 1024);
  final unit = localeName.startsWith('fr') ? 'Go' : 'GB';
  return '${NumberFormat.decimalPattern(localeName).format(value)} $unit';
}

class RescueExportInsufficientSpaceException implements Exception {
  final int requiredBytes;
  final int availableBytes;

  const RescueExportInsufficientSpaceException({
    required this.requiredBytes,
    required this.availableBytes,
  });

  @override
  String toString() =>
      'RescueExportInsufficientSpaceException('
      'requiredBytes: $requiredBytes, availableBytes: $availableBytes)';
}

/// The result of a file-only rescue export.
///
/// This type intentionally contains no database rows or metadata. The export
/// must remain usable when the Drift database cannot be opened.
class RescueExportResult {
  final List<File> archives;
  final int includedFiles;
  final int skippedFiles;

  const RescueExportResult({
    required this.archives,
    required this.includedFiles,
    required this.skippedFiles,
  });

  bool get isPartial => skippedFiles > 0;
}

class _RescueFile {
  final File file;
  final String archivePath;
  final int size;

  const _RescueFile({
    required this.file,
    required this.archivePath,
    required this.size,
  });
}

class _RescueCandidate {
  final File file;
  final String archivePath;

  const _RescueCandidate({required this.file, required this.archivePath});
}

/// Creates and shares a ZIP of local vault files without opening AppDatabase.
///
/// The default part budget is deliberately below the classic ZIP 4 GiB limit.
/// Parts are split by byte budget, not by child: child ownership is database
/// metadata and is unavailable during rescue.
class VaultRescueExport {
  static const int defaultPartBudgetBytes = 3_500_000_000;

  final Future<Directory> Function() _documentsDirectoryProvider;
  final Future<Directory> Function() _temporaryDirectoryProvider;
  final RescueReadCheck _canRead;
  final RescueAvailableSpace _availableSpace;
  final int partBudgetBytes;

  VaultRescueExport({
    Future<Directory> Function()? documentsDirectoryProvider,
    Future<Directory> Function()? temporaryDirectoryProvider,
    RescueReadCheck? canRead,
    RescueAvailableSpace? availableSpace,
    this.partBudgetBytes = defaultPartBudgetBytes,
  }) : _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory,
       _temporaryDirectoryProvider =
           temporaryDirectoryProvider ?? getTemporaryDirectory,
       _canRead = canRead ?? _defaultCanRead,
       _availableSpace = availableSpace ?? _defaultAvailableSpace {
    if (partBudgetBytes <= 0) {
      throw ArgumentError.value(
        partBudgetBytes,
        'partBudgetBytes',
        'must be positive',
      );
    }
  }

  /// Exports originals, audio, fallback derivatives, and any explicitly
  /// supplied in-flight files such as a capture draft.
  Future<RescueExportResult> exportRescueArchive({
    List<String> extraFiles = const [],
    RescueProgress? onProgress,
  }) async {
    final documents = await _documentsDirectoryProvider();
    final candidates = await _collectCandidates(documents, extraFiles);
    final prepared = <_RescueFile>[];
    var skippedFiles = 0;

    for (final candidate in candidates) {
      try {
        if (!await candidate.file.exists() || !await _canRead(candidate.file)) {
          skippedFiles++;
          continue;
        }
        prepared.add(
          _RescueFile(
            file: candidate.file,
            archivePath: candidate.archivePath,
            size: await candidate.file.length(),
          ),
        );
      } catch (_) {
        skippedFiles++;
      }
    }

    final temporary = await _temporaryDirectoryProvider();
    final exportDirectory = await Directory(
      p.join(
        temporary.path,
        'artkiddo-rescue-${DateTime.now().microsecondsSinceEpoch}',
      ),
    ).create(recursive: true);
    final parts = _splitIntoParts(prepared);
    final requiredBytes = _estimateRequiredSpace(prepared, parts.length);
    final availableBytes = await _availableSpace(exportDirectory);
    if (availableBytes != null && availableBytes < requiredBytes) {
      await exportDirectory.delete(recursive: true);
      throw RescueExportInsufficientSpaceException(
        requiredBytes: requiredBytes,
        availableBytes: availableBytes,
      );
    }
    final archives = <File>[];
    var completed = 0;
    final total = candidates.length;

    for (var index = 0; index < parts.length; index++) {
      final archiveFile = File(
        p.join(
          exportDirectory.path,
          'artkiddo-secours-${(index + 1).toString().padLeft(3, '0')}.zip',
        ),
      );
      final encoder = ZipFileEncoder();
      encoder.create(archiveFile.path);
      encoder.addArchiveFile(
        ArchiveFile.string(
          'LISEZ-MOI.txt',
          _readme(
            includedFiles: prepared.length,
            skippedFiles: skippedFiles,
            part: index + 1,
            totalParts: parts.length,
          ),
        ),
      );

      for (final source in parts[index]) {
        try {
          await encoder.addFile(source.file, source.archivePath);
          completed++;
          onProgress?.call(completed, total);
        } catch (_) {
          skippedFiles++;
          onProgress?.call(++completed, total);
        }
      }
      await encoder.close();
      archives.add(archiveFile);
    }

    if (parts.isEmpty) {
      final archiveFile = File(
        p.join(exportDirectory.path, 'artkiddo-secours-001.zip'),
      );
      final encoder = ZipFileEncoder()..create(archiveFile.path);
      encoder.addArchiveFile(
        ArchiveFile.string(
          'LISEZ-MOI.txt',
          _readme(
            includedFiles: 0,
            skippedFiles: skippedFiles,
            part: 1,
            totalParts: 1,
          ),
        ),
      );
      await encoder.close();
      archives.add(archiveFile);
    }

    return RescueExportResult(
      archives: archives,
      includedFiles: prepared.length,
      skippedFiles: skippedFiles,
    );
  }

  /// Exports then opens the native share sheet with the generated files.
  Future<RescueExportResult> shareRescueArchive({
    List<String> extraFiles = const [],
    RescueProgress? onProgress,
  }) async {
    final result = await exportRescueArchive(
      extraFiles: extraFiles,
      onProgress: onProgress,
    );
    await SharePlus.instance.share(
      ShareParams(
        files: result.archives.map((file) => XFile(file.path)).toList(),
      ),
    );
    return result;
  }

  Future<List<_RescueCandidate>> _collectCandidates(
    Directory documents,
    List<String> extraFiles,
  ) async {
    final candidates = <_RescueCandidate>[];
    final originals = Directory(
      p.join(documents.path, LocalVaultPaths.masterpiecesFolder),
    );
    final derivatives = Directory(
      p.join(documents.path, LocalVaultPaths.derivativesFolder),
    );
    final audio = Directory(
      p.join(documents.path, LocalVaultPaths.audioFolder),
    );

    final originalIds = <String>{};
    for (final entity in await _filesIn(originals)) {
      final relative = p.relative(entity.path, from: originals.path);
      originalIds.add(p.basenameWithoutExtension(relative));
      candidates.add(
        _RescueCandidate(
          file: entity,
          archivePath: p.posix.join(
            LocalVaultPaths.masterpiecesFolder,
            relative,
          ),
        ),
      );
    }

    for (final entity in await _filesIn(derivatives)) {
      final relative = p.relative(entity.path, from: derivatives.path);
      final base = p.basenameWithoutExtension(relative);
      final id = base.replaceFirst(RegExp(r'_(display|thumb)$'), '');
      if (!originalIds.contains(id)) {
        candidates.add(
          _RescueCandidate(
            file: entity,
            archivePath: p.posix.join(
              LocalVaultPaths.derivativesFolder,
              relative,
            ),
          ),
        );
      }
    }

    for (final entity in await _filesIn(audio)) {
      final relative = p.relative(entity.path, from: audio.path);
      candidates.add(
        _RescueCandidate(
          file: entity,
          archivePath: p.posix.join(LocalVaultPaths.audioFolder, relative),
        ),
      );
    }

    final usedExtraNames = <String>{};
    for (final pathString in extraFiles) {
      final file = File(pathString);
      var filename = p.basename(pathString);
      var suffix = 2;
      while (!usedExtraNames.add(filename)) {
        filename =
            '${p.basenameWithoutExtension(pathString)}-$suffix${p.extension(pathString)}';
        suffix++;
      }
      candidates.add(
        _RescueCandidate(
          file: file,
          archivePath: p.posix.join('en-cours', filename),
        ),
      );
    }

    candidates.sort((a, b) => a.archivePath.compareTo(b.archivePath));
    return candidates;
  }

  Future<List<File>> _filesIn(Directory directory) async {
    if (!await directory.exists()) return const [];
    final files = <File>[];
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) files.add(entity);
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  List<List<_RescueFile>> _splitIntoParts(List<_RescueFile> files) {
    final parts = <List<_RescueFile>>[];
    var current = <_RescueFile>[];
    var currentBytes = 0;
    for (final file in files) {
      if (current.isNotEmpty && currentBytes + file.size > partBudgetBytes) {
        parts.add(current);
        current = <_RescueFile>[];
        currentBytes = 0;
      }
      current.add(file);
      currentBytes += file.size;
    }
    if (current.isNotEmpty) parts.add(current);
    return parts;
  }

  int _estimateRequiredSpace(List<_RescueFile> files, int partCount) {
    final fileBytes = files.fold<int>(0, (total, file) => total + file.size);
    // ZIP headers and the readme are small compared with originals, but the
    // margin prevents a nearly-full volume from failing halfway through.
    return fileBytes + (files.length * 1024) + (partCount * 64 * 1024);
  }

  String _readme({
    required int includedFiles,
    required int skippedFiles,
    required int part,
    required int totalParts,
  }) {
    final partial = skippedFiles == 0
        ? 'Tous les fichiers lisibles ont été inclus.'
        : '$skippedFiles fichier(s) n\'ont pas pu être lu(s) et ne sont pas inclus.';
    return '''ArtKiddo — export de secours

Cette archive contient les fichiers locaux récupérables sans ouvrir le coffre de l'application.
Les noms de fichiers sont des identifiants techniques : les métadonnées (enfant, date, anecdote)
ne sont pas disponibles lorsque le coffre est illisible.

Fichiers inclus : $includedFiles
$partial
Archive $part sur $totalParts.
''';
  }

  static Future<bool> _defaultCanRead(File file) async {
    try {
      await file.openRead(0, 1).drain<void>();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<int?> _defaultAvailableSpace(Directory directory) async {
    try {
      final megabytes = await DiskSpacePlus().getFreeDiskSpaceForPath(
        directory.path,
      );
      if (megabytes == null || !megabytes.isFinite || megabytes < 0) {
        return null;
      }
      return (megabytes * 1024 * 1024).floor();
    } catch (_) {
      // Desktop/test platforms may not provide the mobile plugin. The export
      // remains usable there; callers can inject a strict checker when needed.
      return null;
    }
  }
}
