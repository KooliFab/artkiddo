/// Capabilities exposed by one ArtKiddo application composition.
///
/// This type deliberately contains product capabilities rather than provider
/// names. The local application can therefore be composed without importing a
/// cloud SDK, while the store application can opt into the same UI contracts.
enum TrashCapability {
  /// A device-local, recoverable trash (implemented by the local repository).
  local,

  /// A household-wide trash backed by the private service.
  sharedRemote,
}

/// Product capabilities enabled for a running application.
final class AppCapabilities {
  final bool remoteAccount;
  final bool remoteBackup;
  final bool household;
  final bool webGalleryLinks;
  final TrashCapability trash;

  const AppCapabilities({
    required this.remoteAccount,
    required this.remoteBackup,
    required this.household,
    required this.webGalleryLinks,
    required this.trash,
  });

  /// The complete account-free, offline-first composition.
  static const local = AppCapabilities(
    remoteAccount: false,
    remoteBackup: false,
    household: false,
    webGalleryLinks: false,
    trash: TrashCapability.local,
  );

  /// The current store/cloud composition.
  static const cloud = AppCapabilities(
    remoteAccount: true,
    remoteBackup: true,
    household: true,
    webGalleryLinks: true,
    trash: TrashCapability.sharedRemote,
  );

  bool get usesCloud =>
      remoteAccount ||
      remoteBackup ||
      household ||
      webGalleryLinks ||
      trash == TrashCapability.sharedRemote;

  @override
  bool operator ==(Object other) =>
      other is AppCapabilities &&
      other.remoteAccount == remoteAccount &&
      other.remoteBackup == remoteBackup &&
      other.household == household &&
      other.webGalleryLinks == webGalleryLinks &&
      other.trash == trash;

  @override
  int get hashCode => Object.hash(
    remoteAccount,
    remoteBackup,
    household,
    webGalleryLinks,
    trash,
  );

  @override
  String toString() =>
      'AppCapabilities(remoteAccount: $remoteAccount, '
      'remoteBackup: $remoteBackup, household: $household, '
      'webGalleryLinks: $webGalleryLinks, trash: $trash)';
}
