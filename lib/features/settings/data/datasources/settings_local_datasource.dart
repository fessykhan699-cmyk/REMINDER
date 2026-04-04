import 'package:hive/hive.dart';

import '../../../../core/storage/hive_storage.dart';
import '../models/app_preferences_model.dart';
import '../models/profile_model.dart';

class SettingsLocalDatasource {
  static const String _userProfileKey = 'currentUserProfile';
  static const String _appPreferencesKey = 'appPreferences';

  final Box<ProfileModel> _profileBox = Hive.box<ProfileModel>(
    HiveStorage.userProfileBoxName,
  );
  final Box<AppPreferencesModel> _preferencesBox =
      Hive.box<AppPreferencesModel>(HiveStorage.appPreferencesBoxName);

  Future<ProfileModel> getProfile() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _profileBox.get(_userProfileKey) ??
        const ProfileModel(
          name: '',
          email: '',
          businessName: '',
          phone: '',
          address: '',
        );
  }

  Future<ProfileModel> saveProfile(ProfileModel profile) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await _profileBox.put(_userProfileKey, profile);
    return profile;
  }

  Future<AppPreferencesModel> getAppPreferences() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _preferencesBox.get(_appPreferencesKey) ??
        const AppPreferencesModel.defaults();
  }

  Future<AppPreferencesModel> saveAppPreferences(
    AppPreferencesModel preferences,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await _preferencesBox.put(_appPreferencesKey, preferences);
    return preferences;
  }
}
