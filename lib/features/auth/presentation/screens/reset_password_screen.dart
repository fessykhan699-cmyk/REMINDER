import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_card.dart';
import '../widgets/auth_route_transition.dart';
import '../widgets/auth_shell.dart';
import '../widgets/glass_button.dart';
import '../widgets/glass_input_field.dart';
import '../widgets/staggered_reveal.dart';
import 'auth_success_screen.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late final AnimationController _entryController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  )..forward();

  bool _isSubmitting = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _entryController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').length < 6) {
      return 'Minimum 6 characters';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value != _newPasswordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  bool get _isFormValid {
    return _validatePassword(_newPasswordController.text) == null &&
        _validateConfirmPassword(_confirmPasswordController.text) == null;
  }

  Future<void> _updatePassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!mounted) {
      return;
    }
    setState(() {
      _isSubmitting = false;
    });

    final email = widget.email.trim().isEmpty
        ? 'owner@studio.com'
        : widget.email.trim();

    await Navigator.of(context).push(
      buildAuthRoute(
        AuthSuccessScreen(
          title: "You're all set",
          subtitle: 'Welcome back',
          onComplete: () async {
            await ref
                .read(authControllerProvider.notifier)
                .login(email: email, password: _newPasswordController.text);
            if (!mounted) {
              return;
            }
            const DashboardTabRoute().go(context);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formListenable = Listenable.merge([
      _newPasswordController,
      _confirmPasswordController,
    ]);

    return AuthShell(
      child: Form(
        key: _formKey,
        child: AuthCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StaggeredReveal(
                controller: _entryController,
                begin: 0,
                end: 0.55,
                child: Text(
                  'Set New Password',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 38,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              StaggeredReveal(
                controller: _entryController,
                begin: 0.10,
                end: 0.68,
                child: Text(
                  'Create a strong password for secure access.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              StaggeredReveal(
                controller: _entryController,
                begin: 0.2,
                end: 0.84,
                child: GlassInputField(
                  controller: _newPasswordController,
                  label: 'New Password',
                  hintText: 'At least 6 characters',
                  obscureText: _obscureNewPassword,
                  textInputAction: TextInputAction.next,
                  validator: _validatePassword,
                  suffix: IconButton(
                    onPressed: () {
                      setState(() {
                        _obscureNewPassword = !_obscureNewPassword;
                      });
                    },
                    icon: Icon(
                      _obscureNewPassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              StaggeredReveal(
                controller: _entryController,
                begin: 0.28,
                end: 0.9,
                child: GlassInputField(
                  controller: _confirmPasswordController,
                  label: 'Confirm Password',
                  hintText: 'Re-enter password',
                  obscureText: _obscureConfirmPassword,
                  textInputAction: TextInputAction.done,
                  validator: _validateConfirmPassword,
                  suffix: IconButton(
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              StaggeredReveal(
                controller: _entryController,
                begin: 0.38,
                end: 1,
                child: AnimatedBuilder(
                  animation: formListenable,
                  builder: (context, _) {
                    return GlassButton(
                      label: 'Update Password',
                      isLoading: _isSubmitting,
                      onPressed: _isFormValid && !_isSubmitting
                          ? _updatePassword
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
