enum TrashCapability { local, sharedRemote }

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

  static const local = AppCapabilities(
    remoteAccount: false,
    remoteBackup: false,
    household: false,
    webGalleryLinks: false,
    trash: TrashCapability.local,
  );

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
