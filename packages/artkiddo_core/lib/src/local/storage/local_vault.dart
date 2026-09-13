import 'dart:io';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../database/app_database.dart';
import '../logging/log.dart';
import 'image_derivatives.dart';

class DerivativePaths {
  final String? displayRelativePath;
  final String? thumbnailRelativePath;
  const DerivativePaths({this.displayRelativePath, this.thumbnailRelativePath});
}

class LocalVault {
  static const String masterpiecesFolder = 'masterpieces';

  static const String derivativesFolder = 'masterpieces_derivatives';
  static const String audioFolder = 'audio';
  static const int displayMaxDimension = 1600;
  static const int thumbnailMaxDimension = 640;
  static const int maxArtworkCloudBytes = 300000;

  static const int displayJpegQuality = 85;
  static const int thumbnailJpegQuality = 75;

  final Future<Directory> Function() _documentsDirProvider;
  final ImageDerivativeCodec _derivativeCodec;

  LocalVault({
    Future<Directory> Function()? documentsDirProvider,
    ImageDerivativeCodec? derivativeCodec,
  }) : _documentsDirProvider =
           documentsDirProvider ?? getApplicationDocumentsDirectory,
       _derivativeCodec = derivativeCodec ?? const ImageDerivativeCodec();

  Future<Directory> get masterPiecesDirectory async {
    final docsDir = await _documentsDirProvider();
    final dir = Directory(p.join(docsDir.path, masterpiecesFolder));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> get _derivativesDirectory async {
    final docsDir = await _documentsDirProvider();
    final dir = Directory(p.join(docsDir.path, derivativesFolder));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> get audioDirectory async {
    final docsDir = await _documentsDirProvider();
    final dir = Directory(p.join(docsDir.path, audioFolder));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String> storeMasterpieceImage({
    required File sourceFile,
    required String masterpieceId,
  }) async {
    if (sourceFile.path.isEmpty) {
      throw ArgumentError('sourceFile.path must not be empty');
    }
    final targetDir = await masterPiecesDirectory;
    final extension = p.extension(sourceFile.path).isNotEmpty
        ? p.extension(sourceFile.path)
        : '.jpg';
    final targetFileName = '$masterpieceId$extension';
    final targetFile = File(p.join(targetDir.path, targetFileName));

    await sourceFile.copy(targetFile.path);

    return p.join(masterpiecesFolder, targetFileName);
  }

  Future<File> resolveFile(String relativePath) async {
    final docsDir = await _documentsDirProvider();
    return File(p.join(docsDir.path, relativePath));
  }

  Future<void> eraseEverything() async {
    final masterpieces = await masterPiecesDirectory;
    if (await masterpieces.exists()) {
      await masterpieces.delete(recursive: true);
    }
    final derivatives = await _derivativesDirectory;
    if (await derivatives.exists()) {
      await derivatives.delete(recursive: true);
    }
    final audio = await audioDirectory;
    if (await audio.exists()) {
      await audio.delete(recursive: true);
    }
  }

  Future<void> deleteFile(String relativePath) async {
    final file = await resolveFile(relativePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> deleteFileOrEnqueueCleanup({
    required String relativePath,
    required AppDatabase db,
  }) async {
    try {
      await deleteFile(relativePath);
    } catch (e, st) {
      Log.e(
        'Suppression différée : fichier conservé pour une nouvelle tentative',
        e,
        st,
        'Vault',
      );
      await db
          .into(db.pendingFileCleanupsTable)
          .insertOnConflictUpdate(
            PendingFileCleanupsTableCompanion(
              relativePath: Value(relativePath),
              failedAt: Value(DateTime.now()),
            ),
          );
    }
  }

  Future<void> retryPendingCleanups(AppDatabase db) async {
    final pending = await db.select(db.pendingFileCleanupsTable).get();
    for (final entry in pending) {
      try {
        await deleteFile(entry.relativePath);
        await (db.delete(
          db.pendingFileCleanupsTable,
        )..where((t) => t.relativePath.equals(entry.relativePath))).go();
      } catch (e, st) {
        Log.e(
          'Nouvelle tentative de nettoyage impossible (${entry.relativePath})',
          e,
          st,
          'Vault',
        );
      }
    }
  }

  Future<DerivativePaths> generateDerivatives({
    required String masterpieceId,
    required String originalRelativePath,
  }) async {
    final originalFile = await resolveFile(originalRelativePath);
    if (!await originalFile.exists()) {
      return const DerivativePaths();
    }

    Uint8List bytes;
    try {
      bytes = await originalFile.readAsBytes();
    } catch (e, st) {
      Log.e(
        'Lecture de l’original impossible ($masterpieceId)',
        e,
        st,
        'Derivatives',
      );
      return const DerivativePaths();
    }

    Map<String, Uint8List> resized;
    try {
      resized = await _derivativeCodec.resizeMany(bytes, const [
        ImageDerivativeSpec(
          key: 'display',
          maxDimension: displayMaxDimension,
          quality: displayJpegQuality,
          maxBytes: maxArtworkCloudBytes,
        ),
        ImageDerivativeSpec(
          key: 'thumb',
          maxDimension: thumbnailMaxDimension,
          quality: thumbnailJpegQuality,
        ),
      ]);
    } catch (e, st) {
      Log.e(
        'Génération des dérivés impossible ($masterpieceId)',
        e,
        st,
        'Derivatives',
      );
      resized = const {};
    }

    final display = await _writeDerivativeBytes(
      resized['display'],
      masterpieceId: masterpieceId,
      suffix: 'display',
    );
    final thumbnail = await _writeDerivativeBytes(
      resized['thumb'],
      masterpieceId: masterpieceId,
      suffix: 'thumb',
    );
    return DerivativePaths(
      displayRelativePath: display,
      thumbnailRelativePath: thumbnail,
    );
  }

  Future<String?> generateThumbnailFromDisplay({
    required String masterpieceId,
    required String displayRelativePath,
  }) async {
    final displayFile = await resolveFile(displayRelativePath);
    if (!await displayFile.exists()) return null;

    Uint8List bytes;
    try {
      bytes = await displayFile.readAsBytes();
    } catch (e, st) {
      Log.e(
        'Lecture de l’image display impossible ($masterpieceId)',
        e,
        st,
        'Derivatives',
      );
      return null;
    }

    Map<String, Uint8List> resized;
    try {
      resized = await _derivativeCodec.resizeMany(bytes, const [
        ImageDerivativeSpec(
          key: 'thumb',
          maxDimension: thumbnailMaxDimension,
          quality: thumbnailJpegQuality,
        ),
      ]);
    } catch (e, st) {
      Log.e(
        'Génération de la miniature depuis display impossible ($masterpieceId)',
        e,
        st,
        'Derivatives',
      );
      resized = const {};
    }

    return _writeDerivativeBytes(
      resized['thumb'],
      masterpieceId: masterpieceId,
      suffix: 'thumb',
    );
  }

  Future<String?> _writeDerivativeBytes(
    Uint8List? bytes, {
    required String masterpieceId,
    required String suffix,
  }) async {
    if (bytes == null) return null;
    try {
      final dir = await _derivativesDirectory;
      final fileName = '${masterpieceId}_$suffix.jpg';
      final targetFile = File(p.join(dir.path, fileName));
      final tmpFile = File('${targetFile.path}.tmp');
      await tmpFile.writeAsBytes(bytes, flush: true);
      await tmpFile.rename(targetFile.path);
      return p.join(derivativesFolder, fileName);
    } catch (e, st) {
      Log.e(
        'Écriture du dérivé $suffix impossible ($masterpieceId)',
        e,
        st,
        'Derivatives',
      );
      return null;
    }
  }

  Future<String> storeDownloadedDerivative({
    required List<int> bytes,
    required String masterpieceId,
    required bool isDisplay,
  }) async {
    final dir = await _derivativesDirectory;
    final suffix = isDisplay ? 'display' : 'thumb';
    final fileName = '${masterpieceId}_$suffix.jpg';
    final targetFile = File(p.join(dir.path, fileName));
    final tmpFile = File('${targetFile.path}.tmp');
    await tmpFile.writeAsBytes(bytes, flush: true);
    await tmpFile.rename(targetFile.path);
    return p.join(derivativesFolder, fileName);
  }

  Future<void> deleteDerivativeFilesOrEnqueueCleanup({
    required String? displayRelativePath,
    required String? thumbnailRelativePath,
    required AppDatabase db,
  }) async {
    if (displayRelativePath != null) {
      await deleteFileOrEnqueueCleanup(
        relativePath: displayRelativePath,
        db: db,
      );
    }
    if (thumbnailRelativePath != null) {
      await deleteFileOrEnqueueCleanup(
        relativePath: thumbnailRelativePath,
        db: db,
      );
    }
  }

  Future<String> storeMasterpieceAudio({
    required File sourceFile,
    required String masterpieceId,
    int version = 1,
  }) async {
    if (sourceFile.path.isEmpty) {
      throw ArgumentError('sourceFile.path must not be empty');
    }
    final targetDir = await audioDirectory;
    final extension = p.extension(sourceFile.path).isNotEmpty
        ? p.extension(sourceFile.path)
        : '.m4a';
    final targetFileName = '${masterpieceId}_v$version$extension';
    final targetFile = File(p.join(targetDir.path, targetFileName));

    final tmpFile = File('${targetFile.path}.tmp');
    await sourceFile.copy(tmpFile.path);
    await tmpFile.rename(targetFile.path);

    return p.join(audioFolder, targetFileName);
  }

  Future<String> storeDownloadedAudio({
    required List<int> bytes,
    required String masterpieceId,
    int version = 1,
  }) async {
    final targetDir = await audioDirectory;
    final targetFileName = '${masterpieceId}_v$version.m4a';
    final targetFile = File(p.join(targetDir.path, targetFileName));

    final tmpFile = File('${targetFile.path}.tmp');
    await tmpFile.writeAsBytes(bytes, flush: true);
    await tmpFile.rename(targetFile.path);

    return p.join(audioFolder, targetFileName);
  }

  Future<void> deleteAudioFileOrEnqueueCleanup({
    required String? relativeAudioPath,
    required AppDatabase db,
  }) async {
    if (relativeAudioPath != null) {
      await deleteFileOrEnqueueCleanup(relativePath: relativeAudioPath, db: db);
    }
  }
}
