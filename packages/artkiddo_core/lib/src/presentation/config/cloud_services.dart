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

final class CloudServices {
  final Set<CloudService> available;
  final CloudInitializer? initialize;

  const CloudServices({required this.available, this.initialize});

  static const none = CloudServices(available: <CloudService>{});

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

final class CloudServiceUnavailableException extends StateError {
  final CloudService service;

  CloudServiceUnavailableException(this.service)
    : super('Cloud service ${service.name} is unavailable in this composition');
}
