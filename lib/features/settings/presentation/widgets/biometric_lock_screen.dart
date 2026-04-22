import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/providers/biometric_provider.dart';
import '../../presentation/controllers/app_preferences_controller.dart';

class BiometricLockScreen extends ConsumerStatefulWidget {
  const BiometricLockScreen({super.key});

  @override
  ConsumerState<BiometricLockScreen> createState() =>
      _BiometricLockScreenState();
}

class _BiometricLockScreenState extends ConsumerState<BiometricLockScreen> {
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;
    _isAuthenticating = true;
    try {
      final service = ref.read(biometricServiceProvider);
      final prefs = ref.read(appPreferencesControllerProvider).valueOrNull;
      final success = await service.authenticate(
        facePreferred: prefs?.faceUnlockEnabled ?? false,
      );
      if (success && mounted) {
        ref.read(isBiometricLockedProvider.notifier).state = false;
      }
    } catch (_) {
      // stay locked on any error
    } finally {
      if (mounted) {
        _isAuthenticating = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: AppColors.backgroundPrimary,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  width: 80,
                  height: 80,
                ),
                const SizedBox(height: 24),
                Text(
                  AppConstants.aboutAppName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                const Icon(
                  Icons.fingerprint,
                  size: 48,
                  color: AppColors.accent,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _authenticate,
                  icon: const Icon(Icons.lock_open_outlined),
                  label: const Text('Unlock'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
