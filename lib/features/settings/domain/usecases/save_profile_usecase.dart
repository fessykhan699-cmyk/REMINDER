import '../entities/profile.dart';
import '../repositories/settings_repository.dart';

class SaveProfileUseCase {
  const SaveProfileUseCase(this._repository);

  final SettingsRepository _repository;

  Future<UserProfile> call(UserProfile profile) {
    return _repository.saveProfile(profile);
  }
}
