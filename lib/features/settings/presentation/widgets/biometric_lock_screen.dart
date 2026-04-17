import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/providers/biometric_provider.dart';

class BiometricLockScreen extends ConsumerWidget {
  const BiometricLockScreen({super.key});

  Future<void> _tryAuthenticate(WidgetRef ref) async {
    final service = ref.read(biometricServiceProvider);
    final success = await service.authenticate();
    if (success) {
      ref.read(isBiometricLockedProvider.notifier).state = false;
    }
    // if false: stay locked, do nothing
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
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
                  onPressed: () => _tryAuthenticate(ref),
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
