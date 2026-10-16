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

  /// Read-only access to other households the user follows, merged into the
  /// gallery feed. Defaults to false so a composition opts in explicitly.
  final bool followedHouseholds;

  const AppCapabilities({
    required this.remoteAccount,
    required this.remoteBackup,
    required this.household,
    required this.webGalleryLinks,
    required this.trash,
    this.followedHouseholds = false,
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
    followedHouseholds: true,
  );

  bool get usesCloud =>
      remoteAccount ||
      remoteBackup ||
      household ||
      webGalleryLinks ||
      followedHouseholds ||
      trash == TrashCapability.sharedRemote;

  @override
  bool operator ==(Object other) =>
      other is AppCapabilities &&
      other.remoteAccount == remoteAccount &&
      other.remoteBackup == remoteBackup &&
      other.household == household &&
      other.webGalleryLinks == webGalleryLinks &&
      other.trash == trash &&
      other.followedHouseholds == followedHouseholds;

  @override
  int get hashCode => Object.hash(
    remoteAccount,
    remoteBackup,
    household,
    webGalleryLinks,
    trash,
    followedHouseholds,
  );

  @override
  String toString() =>
      'AppCapabilities(remoteAccount: $remoteAccount, '
      'remoteBackup: $remoteBackup, household: $household, '
      'webGalleryLinks: $webGalleryLinks, trash: $trash, '
      'followedHouseholds: $followedHouseholds)';
}
