import 'dart:math' as math;
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

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSubmitting = false;

  static final RegExp _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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

  bool get _isFormValid {
    return _validateEmail(_emailController.text) == null &&
        _validatePassword(_passwordController.text) == null;
  }

  Future<void> _submitLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
    });

    await ref
        .read(authControllerProvider.notifier)
        .login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    final state = ref.read(authControllerProvider);
    if (state.status == AuthStatus.authenticated) {
      return;
    }

    if (state.errorMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
    }
  }

  Future<void> _submitGoogle() async {
    FocusScope.of(context).unfocus();
    await ref.read(authControllerProvider.notifier).loginWithGoogle();

    if (!mounted) return;

    final state = ref.read(authControllerProvider);
    if (state.status == AuthStatus.authenticated) {
      return;
    }

    if (state.errorMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
    }
  }

  void _openForgotPassword() {
    const ForgotPasswordRoute().go(context);
  }

  void _openSignUp() {
    const SignUpRoute().go(context);
  }

  @override
  Widget build(BuildContext context) {
    final errorMessage = ref.watch(
      authControllerProvider.select((state) => state.errorMessage),
    );
    final isAuthSubmitting = ref.watch(
      authControllerProvider.select((state) => state.isSubmitting),
    );
    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            const Positioned.fill(child: PremiumGalaxyBackground()),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final formMinHeight = math.max(
                    420.0,
                    constraints.maxHeight - 330,
                  );

                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 12),
                              Text(
                                'Welcome Back',
                                maxLines: 3,
                                softWrap: true,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      fontSize: 48,
                                      height: 1.04,
                                      letterSpacing: -0.8,
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Login to manage invoices, reminders, and cashflow with confidence.',
                                maxLines: 3,
                                softWrap: true,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                      height: 1.35,
                                    ),
                              ),
                              const SizedBox(height: 24),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: formMinHeight,
                                ),
                                child: PremiumFrostedCard(
                                  borderRadius: BorderRadius.circular(20),
                                  blurSigma: 4,
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    16,
                                    16,
                                    16,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      PremiumInputField(
                                        controller: _emailController,
                                        label: 'Email',
                                        hintText: 'you@business.com',
                                        validator: _validateEmail,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        textInputAction: TextInputAction.next,
                                        autofillHints: const [
                                          AutofillHints.email,
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      _PasswordInputField(
                                        controller: _passwordController,
                                        validator: _validatePassword,
                                      ),
                                      const SizedBox(height: 8),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: _openForgotPassword,
                                          child: const Text('Forgot password?'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (errorMessage != null) ...[
                                const SizedBox(height: 16),
                                Text(
                                  errorMessage,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: AppColors.danger,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                              const SizedBox(height: 24),
                              PremiumPrimaryButton(
                                label: 'Login',
                                isLoading: _isSubmitting,
                                onPressed: _isFormValid && !_isSubmitting
                                    ? _submitLogin
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              PremiumPrimaryButton(
                                label: 'Continue with Google',
                                variant: PremiumButtonVariant.secondary,
                                isLoading: isAuthSubmitting,
                                onPressed: isAuthSubmitting
                                    ? null
                                    : _submitGoogle,
                                leading: Container(
                                  width: 22,
                                  height: 22,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.accent.withValues(
                                      alpha: 0.18,
                                    ),
                                    border: Border.all(
                                      color: AppColors.accent.withValues(
                                        alpha: 0.32,
                                      ),
                                    ),
                                  ),
                                  child: const Text(
                                    'G',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Center(
                                child: TextButton(
                                  onPressed: _openSignUp,
                                  child: const Text(
                                    'No account yet? Create one',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordInputField extends StatefulWidget {
  const _PasswordInputField({
    required this.controller,
    required this.validator,
  });

  final TextEditingController controller;
  final String? Function(String?) validator;

  @override
  State<_PasswordInputField> createState() => _PasswordInputFieldState();
}

class _PasswordInputFieldState extends State<_PasswordInputField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return PremiumInputField(
      controller: widget.controller,
      label: 'Password',
      hintText: 'Enter your password',
      validator: widget.validator,
      obscureText: _obscureText,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.password],
      suffix: IconButton(
        onPressed: () => setState(() => _obscureText = !_obscureText),
        icon: Icon(
          _obscureText
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
