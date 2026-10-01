import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/backup_status.dart';
import '../../local/repositories/backup_status_repository.dart';
import 'core_providers.dart';

final backupStatusRepositoryProvider = Provider<BackupStatusRepository>(
  (ref) => BackupStatusRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(localVaultProvider),
  ),
);

/// Backup status of every artwork outside the trash, by artwork id. Follows
/// the artworks, the outbox and the media registry.
final artworkBackupStatusesProvider =
    StreamProvider.autoDispose<Map<String, ArtworkBackupStatus>>((ref) {
      final capabilities = ref.watch(appCapabilitiesProvider);
      return ref
          .watch(backupStatusRepositoryProvider)
          .watchStatuses(remoteBackup: capabilities.remoteBackup);
    });

/// The status of one artwork, or null while unknown or when it is trashed.
final artworkBackupStatusProvider = Provider.autoDispose
    .family<ArtworkBackupStatus?, String>(
      (ref, artworkId) => ref.watch(
        artworkBackupStatusesProvider.select(
          (statuses) => statuses.value?[artworkId],
        ),
      ),
    );

/// Artworks per state, for a settings summary.
final backupSummaryProvider = Provider.autoDispose<BackupSummary?>((ref) {
  final statuses = ref.watch(artworkBackupStatusesProvider).value;
  return statuses == null ? null : BackupSummary.of(statuses.values);
});
