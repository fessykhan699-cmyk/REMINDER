import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/settings_local_datasource.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/usecases/get_profile_usecase.dart';
import '../../domain/usecases/save_profile_usecase.dart';

final settingsLocalDatasourceProvider = Provider<SettingsLocalDatasource>(
  (ref) => SettingsLocalDatasource(),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepositoryImpl(ref.watch(settingsLocalDatasourceProvider)),
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
    Future<void>(load);
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
      return saved;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }
}
