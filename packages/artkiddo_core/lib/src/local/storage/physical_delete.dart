import 'package:drift/drift.dart';

import '../../contracts/sync_protocol.dart';
import '../database/app_database.dart';
import '../logging/log.dart';
import 'media_versions.dart';

/// What [deleteVaultFileIfUnreferenced] did.
enum PhysicalDeleteOutcome {
  /// The file is gone (or already was).
  deleted,

  /// Something still points at the file: an artwork row (the trash
  /// included), a value in `replaced_values`, or an operation in the outbox.
  /// Nothing was touched; the cleanup is retried later.
  stillReferenced,
}

/// The only place a file of the vault is physically removed: it asks
/// [MediaVersionsRepository.isMediaReferenced], removes the file, drops the
/// registry entry of that path, and does nothing else.
///
/// Callers: the 30-day trash purge and an explicit deletion of an artwork or
/// a child, through `LocalVault.deleteFileOrEnqueueCleanup` (which also
/// retries a failed removal at the next start). No network, auth or sync
/// error path reaches it.
///
/// [removeFile] is the raw removal (missing file = success, other failure =
/// throws); it is injected so this file does not depend on the vault.
Future<PhysicalDeleteOutcome> deleteVaultFileIfUnreferenced({
  required AppDatabase db,
  required String relativePath,
  required Future<void> Function(String relativePath) removeFile,
}) async {
  if (await _isPathReferenced(db, relativePath)) {
    return PhysicalDeleteOutcome.stillReferenced;
  }
  await removeFile(relativePath);
  await (db.delete(
    db.mediaVersionsTable,
  )..where((t) => t.localPath.equals(relativePath))).go();
  return PhysicalDeleteOutcome.deleted;
}

Future<bool> _isPathReferenced(AppDatabase db, String path) async {
  // A row pointing at the path, whatever it is (an original, an audio or a
  // derivative, which the registry does not list).
  final artwork =
      await (db.select(db.artworksTable)
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

  final registered = await (db.select(
    db.mediaVersionsTable,
  )..where((t) => t.localPath.equals(path))).get();
  final media = MediaVersionsRepository(db);
  for (final entry in registered) {
    final referenced = await media.isMediaReferenced(
      entry.mediaId,
      entry.version,
      role: MediaRole.values.byName(entry.role),
    );
    if (referenced) {
      Log.i(
        'Fichier conservé : ${entry.mediaId} v${entry.version} est encore '
            'référencé',
        'Vault',
      );
      return true;
    }
  }
  return false;
}
