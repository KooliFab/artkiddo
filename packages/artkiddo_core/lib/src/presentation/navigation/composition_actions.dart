import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Optional destinations and platform services a composition plugs into the
/// presentation layer.
///
/// A null entry means the composition offers no such destination, and the
/// corresponding affordance is not rendered. A composition that enables a
/// capability must supply the matching entry; `ArtKiddoBootstrap` rejects a
/// container whose capabilities and actions disagree, so an enabled capability
/// can never degrade into a silently hidden control.
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
  final Future<String?> Function(BuildContext context)? openQrScanner;

  const CompositionActions({
    this.onArtworkSaved,
    this.openFamilyHub,
    this.openGalleryShare,
    this.openAccount,
    this.openQrScanner,
  });

  static const none = CompositionActions();
}

final compositionActionsProvider = Provider<CompositionActions>((ref) {
  return CompositionActions.none;
});
