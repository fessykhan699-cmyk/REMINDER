import '../entities/profile.dart';
import '../repositories/settings_repository.dart';

class GetProfileUseCase {
  const GetProfileUseCase(this._repository);

  final SettingsRepository _repository;

  Future<UserProfile> call() => _repository.getProfile();
}
