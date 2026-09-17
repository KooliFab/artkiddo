/// Public surface of the account-free ArtKiddo core.
///
/// Files under `src/` remain implementation details. Private mobile adapters
/// may depend on these typed contracts and repositories, but this package never
/// imports a provider SDK or a private backend identifier.
library;

export 'src/presentation/config/app_capabilities.dart';
export 'src/presentation/config/bootstrap_configuration.dart';
export 'src/presentation/config/cloud_services.dart';
export 'src/presentation/bootstrap/artkiddo_bootstrap.dart';
export 'src/contracts/auth_gateway.dart';
export 'src/contracts/gallery_sharing.dart';
export 'src/contracts/household.dart';
export 'src/contracts/object_storage.dart';
export 'src/contracts/sync_backend.dart';
export 'src/contracts/trash.dart';
export 'src/local/database/app_database.dart';
export 'src/domain/app_failure.dart';
export 'src/domain/action_result.dart';
export 'src/local/storage/local_vault.dart';
export 'src/presentation/locale/locale_provider.dart';
export 'src/presentation/navigation/app_shell.dart';
export 'src/presentation/theme/app_theme.dart';
export 'src/presentation/providers/core_providers.dart';
export 'l10n/generated/app_localizations.dart';
export 'src/local/repositories/children_repository.dart';
export 'src/local/repositories/local_trash_repository.dart';
export 'src/domain/child.dart';
export 'src/local/repositories/masterpieces_repository.dart';
export 'src/domain/masterpiece.dart';
export 'src/sync/conflict_resolution.dart';
export 'src/sync/sync_outbox.dart';
export 'src/sync/vault_meta.dart';
export 'src/debug/demo_seed.dart';
