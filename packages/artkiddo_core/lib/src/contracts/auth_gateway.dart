class AuthUser {
  final String id;
  final String? email;

  const AuthUser({required this.id, this.email});
}

class AuthSession {
  final AuthUser user;

  const AuthSession({required this.user});
}

abstract class AuthGateway {
  AuthSession? get currentSession;
  Stream<AuthSession?> get authStateChanges;
}
