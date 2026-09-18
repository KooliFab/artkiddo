/// Concrete service slots required by a cloud composition.
///
/// The enum is intentionally vendor-neutral. Concrete backend implementations are
/// registered by the private composition; public code only reasons about these requirements.
enum CloudService {
  auth,
  syncBackend,
  objectUploader,
  objectDownloader,
  household,
  galleryLinks,
  sharedTrash,
  accountLifecycle,
}

typedef CloudInitializer = Future<void> Function();

/// Services available to a cloud composition.
final class CloudServices {
  final Set<CloudService> available;
  final CloudInitializer? initialize;

  const CloudServices({required this.available, this.initialize});

  /// A composition with no network services. It is not accepted for a local
  /// app as a non-null value; use `cloudServices: null` for local mode so an
  /// accidental provider read fails loudly.
  static const none = CloudServices(available: <CloudService>{});

  /// All service slots used by the current private mobile application.
  static const production = CloudServices(
    available: <CloudService>{
      CloudService.auth,
      CloudService.syncBackend,
      CloudService.objectUploader,
      CloudService.objectDownloader,
      CloudService.household,
      CloudService.galleryLinks,
      CloudService.sharedTrash,
      CloudService.accountLifecycle,
    },
  );

  bool supports(CloudService service) => available.contains(service);

  void require(CloudService service) {
    if (!supports(service)) {
      throw CloudServiceUnavailableException(service);
    }
  }

  @override
  bool operator ==(Object other) =>
      other is CloudServices &&
      other.available.length == available.length &&
      other.available.containsAll(available) &&
      other.available.every(available.contains);

  @override
  int get hashCode {
    final indexes = available.map((service) => service.index).toList()..sort();
    return Object.hashAll(indexes);
  }
}

/// Raised when a provider is read without the capability/service that owns it.
final class CloudServiceUnavailableException extends StateError {
  final CloudService service;

  CloudServiceUnavailableException(this.service)
    : super('Cloud service ${service.name} is unavailable in this composition');
}
