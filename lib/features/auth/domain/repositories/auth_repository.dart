import '../entities/auth_session.dart';

abstract interface class AuthRepository {
  Future<AuthSession?> currentSession();

  Future<AuthSession> login({required String email, required String password});

  Future<void> logout();

  Future<AuthSession?> reloadUser();

  Future<void> sendEmailVerification();

  Future<bool> isOnboardingCompleted();

  Future<void> markOnboardingComplete();
}
