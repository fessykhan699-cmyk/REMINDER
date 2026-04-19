import '../entities/auth_session.dart';

abstract interface class AuthRepository {
  Future<AuthSession?> currentSession();

  Future<AuthSession> login({required String email, required String password});
  
  Future<AuthSession> signUp({required String email, required String password});

  Future<void> logout();

  Future<AuthSession?> reloadUser();

  Future<void> sendEmailVerification();
  
  Future<void> sendPasswordResetEmail({required String email});
  
  Future<void> confirmPasswordReset({required String code, required String newPassword});

  Future<String> verifyPasswordResetCode(String code);

  Future<bool> isOnboardingCompleted();

  Future<void> markOnboardingComplete();
}
