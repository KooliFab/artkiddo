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
/// `galleryStatusBanner` is gated the same way but stays optional: it is
/// information, not a control, so leaving it unbound loses no feature.
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

  /// Best-effort propagation after the local deletion/outbox transaction.
  final Future<void> Function(String artworkId)? onArtworkDeleted;

  final Future<bool> Function(String artworkId, bool keepLocal)?
  resolveAudioConflict;

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

  /// Builds the shareable invite link for [code] in [locale]. It feeds the
  /// invite QR and the share text; when null the screen falls back to the raw
  /// code for both. The composition owns the link's host and shape, and the
  /// core recognises it again through `normalizeInviteCode`.
  final String Function(String code, Locale locale)? inviteLinkFor;

  /// A status line the composition renders above the gallery feed, for
  /// account state this package does not model (for example a vault still
  /// tied to a remote family while no session is open). Capability-gated on
  /// `remoteAccount`: the gallery builds it only when that capability is on
  /// and this entry is bound. The widget decides on its own when it has
  /// nothing to say and then collapses to zero size.
  final WidgetBuilder? galleryStatusBanner;

  const CompositionActions({
    this.onArtworkSaved,
    this.onArtworkDeleted,
    this.resolveAudioConflict,
    this.openFamilyHub,
    this.openGalleryShare,
    this.openAccount,
    this.openSettings,
    this.syncPhotos,
    this.openQrScanner,
    this.inviteLinkFor,
    this.galleryStatusBanner,
  });

  static const none = CompositionActions();
}

final compositionActionsProvider = Provider<CompositionActions>((ref) {
  return CompositionActions.none;
});
