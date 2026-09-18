import 'package:flutter/material.dart';

import '../gallery/gallery_screen.dart';

/// ArtKiddo has one home surface. Low-frequency family and settings actions
/// are presented from the gallery's family control rather than persistent
/// tabs competing with the artwork.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) => const GalleryScreen();
}
