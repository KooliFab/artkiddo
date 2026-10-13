import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:disk_space_plus/disk_space_plus.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../contracts/sync_protocol.dart';
import '../database/app_database.dart';
import '../logging/log.dart';
import 'file_digest.dart';
import 'local_vault.dart';
import 'vault_archive_manifest.dart';
import 'vault_rescue_export.dart' show RescueExportInsufficientSpaceException;

typedef ArchiveProgress = void Function(int completed, int total);
typedef ArchiveAvailableSpace = Future<int?> Function(Directory directory);
typedef ArchiveShare = Future<void> Function(File archive);

/// The result of [VaultArchiveExporter.exportArchive].
class VaultArchiveExport {
  final File archive;
  final int childCount;
  final int artworkCount;

  /// Files written in the archive.
  final int mediaCount;

  /// Files the vault references but the archive could not take. A partial
  /// export must be said as such, never presented as complete.
  final List<ArchiveMissing> missing;

  const VaultArchiveExport({
    required this.archive,
    required this.childCount,
    required this.artworkCount,
    required this.mediaCount,
    required this.missing,
  });

  bool get isPartial => missing.isNotEmpty;
}

/// Writes the complete export: one ZIP holding `manifest.json` and every
/// media file under `media/`.
///
/// This is the database-backed archive. The file-only rescue export
/// (`VaultRescueExport`) stays the way out when the database cannot be
/// opened.
///
/// Creating the archive keeps nothing safe by itself: [shareArchive] only
/// hands the file to the system share sheet, and where it ends up is the
/// parent's choice. No caller may present it as a kept backup.
class VaultArchiveExporter {
  final AppDatabase _db;
  final LocalVault _vault;

  /// Written in the manifest.
  final String appVersion;
  final DateTime Function() _now;
  final Future<Directory> Function() _temporaryDirectoryProvider;
  final ArchiveAvailableSpace _availableSpace;
  final ArchiveShare _share;

  VaultArchiveExporter(
    this._db,
    this._vault, {
    required this.appVersion,
    DateTime Function()? now,
    Future<Directory> Function()? temporaryDirectoryProvider,
    ArchiveAvailableSpace? availableSpace,
    ArchiveShare? share,
  }) : _now = now ?? DateTime.now,
       _temporaryDirectoryProvider =
           temporaryDirectoryProvider ?? getTemporaryDirectory,
       _availableSpace = availableSpace ?? _defaultAvailableSpace,
       _share = share ?? _defaultShare;

  /// Builds the archive in the temporary directory.
  ///
  /// Throws [RescueExportInsufficientSpaceException] before writing anything
  /// when the volume is too small.
  Future<VaultArchiveExport> exportArchive({
    ArchiveProgress? onProgress,
  }) async {
    final plan = await _plan();
    final temporary = await _temporaryDirectoryProvider();
    final exportedAt = _now();
    final directory = await Directory(
      p.join(
        temporary.path,
        'artkiddo-export-${exportedAt.microsecondsSinceEpoch}',
      ),
    ).create(recursive: true);

    try {
      final required = plan.totalBytes + plan.files.length * 1024 + 64 * 1024;
      final available = await _availableSpace(directory);
      if (available != null && available < required) {
        throw RescueExportInsufficientSpaceException(
          requiredBytes: required,
          availableBytes: available,
        );
      }

      final archive = File(
        p.join(directory.path, 'artkiddo-export-${_stamp(exportedAt)}.zip'),
      );
      final encoder = ZipFileEncoder()..create(archive.path);
      final media = <ArchiveMedia>[];
      final missing = [...plan.missing];
      var completed = 0;
      try {
        for (final source in plan.files) {
          final entry = await _addFile(encoder, source);
          if (entry == null) {
            missing.add(source.asMissing);
          } else {
            media.add(entry);
          }
          onProgress?.call(++completed, plan.files.length);
        }
        final manifest = VaultArchiveManifest(
          exportedAt: exportedAt,
          appVersion: appVersion,
          partial: missing.isNotEmpty,
          missing: missing,
          children: plan.children,
          artworks: plan.artworks,
          media: media,
        );
        encoder.addArchiveFile(
          ArchiveFile.string(kVaultArchiveManifestName, manifest.encode()),
        );
      } finally {
        await encoder.close();
      }
      return VaultArchiveExport(
        archive: archive,
        childCount: plan.children.length,
        artworkCount: plan.artworks.length,
        mediaCount: media.length,
        missing: missing,
      );
    } catch (_) {
      await directory.delete(recursive: true);
      rethrow;
    }
  }

  /// Builds the archive, then opens the system share sheet on it.
  Future<VaultArchiveExport> shareArchive({ArchiveProgress? onProgress}) async {
    final result = await exportArchive(onProgress: onProgress);
    await _share(result.archive);
    return result;
  }

  /// Hashes [source] while it is read, then streams it into the ZIP. A file
  /// that cannot be read or added is reported by returning `null`.
  Future<ArchiveMedia?> _addFile(
    ZipFileEncoder encoder,
    _SourceFile source,
  ) async {
    try {
      if (!await source.file.exists()) return null;
      final digest = await digestFile(source.file);
      await encoder.addFile(source.file, source.archivePath);
      return ArchiveMedia(
        mediaId: source.mediaId,
        version: source.version,
        role: source.role,
        sha256: digest.sha256,
        byteSize: digest.byteSize,
        path: source.archivePath,
        quality: source.quality,
      );
    } catch (e, st) {
      Log.e(
        'Fichier absent de l’archive : ${source.vaultPath}',
        e,
        st,
        'Vault',
      );
      return null;
    }
  }

  Future<_Plan> _plan() async {
    final children = await _db.select(_db.childrenTable).get();
    final artworks = await (_db.select(
      _db.artworksTable,
    )..orderBy([(t) => OrderingTerm(expression: t.addedAt)])).get();
    final versions = {
      for (final row in await _db.select(_db.mediaVersionsTable).get())
        row.localPath: row,
    };

    final files = <_SourceFile>[];
    final missing = <ArchiveMissing>[];

    Future<void> addPhoto(ArtworkEntity artwork) async {
      final originalPath = artwork.relativeImagePath;
      var originalIncluded = false;
      if (originalPath != null) {
        final file = await _vault.resolveFile(originalPath);
        if (await _readable(file)) {
          files.add(
            _SourceFile(
              file: file,
              vaultPath: originalPath,
              mediaId: artwork.id,
              version: versions[originalPath]?.version ?? 1,
              role: MediaRole.original,
              extension: p.extension(originalPath),
            ),
          );
          originalIncluded = true;
        } else {
          missing.add(
            ArchiveMissing(
              mediaId: artwork.id,
              role: MediaRole.original,
              path: originalPath,
            ),
          );
        }
      }
      if (originalIncluded) return;
      // The optimized copy stands in for an original that is gone, or that
      // this device never had.
      final displayPath = artwork.displayImagePath;
      if (displayPath == null) return;
      final file = await _vault.resolveFile(displayPath);
      if (await _readable(file)) {
        files.add(
          _SourceFile(
            file: file,
            vaultPath: displayPath,
            mediaId: artwork.id,
            version: 1,
            role: MediaRole.optimized,
            extension: p.extension(displayPath),
          ),
        );
      } else if (originalPath == null) {
        missing.add(
          ArchiveMissing(
            mediaId: artwork.id,
            role: MediaRole.optimized,
            path: displayPath,
          ),
        );
      }
    }

    for (final artwork in artworks) {
      await addPhoto(artwork);
      final audioPath = artwork.relativeAudioPath;
      if (audioPath == null) continue;
      final file = await _vault.resolveFile(audioPath);
      if (await _readable(file)) {
        files.add(
          _SourceFile(
            file: file,
            vaultPath: audioPath,
            mediaId: artwork.id,
            version: versions[audioPath]?.version ?? 1,
            role: MediaRole.audio,
            extension: p.extension(audioPath),
          ),
        );
      } else {
        missing.add(
          ArchiveMissing(
            mediaId: artwork.id,
            role: MediaRole.audio,
            path: audioPath,
          ),
        );
      }
    }

    var totalBytes = 0;
    for (final source in files) {
      totalBytes += await source.file.length();
    }
    return _Plan(
      children: [
        for (final child in children)
          ArchiveChild(
            id: child.id,
            name: child.name,
            birthDate: syncDateValue(child.birthDate),
            createdAt: child.createdAt,
            updatedAt: child.updatedAt,
            deletedAt: child.deletedAt,
          ),
      ],
      artworks: [
        for (final artwork in artworks)
          ArchiveArtwork(
            id: artwork.id,
            childId: artwork.childId,
            addedAt: artwork.addedAt,
            drawnAt: artwork.drawnAt == null
                ? null
                : syncDateValue(artwork.drawnAt!),
            story: artwork.story,
            imageWidth: artwork.imageWidth,
            imageHeight: artwork.imageHeight,
            audioDurationMs: artwork.audioDurationMs,
            deletedAt: artwork.deletedAt,
          ),
      ],
      files: files,
      missing: missing,
      totalBytes: totalBytes,
    );
  }

  static Future<bool> _readable(File file) async {
    try {
      if (!await file.exists()) return false;
      await file.openRead(0, 1).drain<void>();
      return true;
    } catch (_) {
      return false;
    }
  }

  static String _stamp(DateTime instant) {
    final utc = instant.toUtc();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${utc.year}${two(utc.month)}${two(utc.day)}-'
        '${two(utc.hour)}${two(utc.minute)}${two(utc.second)}';
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
      // Desktop and test platforms may lack the mobile plugin.
      return null;
    }
  }

  static Future<void> _defaultShare(File archive) async {
    await SharePlus.instance.share(ShareParams(files: [XFile(archive.path)]));
  }
}

class _Plan {
  final List<ArchiveChild> children;
  final List<ArchiveArtwork> artworks;
  final List<_SourceFile> files;
  final List<ArchiveMissing> missing;
  final int totalBytes;

  const _Plan({
    required this.children,
    required this.artworks,
    required this.files,
    required this.missing,
    required this.totalBytes,
  });
}

class _SourceFile {
  final File file;
  final String vaultPath;
  final String mediaId;
  final int version;
  final MediaRole role;
  final String extension;

  const _SourceFile({
    required this.file,
    required this.vaultPath,
    required this.mediaId,
    required this.version,
    required this.role,
    required this.extension,
  });

  ArchiveQuality get quality => role == MediaRole.optimized
      ? ArchiveQuality.optimized
      : ArchiveQuality.original;

  /// `media/<mediaId>/<role>-v<version><ext>`.
  String get archivePath => p.posix.join(
    kVaultArchiveMediaFolder,
    mediaId,
    '${role.name}-v$version${extension.toLowerCase()}',
  );

  ArchiveMissing get asMissing =>
      ArchiveMissing(mediaId: mediaId, role: role, path: vaultPath);
}
