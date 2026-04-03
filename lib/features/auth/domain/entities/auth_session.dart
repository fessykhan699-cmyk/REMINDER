enum AuthStatus { initializing, authenticated, unauthenticated }

class AuthSession {
  const AuthSession({
    required this.userId,
    required this.email,
    required this.token,
    required this.createdAt,
  });

  final String userId;
  final String email;
  final String token;
  final DateTime createdAt;
}
