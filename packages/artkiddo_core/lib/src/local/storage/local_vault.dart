import 'dart:io';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../database/app_database.dart';
import '../logging/log.dart';
import 'image_derivatives.dart';
import 'local_vault_paths.dart';

/// Result of [LocalVault.generateDerivatives]: either relative path is
/// `null` when that particular derivative could not be produced (a
/// corrupt or unreadable original, a decode failure, a write failure).
/// The original file is never touched regardless of the outcome.
class DerivativePaths {
  final String? displayRelativePath;
  final String? thumbnailRelativePath;
  const DerivativePaths({this.displayRelativePath, this.thumbnailRelativePath});
}

/// Manages the private sandbox file storage for artwork photos and
/// audio. Guarantees files are safely stored inside the app sandbox,
/// independently from the device's own photo gallery.
class LocalVault {
  static const String artworksFolder = LocalVaultPaths.artworksFolder;

  /// Bounded-dimension derivatives kept alongside the untouched
  /// original — `display` for the artwork detail screen (1600px), and
  /// `thumbnail` for the gallery grid (640px, matching the
  /// `cacheWidth` clamp already used by the grid's own tiles, so the
  /// thumbnail is never upscaled at any column width/DPR combination
  /// in use today).
  static const String derivativesFolder = LocalVaultPaths.derivativesFolder;
  static const String audioFolder = LocalVaultPaths.audioFolder;
  static const int displayMaxDimension = 1600;
  static const int thumbnailMaxDimension = 640;
  static const int maxArtworkCloudBytes = 300000;

  /// JPEG quality (1-100), chosen for *reading*, not archiving — the
  /// original stays untouched and is what the zoom screen and any
  /// future export always read. 85 for `display`: the accepted
  /// "visually lossless for photographic content" floor, used
  /// full-screen on the artwork detail. 75 for `thumbnail`: displayed
  /// at a few hundred device-independent pixels at most in the grid,
  /// where artifacts at that quality are not perceptible, so the
  /// lower bound trades a little more fidelity for the
  /// disproportionately larger share of derivative storage/bandwidth
  /// the many-small-tiles grid represents.
  static const int displayJpegQuality = 85;
  static const int thumbnailJpegQuality = 75;

  /// Overridable for tests: defaults to the real app documents
  /// directory.
  final Future<Directory> Function() _documentsDirProvider;
  final ImageDerivativeCodec _derivativeCodec;

  LocalVault({
    Future<Directory> Function()? documentsDirProvider,
    ImageDerivativeCodec? derivativeCodec,
  }) : _documentsDirProvider =
           documentsDirProvider ?? getApplicationDocumentsDirectory,
       _derivativeCodec = derivativeCodec ?? const ImageDerivativeCodec();

  /// The documents directory used by this vault. Exposed for file-only
  /// recovery services that must share the vault's injected test location.
  Future<Directory> get documentsDirectory => _documentsDirProvider();

  /// Retrieves the directory where full-resolution photos are stored.
  Future<Directory> get artworksDirectory async {
    final docsDir = await _documentsDirProvider();
    final dir = Directory(p.join(docsDir.path, artworksFolder));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Retrieves the directory where derivatives are stored — separate
  /// from [artworksDirectory] so that deleting an artwork's
  /// originals folder entry, or reasoning about what's an original vs.
  /// a cache, is never ambiguous.
  Future<Directory> get _derivativesDirectory async {
    final docsDir = await _documentsDirProvider();
    final dir = Directory(p.join(docsDir.path, derivativesFolder));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Retrieves the derivative directory without opening the database.
  Future<Directory> get derivativesDirectory => _derivativesDirectory;

  /// Retrieves the directory where audio recordings are stored.
  Future<Directory> get audioDirectory async {
    final docsDir = await _documentsDirProvider();
    final dir = Directory(p.join(docsDir.path, audioFolder));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Copies a captured image file into the vault using a permanent
  /// filename. Returns the relative file path from the app documents
  /// directory for easy persistence. Throws a [FileSystemException]
  /// (or subtype) if the copy fails — callers must not treat a thrown
  /// copy as a success.
  Future<String> storeArtworkImage({
    required File sourceFile,
    required String artworkId,
  }) async {
    if (sourceFile.path.isEmpty) {
      throw ArgumentError('sourceFile.path must not be empty');
    }
    final targetDir = await artworksDirectory;
    final extension = p.extension(sourceFile.path).isNotEmpty
        ? p.extension(sourceFile.path)
        : '.jpg';
    final targetFileName = '$artworkId$extension';
    final targetFile = File(p.join(targetDir.path, targetFileName));

    await sourceFile.copy(targetFile.path);

    // Store relative path (e.g. "artworks/uuid.jpg") so it survives
    // app container migrations.
    return p.join(artworksFolder, targetFileName);
  }

  /// Resolves a stored relative path to a concrete File.
  Future<File> resolveFile(String relativePath) async {
    final docsDir = await _documentsDirProvider();
    return File(p.join(docsDir.path, relativePath));
  }

  /// The "erase local data" half of account deletion — requires no
  /// network, and must succeed even if a remote deletion request has
  /// already failed or never ran. Removes every original and
  /// derivative image and audio recording this vault holds; a missing
  /// directory is not an error (idempotent, same discipline as
  /// [deleteFile]). Does not touch the Drift database — the caller is
  /// responsible for clearing [AppDatabase]'s own tables alongside
  /// this, since this class has no reference to it.
  Future<void> eraseEverything() async {
    final artworks = await artworksDirectory;
    if (await artworks.exists()) {
      await artworks.delete(recursive: true);
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

  /// Erases all artwork photos and their derivatives from the vault.
  /// Audio files are preserved.
  Future<void> eraseAllArtworkPhotos() async {
    final artworks = await artworksDirectory;
    if (await artworks.exists()) {
      await artworks.delete(recursive: true);
    }
    final derivatives = await _derivativesDirectory;
    if (await derivatives.exists()) {
      await derivatives.delete(recursive: true);
    }
  }

  /// Deletes a file from the vault. A missing file is not an error
  /// (idempotent). Throws if the file exists but cannot be removed.
  Future<void> deleteFile(String relativePath) async {
    final file = await resolveFile(relativePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Deletes a file, recording a [PendingFileCleanupsTable] entry
  /// instead of throwing when the deletion fails. This is the
  /// recovery strategy required by the durability contract: a failed
  /// file cleanup must never turn an otherwise-successful durable
  /// operation into a failure, but it must also never be silently
  /// forgotten.
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

  /// Retries every pending cleanup entry, silently. Intended to be
  /// called once at app startup. Entries that still fail are left in
  /// place for the next attempt.
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

  /// (Re)builds the `display` and `thumbnail` derivatives for the
  /// original at [originalRelativePath], writing them under
  /// [derivativesFolder]. Never reads or writes
  /// [originalRelativePath] itself beyond the initial read — the
  /// original is only ever a source.
  ///
  /// Both derivatives are requested from a single
  /// [ImageDerivativeCodec] call so the original is decoded only once
  /// (in the background isolate `resizeMany` runs in) rather than
  /// twice.
  ///
  /// File names are deterministic (`<artworkId>_display.jpg` /
  /// `<artworkId>_thumb.jpg`), so calling this twice for the same
  /// artwork overwrites the same two paths rather than
  /// accumulating orphans — the idempotence a backfill pass requires.
  /// Each derivative is attempted independently: a failure on one
  /// (corrupt original, decode error, disk full) leaves that one
  /// `null` in the result without preventing the other from
  /// succeeding, and never throws — the original file and its
  /// database row are untouched either way; a derivative is a cache,
  /// not a reference copy.
  Future<DerivativePaths> generateDerivatives({
    required String artworkId,
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
        'Lecture de l’original impossible ($artworkId)',
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
        'Génération des dérivés impossible ($artworkId)',
        e,
        st,
        'Derivatives',
      );
      resized = const {};
    }

    final display = await _writeDerivativeBytes(
      resized['display'],
      artworkId: artworkId,
      suffix: 'display',
    );
    final thumbnail = await _writeDerivativeBytes(
      resized['thumb'],
      artworkId: artworkId,
      suffix: 'thumb',
    );
    return DerivativePaths(
      displayRelativePath: display,
      thumbnailRelativePath: thumbnail,
    );
  }

  /// Regenerates the local thumbnail from a downloaded display image
  /// derivative.
  Future<String?> generateThumbnailFromDisplay({
    required String artworkId,
    required String displayRelativePath,
  }) async {
    final displayFile = await resolveFile(displayRelativePath);
    if (!await displayFile.exists()) return null;

    Uint8List bytes;
    try {
      bytes = await displayFile.readAsBytes();
    } catch (e, st) {
      Log.e(
        'Lecture de l’image display impossible ($artworkId)',
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
        'Génération de la miniature depuis display impossible ($artworkId)',
        e,
        st,
        'Derivatives',
      );
      resized = const {};
    }

    return _writeDerivativeBytes(
      resized['thumb'],
      artworkId: artworkId,
      suffix: 'thumb',
    );
  }

  Future<String?> _writeDerivativeBytes(
    Uint8List? bytes, {
    required String artworkId,
    required String suffix,
  }) async {
    if (bytes == null) return null;
    try {
      final dir = await _derivativesDirectory;
      final fileName = '${artworkId}_$suffix.jpg';
      final targetFile = File(p.join(dir.path, fileName));
      // Write-then-rename: a crash mid-write never leaves a half-written
      // file at the path callers will read from.
      final tmpFile = File('${targetFile.path}.tmp');
      await tmpFile.writeAsBytes(bytes, flush: true);
      await tmpFile.rename(targetFile.path);
      return p.join(derivativesFolder, fileName);
    } catch (e, st) {
      Log.e(
        'Écriture du dérivé $suffix impossible ($artworkId)',
        e,
        st,
        'Derivatives',
      );
      return null;
    }
  }

  /// Writes bytes downloaded from the remote side as one of a
  /// artwork's derivatives — the counterpart, on the pull side, of
  /// [generateDerivatives] on the capture side. Uses the exact same
  /// deterministic naming (`<artworkId>_display.jpg` /
  /// `<artworkId>_thumb.jpg`) so a downloaded derivative and a
  /// locally generated one are indistinguishable to every reader —
  /// neither `Artwork.bestDisplayImagePath` nor the gallery grid
  /// needs to know which source produced the file at the path they
  /// read.
  Future<String> storeDownloadedDerivative({
    required List<int> bytes,
    required String artworkId,
    required bool isDisplay,
  }) async {
    final dir = await _derivativesDirectory;
    final suffix = isDisplay ? 'display' : 'thumb';
    final fileName = '${artworkId}_$suffix.jpg';
    final targetFile = File(p.join(dir.path, fileName));
    // Write-then-rename, same rationale as [_writeDerivativeBytes]: a
    // crash mid-download never leaves a half-written file at the path
    // callers will read from.
    final tmpFile = File('${targetFile.path}.tmp');
    await tmpFile.writeAsBytes(bytes, flush: true);
    await tmpFile.rename(targetFile.path);
    return p.join(derivativesFolder, fileName);
  }

  /// Counterpart to [deleteFileOrEnqueueCleanup] for an artwork's
  /// derivatives: called from `delete()` alongside the original's
  /// cleanup. Either argument may be `null` (no derivative was ever
  /// generated) — a no-op in that case.
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

  /// Stores a captured audio file into the vault using a versioned
  /// filename. Uses a temporary write followed by an atomic rename so
  /// an interrupted write never leaves a partial file at the readable
  /// path.
  Future<String> storeArtworkAudio({
    required File sourceFile,
    required String artworkId,
    int version = 1,
  }) async {
    if (sourceFile.path.isEmpty) {
      throw ArgumentError('sourceFile.path must not be empty');
    }
    final targetDir = await audioDirectory;
    final extension = p.extension(sourceFile.path).isNotEmpty
        ? p.extension(sourceFile.path)
        : '.m4a';
    final targetFileName = '${artworkId}_v$version$extension';
    final targetFile = File(p.join(targetDir.path, targetFileName));

    // Temp write + atomic rename: an interrupted write never leaves a
    // partial file at the readable path.
    final tmpFile = File('${targetFile.path}.tmp');
    await sourceFile.copy(tmpFile.path);
    await tmpFile.rename(targetFile.path);

    return p.join(audioFolder, targetFileName);
  }

  /// Writes downloaded audio bytes into the vault with a versioned
  /// filename, using temporary file writing and atomic rename.
  Future<String> storeDownloadedAudio({
    required List<int> bytes,
    required String artworkId,
    int version = 1,
  }) async {
    final targetDir = await audioDirectory;
    final targetFileName = '${artworkId}_v$version.m4a';
    final targetFile = File(p.join(targetDir.path, targetFileName));

    final tmpFile = File('${targetFile.path}.tmp');
    await tmpFile.writeAsBytes(bytes, flush: true);
    await tmpFile.rename(targetFile.path);

    return p.join(audioFolder, targetFileName);
  }

  /// Deletes an audio file from the vault or enqueues deferred
  /// cleanup.
  Future<void> deleteAudioFileOrEnqueueCleanup({
    required String? relativeAudioPath,
    required AppDatabase db,
  }) async {
    if (relativeAudioPath != null) {
      await deleteFileOrEnqueueCleanup(relativePath: relativeAudioPath, db: db);
    }
  }
}
