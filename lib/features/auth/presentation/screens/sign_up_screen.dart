import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/auth_session.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/components/premium_frosted_card.dart';
import '../../../../shared/components/premium_input_field.dart';
import '../../../../shared/components/premium_primary_button.dart';
import '../../../../shared/widgets/premium_galaxy_background.dart';
import '../controllers/auth_controller.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late final AnimationController _entryController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  )..forward();

  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _entryController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  static final RegExp _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  String? _validateName(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Name is required';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return 'Email is required';
    }
    if (!_emailRegex.hasMatch(text)) {
      return 'Enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').length < 6) {
      return 'Minimum 6 characters';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  bool get _isFormValid {
    return _validateName(_nameController.text) == null &&
        _validateEmail(_emailController.text) == null &&
        _validatePassword(_passwordController.text) == null &&
        _validateConfirmPassword(_confirmPasswordController.text) == null;
  }

  double get _passwordStrength {
    final value = _passwordController.text;
    if (value.isEmpty) {
      return 0;
    }

    var score = 0;
    if (value.length >= 6) {
      score++;
    }
    if (value.length >= 10) {
      score++;
    }
    if (RegExp(r'[A-Z]').hasMatch(value)) {
      score++;
    }
    if (RegExp(r'\d').hasMatch(value)) {
      score++;
    }

    return score / 4;
  }

  Color get _strengthColor {
    final strength = _passwordStrength;
    if (strength < 0.35) {
      return AppColors.danger;
    }
    if (strength < 0.7) {
      return AppColors.warning;
    }
    return AppColors.success;
  }

  String get _strengthLabel {
    final strength = _passwordStrength;
    if (strength < 0.35) {
      return 'Weak';
    }
    if (strength < 0.7) {
      return 'Good';
    }
    return 'Strong';
  }

  Future<void> _onCreateAccount() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
    });

    try {
      await ref.read(authControllerProvider.notifier).signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      if (!mounted) return;

      final state = ref.read(authControllerProvider);
      if (state.status == AuthStatus.authenticated) {
        // Redirection is handled by the router (to EmailVerificationScreen if unverified)
        return;
      }

      if (state.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.errorMessage!)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final errorMessage = ref.watch(
      authControllerProvider.select((state) => state.errorMessage),
    );
    final formListenable = Listenable.merge([
      _nameController,
      _emailController,
      _passwordController,
      _confirmPasswordController,
    ]);

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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Text(
                        'Create Your Account',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontSize: 48,
                          height: 1.04,
                          letterSpacing: -0.8,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Set up your secure workspace to manage invoices faster.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 24),
                      PremiumFrostedCard(
                        borderRadius: BorderRadius.circular(20),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PremiumInputField(
                              controller: _nameController,
                              label: 'Name',
                              hintText: 'Full name',
                              textInputAction: TextInputAction.next,
                              validator: _validateName,
                              autofillHints: const [AutofillHints.name],
                            ),
                            const SizedBox(height: 16),
                            PremiumInputField(
                              controller: _emailController,
                              label: 'Email',
                              hintText: 'you@business.com',
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              validator: _validateEmail,
                              autofillHints: const [AutofillHints.email],
                            ),
                            const SizedBox(height: 16),
                            PremiumInputField(
                              controller: _passwordController,
                              label: 'Password',
                              hintText: 'At least 6 characters',
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.next,
                              validator: _validatePassword,
                              autofillHints: const [AutofillHints.newPassword],
                              suffix: IconButton(
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _passwordController,
                              builder: (context, _, child) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    LinearProgressIndicator(
                                      minHeight: 4,
                                      value: _passwordStrength,
                                      borderRadius: BorderRadius.circular(10),
                                      valueColor: AlwaysStoppedAnimation<Color>(_strengthColor),
                                      backgroundColor: AppColors.backgroundSecondary,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Password strength: $_strengthLabel',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: _strengthColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            PremiumInputField(
                              controller: _confirmPasswordController,
                              label: 'Confirm Password',
                              hintText: 'Re-enter password',
                              obscureText: _obscureConfirm,
                              textInputAction: TextInputAction.done,
                              validator: _validateConfirmPassword,
                              suffix: IconButton(
                                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                icon: Icon(
                                  _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          errorMessage,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      AnimatedBuilder(
                        animation: formListenable,
                        builder: (context, _) {
                          return PremiumPrimaryButton(
                            label: 'Create Account',
                            isLoading: _isSubmitting,
                            onPressed: _isFormValid && !_isSubmitting ? _onCreateAccount : null,
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton(
                          onPressed: () => const LoginRoute().go(context),
                          child: const Text('Already have an account? Login'),
                        ),
                      ),
                      const SizedBox(height: 20),
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
