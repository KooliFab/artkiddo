import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../contracts/sync_protocol.dart';
import '../../sync/replaced_values.dart';
import '../../sync/sync_outbox.dart';
import '../database/app_database.dart';
import '../logging/log.dart';
import 'atomic_file.dart';
import 'file_digest.dart';
import 'local_vault.dart';
import 'media_versions.dart';
import 'vault_archive_manifest.dart';

/// What [VaultArchiveImporter.importArchive] did.
class VaultArchiveImportResult {
  final int addedChildren;
  final int addedArtworks;

  /// Media files written into the vault.
  final int filesWritten;

  /// Imported values that differ from the local ones, kept in
  /// `replaced_values` while the local value stays.
  final int keptAside;

  /// Children and artworks the archive described that were already here,
  /// identical.
  final int unchanged;

  const VaultArchiveImportResult({
    required this.addedChildren,
    required this.addedArtworks,
    required this.filesWritten,
    required this.keptAside,
    required this.unchanged,
  });

  /// False for a re-import of what the device already holds.
  bool get changedAnything =>
      addedChildren + addedArtworks + filesWritten + keptAside > 0;

  @override
  String toString() =>
      'VaultArchiveImportResult(addedChildren: $addedChildren, '
      'addedArtworks: $addedArtworks, filesWritten: $filesWritten, '
      'keptAside: $keptAside, unchanged: $unchanged)';
}

/// Imports an archive made by `VaultArchiveExporter`.
///
/// Two phases. **Validation** works in a temporary directory only: the
/// archive is opened, its entry names and its manifest are checked, and every
/// media file is extracted and compared with its size and SHA-256. A single
/// failure throws a [VaultArchiveImportException] and the vault, the database
/// and the outbox are untouched. **Application** then adds what is absent:
/// the files first (through [writeFileAtomically]), then every row in one
/// transaction. A failure in either step leaves no row and removes the files
/// just written.
///
/// Nothing local is ever overwritten. An element is a child, an artwork, or a
/// media file of an artwork (photo, audio). An absent element is added; an
/// identical one is ignored; for an element that exists with a different
/// value, the local value stays and the imported one goes to
/// `replaced_values` (a media file is kept as a new version next to the local
/// one). Re-importing the same archive changes nothing.
class VaultArchiveImporter {
  final AppDatabase _db;
  final LocalVault _vault;
  final DateTime Function() _now;
  final Future<Directory> Function() _temporaryDirectoryProvider;
  final VaultFileOps _fileOps;
  final SyncOutboxRepository _outbox;
  late final MediaVersionsRepository _media = MediaVersionsRepository(_db);

  VaultArchiveImporter(
    this._db,
    this._vault, {
    DateTime Function()? now,
    Future<Directory> Function()? temporaryDirectoryProvider,
    VaultFileOps? fileOps,
    SyncOutboxRepository? outbox,
  }) : _now = now ?? DateTime.now,
       _temporaryDirectoryProvider =
           temporaryDirectoryProvider ?? getTemporaryDirectory,
       _fileOps = fileOps ?? const DiskVaultFileOps(),
       _outbox = outbox ?? SyncOutboxRepository(_db);

  Future<VaultArchiveImportResult> importArchive(File archive) async {
    final temporary = await _temporaryDirectoryProvider();
    final work = await Directory(
      p.join(
        temporary.path,
        'artkiddo-import-${DateTime.now().microsecondsSinceEpoch}',
      ),
    ).create(recursive: true);
    try {
      final staged = await _validate(archive, work);
      return await _apply(staged);
    } finally {
      try {
        await work.delete(recursive: true);
      } on FileSystemException catch (e) {
        Log.w('Dossier d’import temporaire conservé : $e', 'Vault');
      }
    }
  }

  // -------------------------------------------------------------------------
  // Phase 1: validation, in a temporary directory.
  // -------------------------------------------------------------------------

  Future<_Staged> _validate(File archive, Directory work) async {
    final input = InputFileStream(archive.path);
    try {
      final Archive zip;
      try {
        zip = ZipDecoder().decodeStream(input);
      } catch (e) {
        throw VaultArchiveImportException(
          VaultArchiveFailure.notAnArchive,
          'cannot read the ZIP: $e',
        );
      }

      final entries = <String, ArchiveFile>{};
      for (final entry in zip.files) {
        if (!isSafeArchivePath(entry.name)) {
          throw VaultArchiveImportException(
            VaultArchiveFailure.invalidManifest,
            'unsafe entry name: ${entry.name}',
          );
        }
        if (entry.isSymbolicLink) {
          throw VaultArchiveImportException(
            VaultArchiveFailure.invalidManifest,
            'symbolic link in the archive: ${entry.name}',
          );
        }
        if (!entry.isFile) continue;
        if (entries.containsKey(entry.name)) {
          throw VaultArchiveImportException(
            VaultArchiveFailure.invalidManifest,
            'duplicate entry: ${entry.name}',
          );
        }
        entries[entry.name] = entry;
      }

      final manifestEntry = entries[kVaultArchiveManifestName];
      if (manifestEntry == null) {
        throw const VaultArchiveImportException(
          VaultArchiveFailure.notAnArchive,
          'no manifest.json',
        );
      }
      if (manifestEntry.size > _maxManifestBytes) {
        throw const VaultArchiveImportException(
          VaultArchiveFailure.invalidManifest,
          'manifest too large',
        );
      }
      final String source;
      try {
        source = utf8.decode(manifestEntry.readBytes() ?? const []);
      } on FormatException {
        throw const VaultArchiveImportException(
          VaultArchiveFailure.invalidManifest,
          'manifest is not UTF-8',
        );
      }
      final manifest = VaultArchiveManifest.decode(source);

      final files = <String, File>{};
      for (final media in manifest.media) {
        final entry = entries[media.path];
        if (entry == null) {
          throw VaultArchiveImportException(
            VaultArchiveFailure.corruptedMedia,
            'file missing from the archive: ${media.path}',
          );
        }
        if (entry.size != media.byteSize) {
          throw VaultArchiveImportException(
            VaultArchiveFailure.corruptedMedia,
            'size of ${media.path}: ${entry.size} instead of ${media.byteSize}',
          );
        }
        final staged = File(p.joinAll([work.path, ...media.path.split('/')]));
        await staged.parent.create(recursive: true);
        final output = OutputFileStream(staged.path);
        try {
          entry.writeContent(output);
        } finally {
          await output.close();
        }
        final digest = await digestFile(staged);
        if (digest.byteSize != media.byteSize ||
            digest.sha256 != media.sha256) {
          throw VaultArchiveImportException(
            VaultArchiveFailure.corruptedMedia,
            'content of ${media.path} does not match its hash',
          );
        }
        files[media.path] = staged;
      }
      return _Staged(manifest, files);
    } finally {
      await input.close();
    }
  }

  static const int _maxManifestBytes = 64 * 1024 * 1024;

  // -------------------------------------------------------------------------
  // Phase 2: application.
  // -------------------------------------------------------------------------

  Future<VaultArchiveImportResult> _apply(_Staged staged) async {
    final manifest = staged.manifest;
    final plan = _ApplyPlan(staged.files);

    final localChildren = {
      for (final row in await _db.select(_db.childrenTable).get()) row.id: row,
    };
    final localArtworks = {
      for (final row in await _db.select(_db.artworksTable).get()) row.id: row,
    };
    final mediaByArtwork = <String, Map<String, ArchiveMedia>>{};
    for (final media in manifest.media) {
      mediaByArtwork.putIfAbsent(
        media.mediaId,
        () => {},
      )[media.role == MediaRole.audio ? 'audio' : 'photo'] = media;
    }

    var addedChildren = 0;
    var addedArtworks = 0;
    var unchanged = 0;

    for (final child in manifest.children) {
      final local = localChildren[child.id];
      if (local == null) {
        addedChildren++;
        _planNewChild(plan, child);
        continue;
      }
      final before = plan.size;
      await _compareChild(plan, local, child);
      if (plan.size == before) unchanged++;
    }

    for (final artwork in manifest.artworks) {
      final local = localArtworks[artwork.id];
      final media = mediaByArtwork[artwork.id] ?? const {};
      if (local == null) {
        addedArtworks++;
        await _planNewArtwork(plan, artwork, media['photo'], media['audio']);
        continue;
      }
      final before = plan.size;
      await _compareArtwork(
        plan,
        local,
        artwork,
        media['photo'],
        media['audio'],
      );
      if (plan.size == before) unchanged++;
    }

    final written = <String>[];
    try {
      for (final write in plan.writes) {
        await writeFileAtomically(
          await _vault.resolveFile(write.vaultPath),
          source: write.source,
          ops: _fileOps,
        );
        written.add(write.vaultPath);
        try {
          await write.source.delete();
        } on FileSystemException {
          // The temporary directory is removed as a whole afterwards.
        }
      }
      if (plan.steps.isNotEmpty) {
        await _db.transaction(() async {
          for (final step in plan.steps) {
            await step();
          }
        });
      }
    } catch (_) {
      for (final path in written) {
        await _vault.deleteFileOrEnqueueCleanup(relativePath: path, db: _db);
      }
      rethrow;
    }

    return VaultArchiveImportResult(
      addedChildren: addedChildren,
      addedArtworks: addedArtworks,
      filesWritten: plan.writes.length,
      keptAside: plan.keptAside,
      unchanged: unchanged,
    );
  }

  // ----- children ----------------------------------------------------------

  void _planNewChild(_ApplyPlan plan, ArchiveChild child) {
    plan.steps.add(() async {
      await _db
          .into(_db.childrenTable)
          .insert(
            ChildrenTableCompanion.insert(
              id: child.id,
              name: child.name,
              birthDate: DateTime.parse(child.birthDate),
              createdAt: child.createdAt,
              updatedAt: child.updatedAt,
              deletedAt: Value(child.deletedAt),
            ),
          );
      if (child.deletedAt != null) return;
      await _outbox.enqueuePatch(
        EntityPatch(
          opId: _outbox.newOpId(),
          entityType: SyncEntityType.child,
          entityId: child.id,
          baseRevisions: {
            ChildSyncFields.name: 0,
            ChildSyncFields.birthDate: 0,
          },
          fields: {
            ChildSyncFields.name: child.name,
            ChildSyncFields.birthDate: child.birthDate,
          },
          createdAt: _now(),
        ),
      );
    });
  }

  Future<void> _compareChild(
    _ApplyPlan plan,
    ChildEntity local,
    ArchiveChild imported,
  ) async {
    if (local.name != imported.name) {
      await _keepAside(
        plan,
        SyncEntityType.child,
        local.id,
        ChildSyncFields.name,
        imported.name,
      );
    }
    if (syncDateValue(local.birthDate) != imported.birthDate) {
      await _keepAside(
        plan,
        SyncEntityType.child,
        local.id,
        ChildSyncFields.birthDate,
        imported.birthDate,
      );
    }
  }

  // ----- artworks ----------------------------------------------------------

  Future<void> _planNewArtwork(
    _ApplyPlan plan,
    ArchiveArtwork artwork,
    ArchiveMedia? photo,
    ArchiveMedia? audio,
  ) async {
    String? originalPath;
    String? displayPath;
    String? audioPath;
    if (photo != null) {
      if (photo.role == MediaRole.original) {
        originalPath = await _stage(
          plan,
          photo,
          p.posix.join(
            LocalVault.artworksFolder,
            '${artwork.id}${photo.extension}',
          ),
        );
      } else {
        displayPath = await _stage(plan, photo, _displayPath(artwork.id));
      }
    }
    if (audio != null) {
      audioPath = await _stage(
        plan,
        audio,
        LocalVault.audioVersionPath(
          artwork.id,
          audio.version,
          extension: audio.extension,
        ),
      );
    }

    plan.steps.add(() async {
      await _db
          .into(_db.artworksTable)
          .insert(
            ArtworksTableCompanion.insert(
              id: artwork.id,
              childId: artwork.childId,
              relativeImagePath: Value(originalPath),
              addedAt: artwork.addedAt,
              drawnAt: Value(
                artwork.drawnAt == null
                    ? null
                    : DateTime.parse(artwork.drawnAt!),
              ),
              story: Value(artwork.story),
              displayImagePath: Value(displayPath),
              imageWidth: Value(artwork.imageWidth),
              imageHeight: Value(artwork.imageHeight),
              relativeAudioPath: Value(audioPath),
              audioDurationMs: Value(
                audioPath == null ? null : artwork.audioDurationMs,
              ),
              audioByteSize: Value(audio?.byteSize ?? 0),
              audioSyncIntent: Value(audioPath == null ? 'keep' : 'replace'),
              deletedAt: Value(artwork.deletedAt),
            ),
          );
      if (photo != null) {
        await _media.record(
          mediaId: artwork.id,
          version: photo.version,
          role: photo.role,
          localPath: (originalPath ?? displayPath)!,
          byteSize: photo.byteSize,
        );
      }
      if (audio != null) {
        await _media.record(
          mediaId: artwork.id,
          version: audio.version,
          role: MediaRole.audio,
          localPath: audioPath!,
          byteSize: audio.byteSize,
        );
      }
      // An artwork known only through its optimized copy has no original
      // to upload: it is not queued.
      if (originalPath == null) return;
      await _outbox.enqueue(
        entity: SyncEntityKind.artwork,
        entityId: artwork.id,
        op: SyncOutboxOp.upsert,
      );
      if (artwork.isTrashed) {
        await _outbox.enqueuePatch(
          EntityPatch(
            opId: _outbox.newOpId(),
            entityType: SyncEntityType.artwork,
            entityId: artwork.id,
            baseRevisions: {ArtworkSyncFields.lifecycle: 0},
            fields: {ArtworkSyncFields.lifecycle: SyncLifecycle.trashed.name},
            createdAt: _now(),
          ),
          supersedePending: false,
        );
      }
    });
  }

  Future<void> _compareArtwork(
    _ApplyPlan plan,
    ArtworkEntity local,
    ArchiveArtwork imported,
    ArchiveMedia? photo,
    ArchiveMedia? audio,
  ) async {
    final id = local.id;
    const type = SyncEntityType.artwork;
    if (local.childId != imported.childId) {
      await _keepAside(
        plan,
        type,
        id,
        ArtworkSyncFields.childId,
        imported.childId,
      );
    }
    if (local.addedAt.millisecondsSinceEpoch ~/ 1000 !=
        imported.addedAt.millisecondsSinceEpoch ~/ 1000) {
      await _keepAside(
        plan,
        type,
        id,
        ArtworkSyncFields.addedAt,
        syncInstantValue(imported.addedAt),
      );
    }
    // An imported value that is empty has nothing to keep.
    if (imported.story != null && imported.story != local.story) {
      await _keepAside(plan, type, id, ArtworkSyncFields.story, imported.story);
    }
    if (imported.drawnAt != null &&
        imported.drawnAt !=
            (local.drawnAt == null ? null : syncDateValue(local.drawnAt!))) {
      await _keepAside(
        plan,
        type,
        id,
        ArtworkSyncFields.drawnAt,
        imported.drawnAt,
      );
    }
    if (imported.isTrashed != (local.deletedAt != null)) {
      await _keepAside(
        plan,
        type,
        id,
        ArtworkSyncFields.lifecycle,
        (imported.isTrashed ? SyncLifecycle.trashed : SyncLifecycle.active)
            .name,
      );
    }
    if (photo != null) await _comparePhoto(plan, local, photo);
    if (audio != null) await _compareAudio(plan, local, audio);
  }

  Future<void> _comparePhoto(
    _ApplyPlan plan,
    ArtworkEntity local,
    ArchiveMedia photo,
  ) async {
    final id = local.id;
    if (photo.role == MediaRole.optimized) {
      // The local original, when there is one, is better than this copy.
      if (local.relativeImagePath != null) return;
      final display = local.displayImagePath;
      if (display == null) {
        final path = await _stage(plan, photo, _displayPath(id));
        plan.steps.add(
          () => (_db.update(_db.artworksTable)..where((t) => t.id.equals(id)))
              .write(ArtworksTableCompanion(displayImagePath: Value(path))),
        );
      } else if (!await (await _vault.resolveFile(display)).exists()) {
        plan.writes.add(_FileWrite(display, plan.files[photo.path]!));
      }
      return;
    }

    final path = local.relativeImagePath;
    if (path == null) {
      final staged = await _stage(
        plan,
        photo,
        p.posix.join(LocalVault.artworksFolder, '$id${photo.extension}'),
      );
      plan.steps.add(() async {
        await (_db.update(_db.artworksTable)..where((t) => t.id.equals(id)))
            .write(ArtworksTableCompanion(relativeImagePath: Value(staged)));
        await _media.record(
          mediaId: id,
          version: photo.version,
          role: MediaRole.original,
          localPath: staged,
          byteSize: photo.byteSize,
        );
      });
      return;
    }

    final file = await _vault.resolveFile(path);
    if (!await file.exists()) {
      // The row points at a file that is gone: the archive gives it back at
      // the same path.
      plan.writes.add(_FileWrite(path, plan.files[photo.path]!));
      final version = await _versionAt(path) ?? photo.version;
      plan.steps.add(
        () => _media.record(
          mediaId: id,
          version: version,
          role: MediaRole.original,
          localPath: path,
          byteSize: photo.byteSize,
        ),
      );
      return;
    }
    if (await _sameContent(file, photo.sha256)) return;
    await _keepMediaAside(plan, id, photo, ArtworkSyncFields.photo);
  }

  Future<void> _compareAudio(
    _ApplyPlan plan,
    ArtworkEntity local,
    ArchiveMedia audio,
  ) async {
    final id = local.id;
    final path = local.relativeAudioPath;
    if (path == null) {
      final version = await _media.nextVersion(id, MediaRole.audio);
      final staged = await _stage(
        plan,
        audio,
        LocalVault.audioVersionPath(id, version, extension: audio.extension),
      );
      plan.steps.add(() async {
        await (_db.update(
          _db.artworksTable,
        )..where((t) => t.id.equals(id))).write(
          ArtworksTableCompanion(
            relativeAudioPath: Value(staged),
            audioByteSize: Value(audio.byteSize),
            audioSyncIntent: const Value('replace'),
          ),
        );
        await _media.record(
          mediaId: id,
          version: version,
          role: MediaRole.audio,
          localPath: staged,
          byteSize: audio.byteSize,
        );
      });
      return;
    }

    final file = await _vault.resolveFile(path);
    if (!await file.exists()) {
      plan.writes.add(_FileWrite(path, plan.files[audio.path]!));
      final version = await _versionAt(path) ?? audio.version;
      plan.steps.add(
        () => _media.record(
          mediaId: id,
          version: version,
          role: MediaRole.audio,
          localPath: path,
          byteSize: audio.byteSize,
        ),
      );
      return;
    }
    if (await _sameContent(file, audio.sha256)) return;
    // The audio is one indivisible value: the local recording stays, the
    // imported one is kept as a version of its own next to it.
    await _keepMediaAside(plan, id, audio, ArtworkSyncFields.audio);
  }

  // ----- helpers -----------------------------------------------------------

  static String _displayPath(String artworkId) =>
      p.posix.join(LocalVault.derivativesFolder, '${artworkId}_display.jpg');

  Future<int?> _versionAt(String path) async {
    final row = await (_db.select(
      _db.mediaVersionsTable,
    )..where((t) => t.localPath.equals(path))).get();
    return row.isEmpty ? null : row.first.version;
  }

  Future<bool> _sameContent(File file, String sha256) async {
    try {
      return (await digestFile(file)).sha256 == sha256;
    } on FileSystemException {
      return false;
    }
  }

  /// Keeps an imported media file that differs from the local one. A version
  /// of the vault that already holds the same content (a recording the
  /// parent replaced, or a copy kept by an earlier import) is named in the
  /// history instead of writing the file again.
  Future<void> _keepMediaAside(
    _ApplyPlan plan,
    String id,
    ArchiveMedia media,
    String field,
  ) async {
    LocalMediaVersion? held;
    for (final version in await _media.versionsOf(id)) {
      if (version.role != media.role) continue;
      final file = await _vault.resolveFile(version.localPath);
      if (await file.exists() && await _sameContent(file, media.sha256)) {
        held = version;
        break;
      }
    }

    if (held != null) {
      final ref = MediaRef(mediaId: id, version: held.version);
      final recorded =
          await (_db.select(_db.replacedValuesTable)
                ..where(
                  (t) =>
                      t.entityId.equals(id) &
                      t.field.equals(field) &
                      t.mediaRef.equals(jsonEncode(ref.toJson())),
                )
                ..limit(1))
              .get();
      if (recorded.isNotEmpty) return;
      await _keepAside(
        plan,
        SyncEntityType.artwork,
        id,
        field,
        ref.toJson(),
        mediaRef: ref,
      );
      return;
    }

    final version = await _media.nextVersion(id, media.role);
    final preferred = media.role == MediaRole.audio
        ? LocalVault.audioVersionPath(id, version, extension: media.extension)
        : p.posix.join(
            LocalVault.artworksFolder,
            '$id.v$version${media.extension}',
          );
    final path = await _stage(plan, media, preferred);
    final ref = MediaRef(mediaId: id, version: version);
    await _keepAside(
      plan,
      SyncEntityType.artwork,
      id,
      field,
      ref.toJson(),
      mediaRef: ref,
      onKept: () => _media.record(
        mediaId: id,
        version: version,
        role: media.role,
        localPath: path,
        byteSize: media.byteSize,
      ),
    );
  }

  /// Plans the write of [media] at [preferred], or at the first free
  /// `.vN` sibling when another file already sits there. A file already in
  /// place with the same content is reused, not written again. Returns the
  /// vault path the row must point at.
  Future<String> _stage(
    _ApplyPlan plan,
    ArchiveMedia media,
    String preferred,
  ) async {
    var candidate = preferred;
    for (var attempt = 2; ; attempt++) {
      final file = await _vault.resolveFile(candidate);
      if (!await file.exists()) {
        plan.writes.add(_FileWrite(candidate, plan.files[media.path]!));
        return candidate;
      }
      try {
        if ((await digestFile(file)).sha256 == media.sha256) return candidate;
      } on FileSystemException {
        // Unreadable: leave it, use the next name.
      }
      candidate =
          '${p.posix.withoutExtension(preferred)}.v$attempt'
          '${p.posix.extension(preferred)}';
    }
  }

  /// Plans the record of an imported value that lost against the local one.
  /// A value already in the history is not recorded again, so a second
  /// import changes nothing.
  Future<void> _keepAside(
    _ApplyPlan plan,
    SyncEntityType entityType,
    String entityId,
    String field,
    Object? value, {
    MediaRef? mediaRef,
    Future<void> Function()? onKept,
  }) async {
    if (mediaRef == null) {
      final known =
          await (_db.select(_db.replacedValuesTable)
                ..where(
                  (t) =>
                      t.entityId.equals(entityId) &
                      t.field.equals(field) &
                      t.valueJson.equals(jsonEncode(value)) &
                      t.source.equals(ReplacedValueSource.remote.name),
                )
                ..limit(1))
              .get();
      if (known.isNotEmpty) return;
    }
    plan.keptAside++;
    plan.steps.add(() async {
      await onKept?.call();
      await ReplacedValuesRepository(_db, now: _now).record(
        entityType: entityType,
        entityId: entityId,
        field: field,
        value: value,
        source: ReplacedValueSource.remote,
        mediaRef: mediaRef,
      );
    });
  }
}

class _Staged {
  final VaultArchiveManifest manifest;

  /// Archive path → the verified file extracted in the temporary directory.
  final Map<String, File> files;

  const _Staged(this.manifest, this.files);
}

class _FileWrite {
  final String vaultPath;
  final File source;

  const _FileWrite(this.vaultPath, this.source);
}

class _ApplyPlan {
  final Map<String, File> files;
  final List<_FileWrite> writes = [];
  final List<Future<void> Function()> steps = [];
  int keptAside = 0;

  _ApplyPlan(this.files);

  /// Grows with every planned write or step; an element that leaves it alone
  /// changed nothing.
  int get size => writes.length + steps.length;
}
