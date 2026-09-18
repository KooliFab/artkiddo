import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/config/app_capabilities.dart';
import '../../contracts/trash.dart';
import '../../presentation/providers/core_providers.dart';
import 'local_trash_repository.dart';

export '../../contracts/trash.dart' show TrashRepository, TrashedArtwork;

/// Selects the local or household-wide implementation before reading any
/// provider singleton. The local composition never touches remote cloud providers.
final trashRepositoryProvider = Provider<TrashRepository>((ref) {
  final capabilities = ref.watch(appCapabilitiesProvider);
  if (capabilities.trash != TrashCapability.local) {
    throw StateError('The public core only supports local trash');
  }
  return LocalTrashRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(localVaultProvider),
  );
});
