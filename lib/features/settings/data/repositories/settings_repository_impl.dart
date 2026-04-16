import '../../domain/entities/app_preferences.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/settings_local_datasource.dart';
import '../models/app_preferences_model.dart';
import '../models/profile_model.dart';
import '../../../../data/services/firestore_sync_service.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  const SettingsRepositoryImpl(
    this._datasource, {
    this.syncService,
    this.userId,
    this.isPro = false,
  });

  final SettingsLocalDatasource _datasource;
  final FirestoreSyncService? syncService;
  final String? userId;
  final bool isPro;

  @override
  Future<UserProfile> getProfile() => _datasource.getProfile();

  @override
  Future<UserProfile> saveProfile(UserProfile profile) async {
    final model = ProfileModel.fromEntity(profile);
    final saved = await _datasource.saveProfile(model);
    _syncProfile(model);
    return saved;
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

  // ── Private sync helper ────────────────────────────────────────────────

  void _syncProfile(ProfileModel model) {
    final svc = syncService;
    final uid = userId;
    if (svc == null || uid == null) return;
    svc.syncProfileToCloud(userId: uid, isPro: isPro, profile: model);
  }
}
