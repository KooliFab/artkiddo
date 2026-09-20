import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../contracts/remote_media.dart';
import '../../local/audio/audio_player_service.dart';
import '../../local/audio/audio_recorder_service.dart';
import '../config/app_capabilities.dart';
import '../config/bootstrap_configuration.dart';
import '../config/cloud_services.dart';
import '../../local/database/app_database.dart';
import '../../local/storage/local_vault.dart';
import '../../local/storage/vault_rescue_export.dart';

final appCapabilitiesProvider = Provider<AppCapabilities>((ref) {
  return AppCapabilities.local;
});

final cloudServicesProvider = Provider<CloudServices?>((ref) {
  return null;
});

final appEnvironmentProvider = Provider<AppEnvironment>((ref) {
  return AppEnvironment.local;
});

/// Global singletons for local storage and local database.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final localVaultProvider = Provider<LocalVault>((ref) {
  return LocalVault();
});

/// File-only recovery path. It intentionally does not read AppDatabase.
final vaultRescueExportProvider = Provider<VaultRescueExport>((ref) {
  return VaultRescueExport(
    documentsDirectoryProvider: () =>
        ref.read(localVaultProvider).documentsDirectory,
  );
});

final audioRecorderServiceProvider = Provider<AudioRecorderService>((ref) {
  final service = RecordAudioRecorderService();
  ref.onDispose(() => service.dispose());
  return service;
});

final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  final service = JustAudioPlayerService();
  ref.onDispose(() => service.dispose());
  return service;
});

final remoteMediaFetcherProvider = Provider<RemoteMediaFetcher>((ref) {
  return const NoRemoteMediaFetcher();
});

/// Current authenticated user email, or null if unauthenticated or in local mode.
final sessionEmailProvider = Provider<String?>((ref) => null);
