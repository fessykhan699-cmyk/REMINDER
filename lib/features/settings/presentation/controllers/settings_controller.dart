import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/settings_local_datasource.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/usecases/get_profile_usecase.dart';

final settingsLocalDatasourceProvider = Provider<SettingsLocalDatasource>(
  (ref) => SettingsLocalDatasource(),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepositoryImpl(ref.watch(settingsLocalDatasourceProvider)),
);

final getProfileUseCaseProvider = Provider<GetProfileUseCase>(
  (ref) => GetProfileUseCase(ref.watch(settingsRepositoryProvider)),
);

final settingsControllerProvider =
    AutoDisposeNotifierProvider<SettingsController, AsyncValue<Profile>>(
      SettingsController.new,
    );

class SettingsController extends AutoDisposeNotifier<AsyncValue<Profile>> {
  @override
  AsyncValue<Profile> build() {
    Future<void>(load);
    return const AsyncValue.loading();
  }

  Future<void> load() async {
    state = await AsyncValue.guard(
      () => ref.read(getProfileUseCaseProvider).call(),
    );
  }
}
