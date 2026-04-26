import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/premium_galaxy_background.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    String statusLabel;
    switch (authState.status) {
      case AuthStatus.initializing:
        statusLabel = 'Preparing secure workspace...';
      case AuthStatus.authenticated:
        statusLabel = 'Opening dashboard...';
      case AuthStatus.unauthenticated:
        statusLabel = 'Checking onboarding state...';
    }

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: PremiumGalaxyBackground(galaxyOpacity: 0.20),
          ),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent.withValues(alpha: 0.12),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.30),
                      ),
                    ),
                    child: const Icon(
                      Icons.payments_rounded,
                      size: 36,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Paydeck',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.accent.withValues(alpha: 0.60),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    statusLabel,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
