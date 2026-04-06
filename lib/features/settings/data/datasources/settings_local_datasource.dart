import 'package:hive/hive.dart';

import '../../../../core/storage/hive_storage.dart';
import '../models/app_preferences_model.dart';
import '../models/profile_model.dart';

class SettingsLocalDatasource {
  static const String _userProfileKey = 'currentUserProfile';
  static const String _appPreferencesKey = 'appPreferences';

  final Box<dynamic> _settingsBox = Hive.box<dynamic>(
    HiveStorage.settingsBoxName,
  );
  final Box<ProfileModel> _legacyProfileBox = Hive.box<ProfileModel>(
    HiveStorage.userProfileBoxName,
  );
  final Box<AppPreferencesModel> _legacyPreferencesBox =
      Hive.box<AppPreferencesModel>(HiveStorage.appPreferencesBoxName);

  Future<ProfileModel> getProfile() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final stored = _settingsBox.get(_userProfileKey);
    if (stored is ProfileModel) {
      return stored;
    }

    final legacy = _legacyProfileBox.get(_userProfileKey);
    if (legacy != null) {
      await _settingsBox.put(_userProfileKey, legacy);
      return legacy;
    }

    return const ProfileModel(
      name: '',
      email: '',
      businessName: '',
      phone: '',
      address: '',
    );
  }

  Future<ProfileModel> saveProfile(ProfileModel profile) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await _settingsBox.put(_userProfileKey, profile);
    await _legacyProfileBox.put(_userProfileKey, profile);
    return profile;
  }

  Future<AppPreferencesModel> getAppPreferences() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final stored = _settingsBox.get(_appPreferencesKey);
    if (stored is AppPreferencesModel) {
      return stored;
    }

    final legacy = _legacyPreferencesBox.get(_appPreferencesKey);
    if (legacy != null) {
      await _settingsBox.put(_appPreferencesKey, legacy);
      return legacy;
    }

    return const AppPreferencesModel.defaults();
  }

  Future<AppPreferencesModel> saveAppPreferences(
    AppPreferencesModel preferences,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await _settingsBox.put(_appPreferencesKey, preferences);
    await _legacyPreferencesBox.put(_appPreferencesKey, preferences);
    return preferences;
  }
}
