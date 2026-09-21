sealed class AppFailure {
  final Object? cause;
  final StackTrace? stack;

  const AppFailure({this.cause, this.stack});
}

class LocalWriteFailure extends AppFailure {
  const LocalWriteFailure({super.cause, super.stack});
}

class StorageFullFailure extends AppFailure {
  const StorageFullFailure({super.cause, super.stack});
}

class FileMissingFailure extends AppFailure {
  const FileMissingFailure({super.cause, super.stack});
}

class ImageUnreadableFailure extends AppFailure {
  const ImageUnreadableFailure({super.cause, super.stack});
}

enum PermissionKind { camera, photos }

class PermissionDeniedFailure extends AppFailure {
  final PermissionKind kind;
  const PermissionDeniedFailure(this.kind, {super.cause, super.stack});
}

class NetworkFailure extends AppFailure {
  const NetworkFailure({super.cause, super.stack});
}

class ServiceFailure extends AppFailure {
  final int? code;
  const ServiceFailure({this.code, super.cause, super.stack});
}

class AuthInvalidCredentialsFailure extends AppFailure {
  const AuthInvalidCredentialsFailure({super.cause, super.stack});
}

class AuthWeakPasswordFailure extends AppFailure {
  const AuthWeakPasswordFailure({super.cause, super.stack});
}

class RateLimitedFailure extends AppFailure {
  final Duration? retryAfter;
  const RateLimitedFailure({this.retryAfter, super.cause, super.stack});
}

class NotSignedInFailure extends AppFailure {
  const NotSignedInFailure({super.cause, super.stack});
}

class NotFoundFailure extends AppFailure {
  const NotFoundFailure({super.cause, super.stack});
}

class UnavailableFailure extends AppFailure {
  const UnavailableFailure({super.cause, super.stack});
}

class UnknownFailure extends AppFailure {
  const UnknownFailure({super.cause, super.stack});
}

class FamilyMismatchFailure extends AppFailure {
  final String vaultFamilyId;
  final String authenticatedFamilyId;
  const FamilyMismatchFailure({
    required this.vaultFamilyId,
    required this.authenticatedFamilyId,
    super.cause,
    super.stack,
  });
}

class QuotaExceededFailure extends AppFailure {
  final DateTime? resetsAt;
  const QuotaExceededFailure({this.resetsAt, super.cause, super.stack});
}

class GlobalUploadsSuspendedFailure extends AppFailure {
  final String message;
  const GlobalUploadsSuspendedFailure({
    this.message =
        'Les nouvelles sauvegardes sont suspendues afin de maintenir l\'application gratuite.',
    super.cause,
    super.stack,
  });
}
