import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Optional destinations and platform services a composition can plug into
/// the presentation layer.
/// A null entry means the composition offers no such destination/service and the
/// corresponding affordance is not rendered.
final class CompositionActions {
  final void Function(BuildContext context)? openFamilyHub;
  final void Function(BuildContext context, String childId)? openGalleryShare;
  final void Function(BuildContext context)? openAccount;
  final Future<String?> Function(BuildContext context)? openQrScanner;

  const CompositionActions({
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

/// Backwards compatibility alias for the transitional migration phase.
typedef GalleryActions = CompositionActions;

/// Backwards compatibility alias for the transitional migration phase.
final galleryActionsProvider = compositionActionsProvider;
