import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../domain/backup_status.dart';
import '../theme/app_tokens.dart';

/// The short name of a state, the one word the parent reads on a card, in the
/// artwork sheet and in the settings summary.
String backupStateLabel(AppLocalizations l10n, ArtworkBackupState state) =>
    switch (state) {
      ArtworkBackupState.onDevice => l10n.backupStateOnDevice,
      ArtworkBackupState.inProgress => l10n.backupStateInProgress,
      ArtworkBackupState.saved => l10n.backupStateSaved,
      ArtworkBackupState.actionNeeded => l10n.backupStateActionNeeded,
    };

/// What the parent can do or must know, when the state alone is not enough.
/// Null when nothing more is worth saying.
String? backupStateDetail(AppLocalizations l10n, ArtworkBackupStatus status) {
  return switch (status.reason) {
    ArtworkBackupReason.missingFile => l10n.backupReasonMissingFile,
    ArtworkBackupReason.repeatedFailure => l10n.backupReasonRepeatedFailure,
    ArtworkBackupReason.remotePurged => l10n.backupReasonRemotePurged,
    null => l10n.backupOriginalStaysOnDevice,
  };
}

(IconData, Color, Color) _look(ArtworkBackupState state) => switch (state) {
  ArtworkBackupState.onDevice => (
    Icons.smartphone_rounded,
    AppColors.surfaceSunken,
    AppColors.inkMuted,
  ),
  ArtworkBackupState.inProgress => (
    Icons.cloud_upload_outlined,
    AppColors.ochreSurface,
    AppColors.ink,
  ),
  ArtworkBackupState.saved => (
    Icons.cloud_done_outlined,
    AppColors.sageSurface,
    AppColors.sageInk,
  ),
  ArtworkBackupState.actionNeeded => (
    Icons.error_outline_rounded,
    AppColors.dangerSurface,
    AppColors.danger,
  ),
};

/// The round marker on a gallery card. Icon only, so the state is also read
/// aloud through [Semantics].
class BackupStatusBadge extends StatelessWidget {
  final ArtworkBackupState state;
  const BackupStatusBadge({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final (icon, background, foreground) = _look(state);
    return Semantics(
      label: backupStateLabel(AppLocalizations.of(context), state),
      child: ExcludeSemantics(
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.surface, width: 1.5),
          ),
          child: Icon(icon, size: 14, color: foreground),
        ),
      ),
    );
  }
}

/// The status row of the artwork sheet: state, then the detail line.
class BackupStatusLine extends StatelessWidget {
  final ArtworkBackupStatus status;
  const BackupStatusLine({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (icon, background, foreground) = _look(status.state);
    final detail = backupStateDetail(l10n, status);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: background, shape: BoxShape.circle),
          child: Icon(icon, size: 16, color: foreground),
        ),
        const SizedBox(width: AppSpacing.s2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                backupStateLabel(l10n, status.state),
                style: AppTypography.bodyStrong,
              ),
              if (detail != null)
                Text(
                  detail,
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
