import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._datasource);

  final AuthLocalDatasource _datasource;

  @override
  Future<AuthSession?> currentSession() => _datasource.currentSession();

  @override
  Future<AuthSession> login({required String email, required String password}) {
    return _datasource.login(email: email, password: password);
  }

  @override
  Future<void> logout() => _datasource.logout();

  @override
  Future<AuthSession?> reloadUser() => _datasource.reloadUser();

  @override
  Future<void> sendEmailVerification() => _datasource.sendEmailVerification();

  @override
  Future<bool> isOnboardingCompleted() => _datasource.isOnboardingCompleted();

  @override
  Future<void> markOnboardingComplete() => _datasource.markOnboardingComplete();
}
