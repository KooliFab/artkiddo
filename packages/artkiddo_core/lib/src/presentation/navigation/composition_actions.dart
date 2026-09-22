import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Optional destinations and platform services a composition plugs into the
/// presentation layer.
///
/// Capability-gated entries (`openAccount`, `openGalleryShare`, `syncPhotos`)
/// render only when both their capability and their binding are present. A
/// composition that enables one must supply its matching entry;
/// `ArtKiddoBootstrap` rejects a container where those two disagree.
///
/// Local-default entries (`openFamilyHub`, `openSettings`) are substitutions:
/// when null, their controls still render and open the core's local
/// `ChildrenScreen` or `SettingsScreen`. A composition may replace either
/// destination, but it must keep the replaced local-only behaviour reachable.
final class CompositionActions {
  /// Called after an artwork and its durable local sync outbox entry have
  /// been committed. Cloud compositions may use this to schedule remote work;
  /// the local composition leaves it null.
  final Future<void> Function(String artworkId)? onArtworkSaved;

  final void Function(BuildContext context)? openFamilyHub;

  /// Opens the remote gallery-link surface for one child. The name travels
  /// with the id because the destination renders it before any lookup
  /// resolves.
  final void Function(BuildContext context, String childId, String childName)?
  openGalleryShare;

  final void Function(BuildContext context)? openAccount;

  /// Opens the global settings surface (language, about, notifications,
  /// documents, account) independent of the family hub or household state.
  final void Function(BuildContext context)? openSettings;

  /// Triggers a manual photo/backup sync. A callback rather than anything
  /// status-bearing: this package owns no sync-status abstraction, so the
  /// composition that binds it runs the sync and reports progress and
  /// outcome to the user itself.
  final void Function(BuildContext context)? syncPhotos;

  final Future<String?> Function(BuildContext context)? openQrScanner;

  const CompositionActions({
    this.onArtworkSaved,
    this.openFamilyHub,
    this.openGalleryShare,
    this.openAccount,
    this.openSettings,
    this.syncPhotos,
    this.openQrScanner,
  });

  static const none = CompositionActions();
}

final compositionActionsProvider = Provider<CompositionActions>((ref) {
  return CompositionActions.none;
});
