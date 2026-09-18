import '../../domain/app_failure.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'state_block.dart';

class PresentedError {
  final String title;
  final String? body;
  final String actionLabel;

  const PresentedError({
    required this.title,
    this.body,
    required this.actionLabel,
  });
}

/// Single translation point for [AppFailure] -> (title, body, retry label).
///
/// No screen composes its own error message and no `toString()` of an
/// exception ever reaches the UI — `cause`/`stack` stay in diagnostics.
class ErrorPresenter {
  const ErrorPresenter._();

  static PresentedError present(AppLocalizations l10n, AppFailure failure) {
    return switch (failure) {
      LocalWriteFailure() => PresentedError(
        title: l10n.errorLocalWriteTitle,
        body: l10n.errorLocalWriteBody,
        actionLabel: l10n.commonRetry,
      ),
      StorageFullFailure() => PresentedError(
        title: l10n.captureErrorStorageFullTitle,
        body: l10n.captureErrorStorageFullBody,
        actionLabel: l10n.commonRetry,
      ),
      FileMissingFailure() => PresentedError(
        title: l10n.artworkImageMissingTitle,
        body: l10n.artworkImageMissingBody,
        actionLabel: l10n.artworkDelete,
      ),
      ImageUnreadableFailure() => PresentedError(
        title: l10n.captureReviewUnreadable,
        actionLabel: l10n.captureReviewRetake,
      ),
      PermissionDeniedFailure(kind: final kind) => PresentedError(
        title: kind == PermissionKind.camera
            ? l10n.permissionCameraDeniedTitle
            : l10n.permissionPhotosDeniedTitle,
        body: kind == PermissionKind.camera
            ? l10n.permissionCameraDeniedBody
            : l10n.permissionPhotosDeniedBody,
        actionLabel: l10n.commonOpenSettings,
      ),
      NetworkFailure() => PresentedError(
        title: l10n.errorNetworkTitle,
        body: l10n.errorNetworkBody,
        actionLabel: l10n.commonRetry,
      ),
      ServiceFailure() => PresentedError(
        title: l10n.errorServiceTitle,
        body: l10n.errorServiceBody,
        actionLabel: l10n.commonRetry,
      ),
      AuthInvalidCredentialsFailure() => PresentedError(
        title: l10n.accountErrorInvalidCredentials,
        actionLabel: l10n.commonRetry,
      ),
      AuthWeakPasswordFailure() => PresentedError(
        title: l10n.accountErrorWeakPassword,
        actionLabel: l10n.commonRetry,
      ),
      RateLimitedFailure(retryAfter: final retryAfter) => PresentedError(
        title: l10n.accountErrorRateLimited(retryAfter?.inSeconds ?? 0),
        actionLabel: l10n.commonRetry,
      ),
      NotSignedInFailure() => PresentedError(
        title: l10n.errorNotSignedInTitle,
        body: l10n.errorNotSignedInBody,
        actionLabel: l10n.accountSubmit,
      ),
      NotFoundFailure() => PresentedError(
        title: l10n.errorNotFoundTitle,
        body: l10n.errorNotFoundBody,
        actionLabel: l10n.commonClose,
      ),
      UnavailableFailure() => PresentedError(
        title: l10n.errorUnavailableTitle,
        body: l10n.errorUnavailableBody,
        actionLabel: l10n.commonContactUs,
      ),
      UnknownFailure() => PresentedError(
        title: l10n.errorUnknownTitle,
        body: l10n.errorUnknownBody,
        actionLabel: l10n.commonRetry,
      ),
      // Never retryable on its own — the action offered is the way
      // out (sign out and keep working locally), not another attempt.
      FoyerMismatchFailure() => PresentedError(
        title: l10n.errorFoyerMismatchTitle,
        body: l10n.errorFoyerMismatchBody,
        actionLabel: l10n.accountSignOut,
      ),
      // Retryable on its own (a purge or an expiry frees space) —
      // same retry action as any other transient send failure, no
      // member decision required.
      QuotaExceededFailure(:final resetsAt) => PresentedError(
        title: resetsAt != null
            ? '${l10n.errorQuotaExceededTitle} (disponible à ${resetsAt.toLocal().hour.toString().padLeft(2, '0')}:${resetsAt.toLocal().minute.toString().padLeft(2, '0')})'
            : l10n.errorQuotaExceededTitle,
        body: l10n.errorQuotaExceededBody,
        actionLabel: l10n.commonRetry,
      ),
      GlobalUploadsSuspendedFailure(:final message) => PresentedError(
        title: l10n.syncUploadSuspendedTitle,
        body: message,
        actionLabel: l10n.commonUnderstood,
      ),
    };
  }

  static StateBlockIntent intentFor(AppFailure failure) {
    if (failure is PermissionDeniedFailure || failure is StorageFullFailure) {
      return StateBlockIntent.warning;
    }
    return StateBlockIntent.error;
  }
}
