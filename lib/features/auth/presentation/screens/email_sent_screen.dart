import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../widgets/auth_card.dart';
import '../widgets/auth_route_transition.dart';
import '../widgets/auth_shell.dart';
import '../widgets/glass_button.dart';
import '../widgets/staggered_reveal.dart';
import 'reset_password_screen.dart';

class EmailSentScreen extends StatefulWidget {
  const EmailSentScreen({super.key, required this.email});

  final String email;

  @override
  State<EmailSentScreen> createState() => _EmailSentScreenState();
}

class _EmailSentScreenState extends State<EmailSentScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  )..forward();

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  void _openReset() {
    Navigator.of(
      context,
    ).push(buildAuthRoute(ResetPasswordScreen(email: widget.email)));
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      child: AuthCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            StaggeredReveal(
              controller: _entryController,
              begin: 0,
              end: 0.55,
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentPrimary.withValues(alpha: 0.22),
                  border: Border.all(
                    color: AppColors.accentPrimary.withValues(alpha: 0.34),
                  ),
                ),
                child: const Icon(
                  Icons.mark_email_read_rounded,
                  color: AppColors.textPrimary,
                  size: 42,
                ),
              ),
            ),
            const SizedBox(height: 20),
            StaggeredReveal(
              controller: _entryController,
              begin: 0.1,
              end: 0.74,
              child: Text(
                'Check Your Email',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 36,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                ),
              ),
            ),
            const SizedBox(height: 10),
            StaggeredReveal(
              controller: _entryController,
              begin: 0.2,
              end: 0.84,
              child: Text(
                'We have sent password reset instructions to ${widget.email}.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 24),
            StaggeredReveal(
              controller: _entryController,
              begin: 0.32,
              end: 1,
              child: GlassButton(
                label: 'Back to Login',
                onPressed: () async {
                  Navigator.of(context).pop();
                },
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _openReset,
              child: const Text('I already opened the link'),
            ),
          ],
        ),
      ),
    );
  }
}
