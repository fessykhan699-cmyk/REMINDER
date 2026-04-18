import '../../domain/entities/auth_session.dart';

class AuthSessionModel extends AuthSession {
  const AuthSessionModel({
    required super.userId,
    required super.email,
    required super.token,
    required super.createdAt,
    super.isEmailVerified = false,
  });

  factory AuthSessionModel.fromEntity(AuthSession session) {
    return AuthSessionModel(
      userId: session.userId,
      email: session.email,
      token: session.token,
      createdAt: session.createdAt,
    );
  }
}
