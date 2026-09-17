import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/bootstrap_configuration.dart';
import '../config/app_capabilities.dart';
import '../providers/core_providers.dart';
import '../../local/logging/log.dart';
import '../../domain/action_result.dart';
import '../gallery/gallery_providers.dart';
import '../../local/repositories/trash_repository.dart';

abstract final class ArtKiddoBootstrap {
  static ProviderContainer createContainer(ArtKiddoBootstrapConfig config) {
    config.validate();
    return ProviderContainer(
      overrides: [
        appCapabilitiesProvider.overrideWithValue(config.capabilities),
        cloudServicesProvider.overrideWithValue(config.cloudServices),
        appEnvironmentProvider.overrideWithValue(config.environment),
        ...config.overrides,
      ],
    );
  }

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
          .read(masterpiecesRepositoryProvider)
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
