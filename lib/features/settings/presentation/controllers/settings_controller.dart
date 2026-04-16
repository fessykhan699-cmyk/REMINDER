import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../data/providers/firestore_sync_provider.dart';
import '../../../subscription/presentation/controllers/subscription_controller.dart';
import '../../data/datasources/settings_local_datasource.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/usecases/get_profile_usecase.dart';
import '../../domain/usecases/save_profile_usecase.dart';
import '../controllers/app_preferences_controller.dart';

final settingsLocalDatasourceProvider = Provider<SettingsLocalDatasource>(
  (ref) => SettingsLocalDatasource(),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) {
    final datasource = ref.watch(settingsLocalDatasourceProvider);
    return SettingsRepositoryImpl(
      datasource,
      syncService: ref.watch(firestoreSyncServiceProvider),
      userId: ref.watch(currentUserIdProvider),
      isPro:
          ref.watch(subscriptionControllerProvider).valueOrNull?.isPro ?? false,
    );
  },
);

final getProfileUseCaseProvider = Provider<GetProfileUseCase>(
  (ref) => GetProfileUseCase(ref.watch(settingsRepositoryProvider)),
);

final saveProfileUseCaseProvider = Provider<SaveProfileUseCase>(
  (ref) => SaveProfileUseCase(ref.watch(settingsRepositoryProvider)),
);

final settingsControllerProvider =
    AutoDisposeNotifierProvider<SettingsController, AsyncValue<UserProfile>>(
      SettingsController.new,
    );

class SettingsController extends AutoDisposeNotifier<AsyncValue<UserProfile>> {
  @override
  AsyncValue<UserProfile> build() {
    Future(() => load());
    return const AsyncValue.loading();
  }

  Future<void> load() async {
    state = await AsyncValue.guard(
      () => ref.read(getProfileUseCaseProvider).call(),
    );
  }

  Future<UserProfile> saveProfile(UserProfile profile) async {
    try {
      final saved = await ref.read(saveProfileUseCaseProvider).call(profile);
      state = AsyncValue.data(saved);
      _maybeSyncCurrencyFromPhone(saved.phone);
      return saved;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  /// When the user saves a phone number we detect the likely currency and
  /// apply it automatically — but only if they haven't already changed the
  /// currency from the factory default ('USD'). This avoids overwriting a
  /// deliberate currency choice.
  void _maybeSyncCurrencyFromPhone(String phone) {
    final detected = AppFormatters.currencyFromPhone(phone);
    if (detected == null) return;
    ref.read(appPreferencesControllerProvider.notifier).patch((prefs) {
      if (prefs.defaultCurrency == 'USD') {
        return prefs.copyWith(defaultCurrency: detected);
      }
      return prefs;
    });
  }
}
