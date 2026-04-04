import '../../domain/entities/app_preferences.dart';
import '../../domain/entities/profile.dart';

abstract interface class SettingsRepository {
  Future<UserProfile> getProfile();

  Future<UserProfile> saveProfile(UserProfile profile);

  Future<AppPreferences> getAppPreferences();

  Future<AppPreferences> saveAppPreferences(AppPreferences preferences);
}
