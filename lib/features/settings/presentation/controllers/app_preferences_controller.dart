import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_preferences.dart';
import '../../domain/usecases/get_app_preferences_usecase.dart';
import '../../domain/usecases/save_app_preferences_usecase.dart';
import 'settings_controller.dart';

final getAppPreferencesUseCaseProvider = Provider<GetAppPreferencesUseCase>(
  (ref) => GetAppPreferencesUseCase(ref.watch(settingsRepositoryProvider)),
);

final saveAppPreferencesUseCaseProvider = Provider<SaveAppPreferencesUseCase>(
  (ref) => SaveAppPreferencesUseCase(ref.watch(settingsRepositoryProvider)),
);

final appPreferencesControllerProvider =
    NotifierProvider<AppPreferencesController, AsyncValue<AppPreferences>>(
      AppPreferencesController.new,
    );

class AppPreferencesController
    extends Notifier<AsyncValue<AppPreferences>> {
  @override
  AsyncValue<AppPreferences> build() {
    Future(() => load());
    return const AsyncValue.loading();
  }

  Future<void> load() async {
    state = await AsyncValue.guard(
      () => ref.read(getAppPreferencesUseCaseProvider).call(),
    );
  }

  Future<AppPreferences> save(AppPreferences preferences) async {
    final saved = await ref.read(saveAppPreferencesUseCaseProvider).call(
      preferences,
    );
    state = AsyncValue.data(saved);
    return saved;
  }

  Future<AppPreferences> patch(AppPreferences Function(AppPreferences current) update) async {
    final current = state.valueOrNull ??
        await ref.read(getAppPreferencesUseCaseProvider).call();
    final next = update(current);
    return save(next);
  }

  Future<void> setBiometricLock(bool value) async {
    await patch((current) => current.copyWith(biometricLockEnabled: value));
  }

  Future<void> setFaceUnlock(bool value) async {
    await patch((current) => current.copyWith(faceUnlockEnabled: value));
  }

  Future<void> setFingerprintLock(bool value) async {
    await patch((current) => current.copyWith(fingerprintLockEnabled: value));
  }
}
