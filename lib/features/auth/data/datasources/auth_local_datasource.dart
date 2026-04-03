import '../models/auth_session_model.dart';

class AuthLocalDatasource {
  AuthSessionModel? _session;
  bool _onboardingCompleted = false;

  Future<AuthSessionModel?> currentSession() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return _session;
  }

  Future<AuthSessionModel> login({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 420));

    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty || password.trim().isEmpty) {
      throw Exception('Email and password are required.');
    }

    _session = AuthSessionModel(
      userId: 'user-1',
      email: normalizedEmail,
      token: 'local-dev-token',
      createdAt: DateTime.now(),
    );
    return _session!;
  }

  Future<void> logout() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    _session = null;
  }

  Future<bool> isOnboardingCompleted() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _onboardingCompleted;
  }

  Future<void> markOnboardingComplete() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    _onboardingCompleted = true;
  }
}
