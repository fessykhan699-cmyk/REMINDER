import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/components/premium_frosted_card.dart';
import '../../../../shared/components/premium_primary_button.dart';
import '../../../../shared/widgets/premium_galaxy_background.dart';
import '../controllers/auth_controller.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  ConsumerState<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends ConsumerState<EmailVerificationScreen> {
  bool _isResending = false;

  Future<void> _onResendEmail() async {
    setState(() => _isResending = true);
    await ref.read(authControllerProvider.notifier).resendVerificationEmail();
    if (!mounted) return;
    setState(() => _isResending = false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Verification link resent. Please check your inbox.')),
    );
  }

  Future<void> _onCheckStatus() async {
    await ref.read(authControllerProvider.notifier).reloadUser();
    if (!mounted) return;
    
    final state = ref.read(authControllerProvider);
    if (state.session?.isEmailVerified ?? false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email verified! Redirecting...')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email not verified yet. Please check your inbox.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider.select((s) => s.session));
    final isSubmitting = ref.watch(authControllerProvider.select((s) => s.isSubmitting));

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: PremiumGalaxyBackground()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.mark_email_read_outlined,
                      size: 80,
                      color: AppColors.accent,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Verify Your Email',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'We\'ve sent a verification link to:',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      session?.email ?? 'your email',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 32),
                    PremiumFrostedCard(
                      borderRadius: BorderRadius.circular(20),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Text(
                            'Please click the link in the email to verify your account and get started.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.5,
                                ),
                          ),
                          const SizedBox(height: 24),
                          PremiumPrimaryButton(
                            label: 'I\'ve Verified My Email',
                            isLoading: isSubmitting,
                            onPressed: isSubmitting ? null : _onCheckStatus,
                          ),
                          const SizedBox(height: 12),
                          PremiumPrimaryButton(
                            label: 'Resend Verification Link',
                            variant: PremiumButtonVariant.secondary,
                            isLoading: _isResending,
                            onPressed: _isResending ? null : _onResendEmail,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextButton(
                      onPressed: () => ref.read(authControllerProvider.notifier).logout(),
                      child: Text(
                        'Use a different account? Logout',
                        style: TextStyle(
                          color: AppColors.textSecondary.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
