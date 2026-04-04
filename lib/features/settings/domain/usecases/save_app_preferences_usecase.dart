import '../entities/app_preferences.dart';
import '../repositories/settings_repository.dart';

class SaveAppPreferencesUseCase {
  const SaveAppPreferencesUseCase(this._repository);

  final SettingsRepository _repository;

  Future<AppPreferences> call(AppPreferences preferences) {
    return _repository.saveAppPreferences(preferences);
  }
}
