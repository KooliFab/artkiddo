import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/bootstrap_configuration.dart';
import '../config/app_capabilities.dart';
import '../providers/core_providers.dart';
import '../../local/logging/log.dart';
import '../../domain/action_result.dart';
import '../gallery/gallery_providers.dart';
import '../navigation/composition_actions.dart';
import '../../contracts/remote_media.dart';
import '../../contracts/household.dart';
import '../../contracts/gallery_sharing.dart';
import '../family/family_controller.dart' show familyApiProvider;
import '../sharing/share_controller.dart'
    show sharingServiceProvider, shareBackupProvider;
import '../../local/repositories/trash_repository.dart';

/// Creates the provider graph after validating capabilities and services.
///
/// The bootstrap has no vendor dependency. A private composition may provide
/// an initializer through [CloudServices]; the local composition passes null,
/// so no network SDK is initialized.
abstract final class ArtKiddoBootstrap {
  static ProviderContainer createContainer(ArtKiddoBootstrapConfig config) {
    config.validate();
    final container = ProviderContainer(
      overrides: [
        appCapabilitiesProvider.overrideWithValue(config.capabilities),
        cloudServicesProvider.overrideWithValue(config.cloudServices),
        appEnvironmentProvider.overrideWithValue(config.environment),
        ...config.overrides,
      ],
    );
    try {
      _validateComposition(container, config.capabilities);
    } on BootstrapConfigurationException {
      container.dispose();
      rethrow;
    }
    return container;
  }

  /// Rejects a container whose capabilities are not backed by real bindings.
  ///
  /// `validate()` checks the declared configuration; this checks what the
  /// overrides actually produced. Without it, a composition that enables a
  /// capability but forgets its binding starts normally and degrades into a
  /// hidden control or a no-op service — the silent local/remote fallback the
  /// architecture forbids.
  static void _validateComposition(
    ProviderContainer container,
    AppCapabilities capabilities,
  ) {
    final failures = <String>[];
    final actions = container.read(compositionActionsProvider);

    if (capabilities.remoteAccount && actions.openAccount == null) {
      failures.add('remoteAccount requires a CompositionActions.openAccount');
    }
    if (capabilities.household && actions.openFamilyHub == null) {
      failures.add('household requires a CompositionActions.openFamilyHub');
    }
    if (capabilities.webGalleryLinks && actions.openGalleryShare == null) {
      failures.add(
        'webGalleryLinks requires a CompositionActions.openGalleryShare',
      );
    }
    if (capabilities.remoteBackup &&
        container.read(remoteMediaFetcherProvider) is NoRemoteMediaFetcher) {
      failures.add('remoteBackup requires a RemoteMediaFetcher binding');
    }
    // The gallery renders its manual-sync control on `remoteBackup`. Without
    // this rule a composition could enable the capability, omit the action,
    // and ship a build that backs up in the background with no way for the
    // user to trigger or observe it — the hidden-control degradation the
    // rest of this method exists to prevent.
    if (capabilities.remoteBackup && actions.syncPhotos == null) {
      failures.add('remoteBackup requires a CompositionActions.syncPhotos');
    }
    if (capabilities.household &&
        container.read(familyApiProvider) is NoFamilyApi) {
      failures.add('household requires a FamilyApi binding');
    }
    if (capabilities.webGalleryLinks &&
        container.read(sharingServiceProvider) is NoSharingService) {
      failures.add('webGalleryLinks requires a SharingService binding');
    }
    if (capabilities.webGalleryLinks &&
        container.read(shareBackupProvider) == null) {
      failures.add('webGalleryLinks requires a ShareBackup binding');
    }

    if (failures.isNotEmpty) {
      throw BootstrapConfigurationException(failures);
    }
  }

  /// Initializes the optional cloud service and schedules local maintenance.
  static Future<ProviderContainer> start(ArtKiddoBootstrapConfig config) async {
    config.validate();
    await config.cloudServices?.initialize?.call();
    final container = createContainer(config);
    _scheduleLocalMaintenance(container);
    return container;
  }

  static void _scheduleLocalMaintenance(ProviderContainer container) {
    unawaited(
      container
          .read(localVaultProvider)
          .retryPendingCleanups(container.read(appDatabaseProvider))
          .catchError((Object error, StackTrace stack) {
            Log.e(
              'Échec du nettoyage différé au démarrage',
              error,
              stack,
              'Vault',
            );
          }),
    );
    unawaited(
      container
          .read(artworksRepositoryProvider)
          .backfillMissingDerivatives()
          .then((summary) {
            Log.i(
              'Backfill des dérivés terminé : '
                  '${summary.succeeded}/${summary.attempted} réussis, '
                  '${summary.failed} échecs',
              'Derivatives',
            );
          })
          .catchError((Object error, StackTrace stack) {
            Log.e(
              'Échec du backfill des dérivés au démarrage',
              error,
              stack,
              'Derivatives',
            );
          }),
    );
    if (container.read(appCapabilitiesProvider).trash ==
        TrashCapability.local) {
      unawaited(
        container
            .read(trashRepositoryProvider)
            .purgeExpired()
            .then((result) {
              if (result case ActionSuccess(value: final count)) {
                if (count > 0) {
                  Log.i('$count œuvre(s) purgée(s) automatiquement', 'Trash');
                }
              }
            })
            .catchError((Object error, StackTrace stack) {
              Log.e(
                'Échec de la purge automatique de la Corbeille locale',
                error,
                stack,
                'Trash',
              );
            }),
      );
    }
  }
}
