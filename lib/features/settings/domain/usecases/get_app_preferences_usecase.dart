import '../entities/app_preferences.dart';
import '../repositories/settings_repository.dart';

class GetAppPreferencesUseCase {
  const GetAppPreferencesUseCase(this._repository);

  final SettingsRepository _repository;

  Future<AppPreferences> call() => _repository.getAppPreferences();
}
