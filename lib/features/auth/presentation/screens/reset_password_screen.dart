import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/components/premium_frosted_card.dart';
import '../../../../shared/components/premium_input_field.dart';
import '../../../../shared/components/premium_primary_button.dart';
import '../../../../shared/widgets/premium_galaxy_background.dart';
import '../../domain/entities/auth_session.dart';
import '../controllers/auth_controller.dart';
import 'auth_success_screen.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String? oobCode;
  const ResetPasswordScreen({super.key, this.oobCode});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _email;
  bool _isVerifying = true;

  @override
  void initState() {
    super.initState();
    _verifyCode();
  }

  Future<void> _verifyCode() async {
    if (widget.oobCode == null) {
      setState(() {
        _isVerifying = false;
      });
      return;
    }

    final email = await ref.read(authControllerProvider.notifier).verifyPasswordResetCode(widget.oobCode!);
    if (mounted) {
      setState(() {
        _email = email;
        _isVerifying = false;
      });
    }
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value != _newPasswordController.text) return 'Passwords do not match';
    return null;
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.oobCode == null) return;

    FocusScope.of(context).unfocus();
    
    await ref.read(authControllerProvider.notifier).confirmPasswordReset(
      code: widget.oobCode!,
      newPassword: _newPasswordController.text,
    );
    
    if (!mounted) return;
    
    final authState = ref.read(authControllerProvider);
    if (authState.errorMessage == null) {
       if (!mounted) return;
       
       Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => AuthSuccessScreen(
            title: 'Password Reset!',
            subtitle: 'Your password has been successfully updated.',
            onComplete: () async {
              final email = _email;
              final password = _newPasswordController.text;
              if (email != null && password.isNotEmpty) {
                await ref.read(authControllerProvider.notifier).login(
                      email: email,
                      password: password,
                    );
                if (!context.mounted) return;
                final state = ref.read(authControllerProvider);
                if (state.status == AuthStatus.authenticated) {
                  const DashboardTabRoute().go(context);
                  return;
                }
              }
              if (!context.mounted) return;
              const LoginRoute().go(context);
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final formListenable = Listenable.merge([_newPasswordController, _confirmPasswordController]);

    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            const Positioned.fill(child: PremiumGalaxyBackground()),
            SafeArea(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 60),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          onPressed: () async => const LoginRoute().go(context),
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: AppColors.textPrimary,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _isVerifying
                            ? 'Verifying reset link...'
                            : (_email != null ? 'Hi $_email, reset your password.' : 'Reset Password'),
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _isVerifying
                            ? 'Please wait while we check your request.'
                            : (_email != null
                                ? 'Create a new password to secure your account.'
                                : 'The reset link is invalid or has expired.'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 48),
                      if (_isVerifying)
                        const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.accent,
                          ),
                        )
                       else if (_email == null)
                        PremiumFrostedCard(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
                              const SizedBox(height: 16),
                              Text(
                                authState.errorMessage ?? 'Please request a new reset link to proceed.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.danger),
                              ),
                              const SizedBox(height: 24),
                              PremiumPrimaryButton(
                                label: 'Back to Login',
                                onPressed: () async => const LoginRoute().go(context),
                              ),
                            ],
                          ),
                        )
                      else if (_email != null)
                        PremiumFrostedCard(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              PremiumInputField(
                                controller: _newPasswordController,
                                label: 'New Password',
                                hintText: 'Minimum 8 characters',
                                obscureText: true,
                                textInputAction: TextInputAction.next,
                                validator: _validatePassword,
                              ),
                              const SizedBox(height: 20),
                              PremiumInputField(
                                controller: _confirmPasswordController,
                                label: 'Confirm New Password',
                                hintText: 'Repeat your new password',
                                obscureText: true,
                                textInputAction: TextInputAction.done,
                                validator: _validateConfirmPassword,
                              ),
                              const SizedBox(height: 32),
                              ListenableBuilder(
                                listenable: formListenable,
                                builder: (context, _) {
                                  final isFormValid = _newPasswordController.text.length >= 8 &&
                                      _newPasswordController.text == _confirmPasswordController.text;
                                  return Column(
                                    children: [
                                      PremiumPrimaryButton(
                                        label: 'Update Password',
                                        isLoading: authState.isSubmitting,
                                        onPressed: isFormValid && !authState.isSubmitting ? _updatePassword : null,
                                      ),
                                      if (authState.errorMessage != null) ...[
                                        const SizedBox(height: 16),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: AppColors.danger.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  authState.errorMessage!,
                                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.danger),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
