import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';

import '../providers/core_providers.dart';
import '../../local/logging/log.dart';
import '../theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'gallery_providers.dart';

class ArtworkZoomScreen extends ConsumerStatefulWidget {
  final String masterpieceId;
  final String childName;

  const ArtworkZoomScreen({
    super.key,
    required this.masterpieceId,
    required this.childName,
  });

  @override
  ConsumerState<ArtworkZoomScreen> createState() => _ArtworkZoomScreenState();
}

class _ArtworkZoomScreenState extends ConsumerState<ArtworkZoomScreen> {
  final PhotoViewController _controller = PhotoViewController();
  double? _initialScale;
  double? _maxScale;

  @override
  void initState() {
    super.initState();
    Log.d(
      '📱 [ArtworkZoomScreen] Opening (${widget.masterpieceId})',
      'Navigation',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    final scale = _controller.scale;
    if (scale != null && _initialScale == null) {
      setState(() {
        _initialScale = scale;
        _maxScale = scale * 4; // screens.md §6: "maximale = 4×"
      });
    }
  }

  void _zoomIn() {
    final initial = _initialScale;
    final max = _maxScale;
    if (initial == null || max == null) return;
    final current = _controller.scale ?? initial;
    _controller.scale = (current * 1.5).clamp(initial, max);
  }

  void _zoomOut() {
    final initial = _initialScale;
    final max = _maxScale;
    if (initial == null || max == null) return;
    final current = _controller.scale ?? initial;
    _controller.scale = (current / 1.5).clamp(initial, max);
  }

  void _onDoubleTap() {
    final initial = _initialScale;
    if (initial == null) return;
    final current = _controller.scale ?? initial;
    _controller.scale = current > initial * 1.05 ? initial : initial * 2;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final repository = ref.watch(masterpiecesRepositoryProvider);
    final vault = ref.watch(localVaultProvider);
    final zoomReady = _initialScale != null;

    return Scaffold(
      backgroundColor: AppColors.immersive,
      appBar: AppBar(
        backgroundColor: AppColors.immersive.withValues(alpha: 0.7),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.commonClose,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.artworkTitle(widget.childName),
          style: const TextStyle(
            fontFamily: AppTypography.family,
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ),
      body: FutureBuilder(
        future: repository.getById(widget.masterpieceId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          final masterpiece = snapshot.data;
          if (masterpiece == null) {
            return _ZoomMessage(text: l10n.artworkZoomImageMissing);
          }
          final zoomPath =
              masterpiece.relativeImagePath ?? masterpiece.bestDisplayImagePath;
          return FutureBuilder<File>(
            future: zoomPath != null
                ? vault.resolveFile(zoomPath)
                : Future.value(File('')),
            builder: (context, fileSnapshot) {
              final file = fileSnapshot.data;
              if (file == null || !file.existsSync()) {
                return _ZoomMessage(text: l10n.artworkZoomImageMissing);
              }
              return Stack(
                children: [
                  GestureDetector(
                    onDoubleTap: _onDoubleTap,
                    child: PhotoView(
                      imageProvider: FileImage(file),
                      controller: _controller,
                      minScale: PhotoViewComputedScale.contained,
                      maxScale: PhotoViewComputedScale.contained * 4,
                      backgroundDecoration: const BoxDecoration(
                        color: AppColors.immersive,
                      ),
                      enablePanAlways: true,
                      loadingBuilder: (context, event) => const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                      errorBuilder: (context, error, stack) =>
                          _ZoomMessage(text: l10n.artworkZoomDecodeFailed),
                    ),
                  ),
                  _ScaleListener(
                    controller: _controller,
                    onUpdate: _onControllerUpdate,
                  ),
                  if (zoomReady)
                    Positioned(
                      right: AppSpacing.s4,
                      bottom: AppSpacing.s6,
                      child: _ZoomControls(
                        onZoomIn: _zoomIn,
                        onZoomOut: _zoomOut,
                        l10n: l10n,
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ScaleListener extends StatefulWidget {
  final PhotoViewController controller;
  final VoidCallback onUpdate;
  const _ScaleListener({required this.controller, required this.onUpdate});

  @override
  State<_ScaleListener> createState() => _ScaleListenerState();
}

class _ScaleListenerState extends State<_ScaleListener> {
  @override
  void initState() {
    super.initState();
    widget.controller.outputStateStream.listen((_) => widget.onUpdate());
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _ZoomControls extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final AppLocalizations l10n;
  const _ZoomControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.immersive.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            tooltip: l10n.artworkZoomIn,
            onPressed: onZoomIn,
          ),
          const SizedBox(height: AppSpacing.s1),
          IconButton(
            icon: const Icon(Icons.remove, color: Colors.white),
            tooltip: l10n.artworkZoomOut,
            onPressed: onZoomOut,
          ),
        ],
      ),
    );
  }
}

class _ZoomMessage extends StatelessWidget {
  final String text;
  const _ZoomMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: AppTypography.family,
          color: Colors.white70,
        ),
      ),
    );
  }
}
