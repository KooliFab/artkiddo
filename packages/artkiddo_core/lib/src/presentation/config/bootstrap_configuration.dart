import 'package:flutter_riverpod/misc.dart' show Override;

import 'app_capabilities.dart';
import 'cloud_services.dart';

enum AppEnvironment { local, production, test }

final class ArtKiddoBootstrapConfig {
  final AppCapabilities capabilities;
  final CloudServices? cloudServices;
  final AppEnvironment environment;

  /// Provider overrides supplied by the composition. The core declares
  /// neutral defaults; a composition replaces them with its own bindings.
  final List<Override> overrides;

  const ArtKiddoBootstrapConfig({
    required this.capabilities,
    required this.cloudServices,
    required this.environment,
    this.overrides = const [],
  });

  void validate() {
    final failures = <String>[];
    final cloud = cloudServices;

    if (capabilities.usesCloud && cloud == null) {
      failures.add('a cloud capability requires CloudServices');
    }
    if (!capabilities.usesCloud && cloud != null) {
      failures.add('the local composition must not provide CloudServices');
    }

    void requireService(CloudService service, String capability) {
      if (cloud == null || !cloud.supports(service)) {
        failures.add('$capability requires ${service.name}');
      }
    }

    if (capabilities.remoteAccount) {
      requireService(CloudService.auth, 'remoteAccount');
    }
    if (capabilities.remoteBackup) {
      if (!capabilities.remoteAccount) {
        failures.add('remoteBackup requires remoteAccount');
      }
      requireService(CloudService.syncBackend, 'remoteBackup');
      requireService(CloudService.objectUploader, 'remoteBackup');
      requireService(CloudService.objectDownloader, 'remoteBackup');
    }
    if (capabilities.household) {
      if (!capabilities.remoteAccount) {
        failures.add('household requires remoteAccount');
      }
      if (!capabilities.remoteBackup) {
        failures.add('household requires remoteBackup');
      }
      requireService(CloudService.household, 'household');
    }
    if (capabilities.webGalleryLinks) {
      if (!capabilities.remoteAccount) {
        failures.add('webGalleryLinks requires remoteAccount');
      }
      if (!capabilities.remoteBackup) {
        failures.add('webGalleryLinks requires remoteBackup');
      }
      requireService(CloudService.galleryLinks, 'webGalleryLinks');
    }
    if (capabilities.trash == TrashCapability.sharedRemote) {
      if (!capabilities.remoteAccount) {
        failures.add('sharedRemote trash requires remoteAccount');
      }
      if (!capabilities.household) {
        failures.add('sharedRemote trash requires household');
      }
      requireService(CloudService.sharedTrash, 'sharedRemote trash');
    }

    if (failures.isNotEmpty) {
      throw BootstrapConfigurationException(failures);
    }
  }
}

final class BootstrapConfigurationException extends StateError {
  final List<String> failures;

  BootstrapConfigurationException(this.failures)
    : super('Invalid ArtKiddo bootstrap configuration: ${failures.join('; ')}');
}
