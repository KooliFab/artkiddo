import 'child.dart';

/// What a parent is told about the protection of one artwork.
///
/// "Saved" never means "the original is in the cloud" (it stays on this
/// device) nor "the other device received it".
enum ArtworkBackupState {
  /// Nothing protects it but this device: no account, never sent, or kept
  /// here after the remote side purged it.
  onDevice,

  /// An operation of the artwork is waiting in the outbox or being retried.
  inProgress,

  /// The server acknowledged the row, and its optimized photo and audio were
  /// verified before that (the server refuses a patch naming unverified
  /// media). The original photo stays on this device.
  saved,

  /// A member has to act: a file is missing, or sending failed repeatedly.
  actionNeeded,
}

/// Why a state is what it is, when the interface can say more than the state.
enum ArtworkBackupReason {
  /// [ArtworkBackupState.actionNeeded]: a file the artwork points at is gone
  /// from the device. The artwork stays listed.
  missingFile,

  /// [ArtworkBackupState.actionNeeded]: sending (or downloading) failed
  /// [repeatedFailureAttempts] times.
  repeatedFailure,

  /// [ArtworkBackupState.onDevice]: purged elsewhere, restored here. The
  /// server refuses to bring it back, so it exists on this device only.
  remotePurged,
}

/// Failed attempts after which an operation stops being "in progress" and
/// asks for an action (the backoff then has reached about seven minutes).
const int repeatedFailureAttempts = 3;

class ArtworkBackupStatus {
  final ArtworkBackupState state;
  final ArtworkBackupReason? reason;
  const ArtworkBackupStatus(this.state, {this.reason});

  @override
  bool operator ==(Object other) =>
      other is ArtworkBackupStatus &&
      other.state == state &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(state, reason);

  @override
  String toString() => 'ArtworkBackupStatus($state, $reason)';
}

/// What is known locally about one artwork; every field comes from existing
/// data (the artwork row, the outbox, the vault), none from a new table.
class ArtworkBackupFacts {
  /// A remote backup capability is composed. Without it the answer is only
  /// "on this device", or "action needed" when a file is gone.
  final bool remoteBackup;

  final SyncState syncState;

  /// `artworks.remote_purged_at` is set: the remote side purged the artwork
  /// and this device kept (or restored) it.
  final bool remotePurged;

  /// Operations of the artwork still in the outbox (pending or in flight).
  final int pendingOperations;

  /// Highest `attempts` among those operations.
  final int maxAttempts;

  /// A path the artwork points at does not exist in the vault.
  final bool missingFile;

  final bool audioSyncPending;
  final bool audioConflict;

  const ArtworkBackupFacts({
    required this.remoteBackup,
    required this.syncState,
    this.remotePurged = false,
    this.pendingOperations = 0,
    this.maxAttempts = 0,
    this.missingFile = false,
    this.audioSyncPending = false,
    this.audioConflict = false,
  });
}

/// The four-state answer for one artwork. Pure: same facts, same status.
///
/// Order matters: a missing file outranks everything (it must be seen); a
/// remote purge outranks "saved" and "in progress" (the server will never hold
/// this artwork again); a queued operation outranks "saved" (INV-07: what is
/// waiting is always visible); only an acknowledged row with nothing queued is
/// "saved" (INV-06).
ArtworkBackupStatus backupStatusFor(ArtworkBackupFacts facts) {
  if (facts.missingFile) {
    return const ArtworkBackupStatus(
      ArtworkBackupState.actionNeeded,
      reason: ArtworkBackupReason.missingFile,
    );
  }
  if (!facts.remoteBackup) {
    return const ArtworkBackupStatus(ArtworkBackupState.onDevice);
  }
  if (facts.remotePurged) {
    return const ArtworkBackupStatus(
      ArtworkBackupState.onDevice,
      reason: ArtworkBackupReason.remotePurged,
    );
  }
  if (facts.maxAttempts >= repeatedFailureAttempts ||
      facts.syncState == SyncState.downloadFailed) {
    return const ArtworkBackupStatus(
      ArtworkBackupState.actionNeeded,
      reason: ArtworkBackupReason.repeatedFailure,
    );
  }
  if (facts.pendingOperations > 0) {
    return const ArtworkBackupStatus(ArtworkBackupState.inProgress);
  }
  // An audio the server has not confirmed, with nothing queued to send it,
  // is not saved and not on its way either.
  if (facts.audioSyncPending || facts.audioConflict) {
    return const ArtworkBackupStatus(ArtworkBackupState.onDevice);
  }
  return switch (facts.syncState) {
    // The row came from the server: its media were verified there.
    SyncState.synced || SyncState.remoteThumbnail => const ArtworkBackupStatus(
      ArtworkBackupState.saved,
    ),
    // Nothing queued and not acknowledged: nothing will send it.
    SyncState.localOnly ||
    SyncState.pendingUpload ||
    SyncState.syncError ||
    SyncState.downloadFailed => const ArtworkBackupStatus(
      ArtworkBackupState.onDevice,
    ),
  };
}

/// Artworks per state, for a one-line summary.
class BackupSummary {
  final int saved;
  final int inProgress;
  final int actionNeeded;
  final int onDevice;

  const BackupSummary({
    this.saved = 0,
    this.inProgress = 0,
    this.actionNeeded = 0,
    this.onDevice = 0,
  });

  factory BackupSummary.of(Iterable<ArtworkBackupStatus> statuses) {
    var saved = 0, inProgress = 0, actionNeeded = 0, onDevice = 0;
    for (final status in statuses) {
      switch (status.state) {
        case ArtworkBackupState.saved:
          saved++;
        case ArtworkBackupState.inProgress:
          inProgress++;
        case ArtworkBackupState.actionNeeded:
          actionNeeded++;
        case ArtworkBackupState.onDevice:
          onDevice++;
      }
    }
    return BackupSummary(
      saved: saved,
      inProgress: inProgress,
      actionNeeded: actionNeeded,
      onDevice: onDevice,
    );
  }

  int get total => saved + inProgress + actionNeeded + onDevice;
}
