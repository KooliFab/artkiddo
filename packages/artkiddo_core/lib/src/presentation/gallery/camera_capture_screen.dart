import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../local/logging/log.dart';
import '../theme/app_tokens.dart';
import '../ui/app_button.dart';
import '../utils/app_settings_launcher.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Outcome of a [CameraCaptureScreen] round trip, popped back to whoever
/// pushed it (`_acquirePhoto` in capture presentation).
sealed class CameraCaptureOutcome {
  const CameraCaptureOutcome();
}

class CameraCaptureSuccess extends CameraCaptureOutcome {
  final String path;
  const CameraCaptureSuccess(this.path);
}

class CameraCaptureDenied extends CameraCaptureOutcome {
  const CameraCaptureDenied();
}

class CameraCaptureCancelled extends CameraCaptureOutcome {
  const CameraCaptureCancelled();
}

/// Replaces the OS camera app (which shows its own "Retake / Use Photo"
/// confirmation) with a live, in-app viewfinder. The only confirmation left for
/// a camera-sourced photo is the crop step that follows (`CaptureController.cropDraft`).
class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _releasedForBackground = false;
  Future<void>? _initializeFuture;
  bool _denied = false;
  bool _unavailable = false;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeFuture = _init();
  }

  Future<void> _init() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _unavailable = true);
        return;
      }
      final description = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        description,
        ResolutionPreset.veryHigh,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } on CameraException catch (e, st) {
      Log.e('Ouverture de la caméra refusée', e, st, 'Capture');
      if (mounted) setState(() => _denied = true);
    } catch (e, st) {
      Log.e('Ouverture de la caméra impossible', e, st, 'Capture');
      if (mounted) setState(() => _unavailable = true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    final controller = _controller;
    if (lifecycleState == AppLifecycleState.inactive) {
      if (controller == null || !controller.value.isInitialized) return;
      // Drop the preview from the tree before disposing, otherwise the next
      // frame builds CameraPreview on a disposed controller.
      setState(() => _controller = null);
      _releasedForBackground = true;
      controller.dispose();
    } else if (lifecycleState == AppLifecycleState.resumed &&
        _releasedForBackground) {
      _releasedForBackground = false;
      setState(() => _initializeFuture = _init());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) {
      return;
    }
    setState(() => _capturing = true);
    try {
      final file = await controller.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(CameraCaptureSuccess(file.path));
    } catch (e, st) {
      Log.e('Capture photo impossible', e, st, 'Capture');
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () =>
              Navigator.of(context).pop(const CameraCaptureCancelled()),
        ),
      ),
      body: FutureBuilder<void>(
        future: _initializeFuture,
        builder: (context, snapshot) {
          if (_denied) {
            return _buildMessage(
              l10n.permissionCameraDeniedBody,
              l10n,
              showSettings: true,
            );
          }
          if (_unavailable) {
            return _buildMessage(
              l10n.permissionCameraReason,
              l10n,
              showSettings: false,
            );
          }
          final controller = _controller;
          if (controller == null || !controller.value.isInitialized) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          return Stack(
            fit: StackFit.expand,
            children: [
              Center(child: CameraPreview(controller)),
              Positioned(
                left: 0,
                right: 0,
                bottom: AppSpacing.s6,
                child: Center(
                  child: GestureDetector(
                    onTap: _capturing ? null : _capture,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: Colors.white54, width: 4),
                      ),
                      child: _capturing
                          ? const Padding(
                              padding: EdgeInsets.all(22),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMessage(
    String body,
    AppLocalizations l10n, {
    required bool showSettings,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              body,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: Colors.white),
            ),
            if (showSettings) ...[
              const SizedBox(height: AppSpacing.s4),
              AppButton(
                label: l10n.commonOpenSettings,
                variant: AppButtonVariant.secondary,
                onPressed: () => AppSettingsLauncher.open(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
