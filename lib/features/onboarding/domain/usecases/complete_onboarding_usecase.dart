import '../../../auth/domain/repositories/auth_repository.dart';

class CompleteOnboardingUseCase {
  const CompleteOnboardingUseCase(this._authRepository);

  final AuthRepository _authRepository;

  Future<void> call() => _authRepository.markOnboardingComplete();
}
