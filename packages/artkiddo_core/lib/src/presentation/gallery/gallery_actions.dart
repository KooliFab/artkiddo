import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Optional destinations a composition can plug into the gallery.
/// A null entry means the composition offers no such destination and the
/// corresponding affordance is not rendered.
final class GalleryActions {
  final void Function(BuildContext context)? openFamilyHub;
  final void Function(BuildContext context, String childId)? openGalleryShare;

  const GalleryActions({this.openFamilyHub, this.openGalleryShare});

  static const none = GalleryActions();
}

final galleryActionsProvider = Provider<GalleryActions>((ref) {
  return GalleryActions.none;
});
