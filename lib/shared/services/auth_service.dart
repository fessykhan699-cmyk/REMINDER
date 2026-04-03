import '../../features/auth/domain/entities/auth_session.dart';

abstract interface class AuthService {
  Future<AuthSession?> currentSession();

  Future<AuthSession> login({required String email, required String password});

  Future<void> logout();

  Future<bool> isOnboardingCompleted();

  Future<void> setOnboardingCompleted(bool value);
}
