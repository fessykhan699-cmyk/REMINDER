import '../../domain/entities/app_preferences.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/settings_local_datasource.dart';
import '../models/app_preferences_model.dart';
import '../models/profile_model.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  const SettingsRepositoryImpl(this._datasource);

  final SettingsLocalDatasource _datasource;

  @override
  Future<UserProfile> getProfile() => _datasource.getProfile();

  @override
  Future<UserProfile> saveProfile(UserProfile profile) {
    return _datasource.saveProfile(ProfileModel.fromEntity(profile));
  }

  @override
  Future<AppPreferences> getAppPreferences() {
    return _datasource.getAppPreferences();
  }

  @override
  Future<AppPreferences> saveAppPreferences(AppPreferences preferences) {
    return _datasource.saveAppPreferences(
      AppPreferencesModel.fromEntity(preferences),
    );
  }
}
