import '../../domain/backup_status.dart';
import '../../domain/child.dart';
import '../database/app_database.dart';
import '../storage/local_vault.dart';

/// Reads the facts [backupStatusFor] needs and applies it, for every artwork
/// outside the trash. Read-only: it never writes a row and never deletes a
/// file; a file that is gone only changes the status.
class BackupStatusRepository {
  final AppDatabase _db;
  final LocalVault _vault;
  BackupStatusRepository(this._db, this._vault);

  /// Status of every artwork not in the trash, by artwork id.
  Future<Map<String, ArtworkBackupStatus>> statuses({
    required bool remoteBackup,
  }) async {
    final rows = await (_db.select(
      _db.artworksTable,
    )..where((t) => t.deletedAt.isNull())).get();

    final ops = <String, ({int count, int maxAttempts})>{};
    for (final op in await (_db.select(
      _db.syncOutboxTable,
    )..where((t) => t.entity.equals('artwork'))).get()) {
      final known = ops[op.entityId];
      final knownAttempts = known?.maxAttempts ?? 0;
      ops[op.entityId] = (
        count: (known?.count ?? 0) + 1,
        maxAttempts: op.attempts > knownAttempts ? op.attempts : knownAttempts,
      );
    }

    // A path shared by several rows is checked once.
    final exists = <String, bool>{};
    Future<bool> pathExists(String path) async =>
        exists[path] ??= await (await _vault.resolveFile(path)).exists();

    final result = <String, ArtworkBackupStatus>{};
    for (final row in rows) {
      var missing = false;
      for (final path in [
        row.relativeImagePath,
        row.displayImagePath,
        row.thumbnailImagePath,
        row.relativeAudioPath,
      ]) {
        if (path != null && !await pathExists(path)) {
          missing = true;
          break;
        }
      }
      final queued = ops[row.id];
      result[row.id] = backupStatusFor(
        ArtworkBackupFacts(
          remoteBackup: remoteBackup,
          syncState: SyncState.values.firstWhere(
            (s) => s.name == row.syncState,
            orElse: () => SyncState.localOnly,
          ),
          remotePurged: row.remotePurgedAt != null,
          pendingOperations: queued?.count ?? 0,
          maxAttempts: queued?.maxAttempts ?? 0,
          missingFile: missing,
          audioSyncPending: row.audioSyncIntent != 'keep',
          audioConflict: row.audioConflict,
        ),
      );
    }
    return result;
  }

  /// Same, re-emitted whenever an artwork, an operation or a media version
  /// changes.
  Stream<Map<String, ArtworkBackupStatus>> watchStatuses({
    required bool remoteBackup,
  }) => _db
      .customSelect(
        'SELECT 1',
        readsFrom: {
          _db.artworksTable,
          _db.syncOutboxTable,
          _db.mediaVersionsTable,
        },
      )
      .watch()
      .asyncMap((_) => statuses(remoteBackup: remoteBackup));
}
