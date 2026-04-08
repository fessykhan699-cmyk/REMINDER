import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../widgets/auth_card.dart';
import '../widgets/auth_route_transition.dart';
import '../widgets/auth_shell.dart';
import '../widgets/glass_button.dart';
import '../widgets/glass_input_field.dart';
import '../widgets/staggered_reveal.dart';
import 'email_sent_screen.dart';
import 'reset_password_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  late final AnimationController _entryController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  )..forward();

  bool _isSubmitting = false;

  static final RegExp _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  @override
  void dispose() {
    _entryController.dispose();
    _emailController.dispose();
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

  bool get _isFormValid => _validateEmail(_emailController.text) == null;

  Future<void> _sendResetLink() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    final email = _emailController.text.trim();
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      debugPrint('sendPasswordResetEmail sent to: $email');
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        buildAuthRoute(EmailSentScreen(email: email)),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      debugPrint('sendPasswordResetEmail failed [${e.code}]: ${e.message}');
      final message = switch (e.code) {
        'user-not-found' =>
          'No password account found. If you signed up with Google, use Google Sign-In.',
        'invalid-email' => 'Invalid email address.',
        'network-request-failed' => 'Network error. Check your connection.',
        _ => 'Something went wrong. Please try again.',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _openReset() {
    final email = _emailController.text.trim();
    Navigator.of(
      context,
    ).push(buildAuthRoute(ResetPasswordScreen(email: email)));
  }

  @override
  Widget build(BuildContext context) {
    final formListenable = Listenable.merge([_emailController]);

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
                end: 0.6,
                child: Text(
                  'Forgot Password?',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 38,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              StaggeredReveal(
                controller: _entryController,
                begin: 0.10,
                end: 0.7,
                child: Text(
                  'Enter your email to receive reset instructions',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              StaggeredReveal(
                controller: _entryController,
                begin: 0.22,
                end: 0.86,
                child: GlassInputField(
                  controller: _emailController,
                  label: 'Email',
                  hintText: 'you@business.com',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  validator: _validateEmail,
                ),
              ),
              const SizedBox(height: 20),
              StaggeredReveal(
                controller: _entryController,
                begin: 0.32,
                end: 1,
                child: AnimatedBuilder(
                  animation: formListenable,
                  builder: (context, _) {
                    return GlassButton(
                      label: 'Send Reset Link',
                      isLoading: _isSubmitting,
                      onPressed: _isFormValid && !_isSubmitting
                          ? _sendResetLink
                          : null,
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: _openReset,
                  child: const Text(
                    'Already have a reset link? Set new password',
                  ),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back to Login'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
