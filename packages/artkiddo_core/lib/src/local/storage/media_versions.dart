import 'dart:convert';

import 'package:drift/drift.dart';

import '../../contracts/sync_protocol.dart';
import '../database/app_database.dart';
import '../logging/log.dart';
import 'local_vault.dart';

/// Whether the file of a media version is on the device.
enum MediaVersionState {
  present,

  /// A row or a registry entry points at it, but the file is gone. The
  /// artwork is left untouched; the interface can say the media is missing.
  missing,

  /// Known remotely, not downloaded yet.
  pendingDownload,
}

/// One immutable media file version (table `media_versions`).
class LocalMediaVersion {
  final String mediaId;
  final int version;
  final MediaRole role;
  final String localPath;
  final int byteSize;
  final MediaVersionState state;

  const LocalMediaVersion({
    required this.mediaId,
    required this.version,
    required this.role,
    required this.localPath,
    required this.byteSize,
    required this.state,
  });

  MediaRef get ref => MediaRef(mediaId: mediaId, version: version);
}

/// Registry of the media files the vault holds, and the question every
/// cleanup must ask first: [isMediaReferenced].
///
/// The registry has no hash: the SHA-256 is computed only when a version is
/// sent.
class MediaVersionsRepository {
  final AppDatabase _db;
  MediaVersionsRepository(this._db);

  /// Registers (or updates) a version. Call it inside the transaction that
  /// writes the row pointing at [localPath], after the file is final.
  Future<void> record({
    required String mediaId,
    required int version,
    required MediaRole role,
    required String localPath,
    required int byteSize,
    MediaVersionState state = MediaVersionState.present,
  }) => _db
      .into(_db.mediaVersionsTable)
      .insertOnConflictUpdate(
        MediaVersionsTableCompanion.insert(
          mediaId: mediaId,
          version: version,
          role: role.name,
          localPath: localPath,
          byteSize: Value(byteSize),
          state: Value(state.name),
        ),
      );

  /// The next unused version number of [mediaId] for [role] (`1` for a new
  /// media).
  Future<int> nextVersion(String mediaId, MediaRole role) async {
    final max = _db.mediaVersionsTable.version.max();
    final row =
        await (_db.selectOnly(_db.mediaVersionsTable)
              ..addColumns([max])
              ..where(
                _db.mediaVersionsTable.mediaId.equals(mediaId) &
                    _db.mediaVersionsTable.role.equals(role.name),
              ))
            .getSingle();
    return (row.read(max) ?? 0) + 1;
  }

  /// The versions of [mediaId], oldest first.
  Future<List<LocalMediaVersion>> versionsOf(String mediaId) async {
    final rows =
        await (_db.select(_db.mediaVersionsTable)
              ..where((t) => t.mediaId.equals(mediaId))
              ..orderBy([(t) => OrderingTerm(expression: t.version)]))
            .get();
    return rows.map(_toDomain).toList(growable: false);
  }

  /// True when anything still points at version [version] of [mediaId]:
  /// an artwork (trashed ones included), a value kept in `replaced_values`,
  /// or an operation still in the outbox (pending or in flight). A file of a
  /// referenced version must never be deleted or overwritten.
  ///
  /// Without [role], every role registered under that id and version counts
  /// (an artwork's original and audio can both be version 1): the answer then
  /// errs on the side of "referenced".
  Future<bool> isMediaReferenced(
    String mediaId,
    int version, {
    MediaRole? role,
  }) async {
    final registered =
        await (_db.select(_db.mediaVersionsTable)..where(
              (t) =>
                  t.mediaId.equals(mediaId) &
                  t.version.equals(version) &
                  (role == null
                      ? const Constant(true)
                      : t.role.equals(role.name)),
            ))
            .get();
    for (final entry in registered) {
      final path = entry.localPath;
      final artwork =
          await (_db.select(_db.artworksTable)
                ..where(
                  (t) =>
                      t.relativeImagePath.equals(path) |
                      t.relativeAudioPath.equals(path) |
                      t.displayImagePath.equals(path) |
                      t.thumbnailImagePath.equals(path),
                )
                ..limit(1))
              .get();
      if (artwork.isNotEmpty) return true;
    }

    final ref = jsonEncode(
      MediaRef(mediaId: mediaId, version: version).toJson(),
    );
    final replaced =
        await (_db.select(_db.replacedValuesTable)
              ..where((t) => t.mediaRef.equals(ref))
              ..limit(1))
            .get();
    if (replaced.isNotEmpty) return true;

    // An operation names the version in its patch, as a field value
    // (`{"mediaId":…,"version":N}`) and in the media descriptor (more keys
    // follow `version`).
    final prefix = '"mediaId":"$mediaId","version":$version';
    final queued =
        await (_db.select(_db.syncOutboxTable)
              ..where(
                (t) =>
                    t.patchJson.like('%$prefix}%') |
                    t.patchJson.like('%$prefix,%'),
              )
              ..limit(1))
            .get();
    return queued.isNotEmpty;
  }

  /// Brings the registry in line with the files on the disk. Meant to run at
  /// start-up, after the stale temporary files are removed.
  ///
  /// * a registered file that is gone becomes `missing`; one that is back
  ///   becomes `present`, with its real size;
  /// * a file an artwork points at but the registry does not know (a row
  ///   written before the registry, or by a pull) is registered.
  ///
  /// Never changes an artwork row and never deletes a file. Returns how many
  /// entries changed.
  Future<int> reconcile(LocalVault vault) async {
    var changed = 0;

    final artworks = await _db.select(_db.artworksTable).get();
    final known = {
      for (final row in await _db.select(_db.mediaVersionsTable).get())
        row.localPath,
    };
    for (final artwork in artworks) {
      final original = artwork.relativeImagePath;
      if (original != null && !known.contains(original)) {
        await record(
          mediaId: artwork.id,
          version: await nextVersion(artwork.id, MediaRole.original),
          role: MediaRole.original,
          localPath: original,
          byteSize: 0,
        );
        changed++;
      }
      final audio = artwork.relativeAudioPath;
      if (audio != null && !known.contains(audio)) {
        await record(
          mediaId: artwork.id,
          version: await nextVersion(artwork.id, MediaRole.audio),
          role: MediaRole.audio,
          localPath: audio,
          byteSize: artwork.audioByteSize,
        );
        changed++;
      }
    }

    for (final row in await _db.select(_db.mediaVersionsTable).get()) {
      if (row.state == MediaVersionState.pendingDownload.name) continue;
      final file = await vault.resolveFile(row.localPath);
      final exists = await file.exists();
      final state = exists
          ? MediaVersionState.present
          : MediaVersionState.missing;
      final size = exists ? await file.length() : row.byteSize;
      if (state.name == row.state && size == row.byteSize) continue;
      if (!exists) {
        Log.w('Média absent du coffre : ${row.localPath}', 'Vault');
      }
      await (_db.update(_db.mediaVersionsTable)..where(
            (t) =>
                t.mediaId.equals(row.mediaId) &
                t.version.equals(row.version) &
                t.role.equals(row.role),
          ))
          .write(
            MediaVersionsTableCompanion(
              state: Value(state.name),
              byteSize: Value(size),
            ),
          );
      changed++;
    }
    return changed;
  }

  LocalMediaVersion _toDomain(MediaVersionEntity row) => LocalMediaVersion(
    mediaId: row.mediaId,
    version: row.version,
    role: MediaRole.values.byName(row.role),
    localPath: row.localPath,
    byteSize: row.byteSize,
    state: MediaVersionState.values.byName(row.state),
  );
}
