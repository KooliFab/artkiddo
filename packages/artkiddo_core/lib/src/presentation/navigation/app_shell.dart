import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../children/children_screen.dart';
import '../gallery/gallery_actions.dart';
import '../gallery/gallery_screen.dart';

/// ArtKiddo has one home surface: [GalleryScreen].
///
/// In local / core composition, family and settings actions are surfaced
/// from the gallery's family control, opening [ChildrenScreen].
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        galleryActionsProvider.overrideWithValue(
          const GalleryActions(
            openFamilyHub: _openLocalChildren,
          ),
        ),
      ],
      child: const GalleryScreen(),
    );
  }

  static void _openLocalChildren(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ChildrenScreen(),
      ),
    );
  }
}
