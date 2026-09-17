import 'package:flutter/material.dart';

import '../gallery/gallery_screen.dart';

/// ArtKiddo has one home surface: [GalleryScreen].
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) => const GalleryScreen();
}
