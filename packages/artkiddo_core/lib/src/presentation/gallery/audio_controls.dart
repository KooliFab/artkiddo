import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../theme/app_tokens.dart';
import '../ui/app_button.dart';

/// `mm:ss` for a voice-story duration.
String formatAudioDuration(int ms) {
  final totalSeconds = (ms / 1000).floor();
  final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// A take in progress: elapsed time against the two-minute limit, the live
/// input level, and the two ways out (discard the take, or stop and keep
/// it). Shared by capture and the artwork's recorder sheet.
class AudioRecordingPanel extends StatelessWidget {
  final int durationMs;
  final double soundLevel;
  final VoidCallback onCancel;
  final VoidCallback onStop;

  const AudioRecordingPanel({
    super.key,
    required this.durationMs,
    required this.soundLevel,
    required this.onCancel,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.danger,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.s2),
            Text(
              l10n.captureAudioRecording,
              style: AppTypography.bodyStrong.copyWith(color: AppColors.accent),
            ),
            const Spacer(),
            Text(
              '${formatAudioDuration(durationMs)} / 02:00',
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s3),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.xs),
          child: LinearProgressIndicator(
            value: soundLevel.clamp(0.05, 1.0),
            backgroundColor: AppColors.surfaceSunken,
            valueColor: const AlwaysStoppedAnimation(AppColors.accent),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: AppSpacing.s3),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: AppColors.ink),
              icon: const Icon(Icons.close, size: 18),
              label: Text(l10n.captureAudioCancel),
              onPressed: onCancel,
            ),
            AppButton(
              label: l10n.captureAudioStop,
              icon: Icons.stop,
              onPressed: onStop,
            ),
          ],
        ),
      ],
    );
  }
}

/// Play/pause with the playback position. Shared by capture, the recorder
/// sheet's preview and the artwork's saved voice story.
class AudioPlaybackRow extends StatelessWidget {
  final bool isPlaying;
  final int positionMs;
  final int durationMs;
  final VoidCallback? onToggle;

  const AudioPlaybackRow({
    super.key,
    required this.isPlaying,
    required this.positionMs,
    required this.durationMs,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        IconButton.filled(
          tooltip: isPlaying ? l10n.captureAudioPause : l10n.captureAudioPlay,
          icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
          onPressed: onToggle,
          style: IconButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.onAccent,
          ),
        ),
        const SizedBox(width: AppSpacing.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.xs),
                child: LinearProgressIndicator(
                  value: durationMs > 0
                      ? (positionMs / durationMs).clamp(0.0, 1.0)
                      : 0.0,
                  backgroundColor: AppColors.surfaceSunken,
                  valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: AppSpacing.s1),
              Text(
                '${formatAudioDuration(positionMs)} / ${formatAudioDuration(durationMs)}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
