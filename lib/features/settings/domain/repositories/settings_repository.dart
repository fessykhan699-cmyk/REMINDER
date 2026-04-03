import '../entities/profile.dart';

abstract interface class SettingsRepository {
  Future<Profile> getProfile();
}
