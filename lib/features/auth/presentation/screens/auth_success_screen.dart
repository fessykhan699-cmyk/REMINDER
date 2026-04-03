import 'package:flutter/material.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/auth_card.dart';
import '../widgets/auth_shell.dart';
import '../widgets/staggered_reveal.dart';

class AuthSuccessScreen extends StatefulWidget {
  const AuthSuccessScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onComplete,
  });

  final String title;
  final String subtitle;
  final Future<void> Function() onComplete;

  @override
  State<AuthSuccessScreen> createState() => _AuthSuccessScreenState();
}

class _AuthSuccessScreenState extends State<AuthSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  )..forward();

  bool _isWorking = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      await widget.onComplete();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isWorking = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  Future<void> _retry() async {
    setState(() {
      _isWorking = true;
      _error = null;
    });
    await _start();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      child: AuthCard(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
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
                  color: AppColors.success.withValues(alpha: 0.22),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.38),
                  ),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.textPrimary,
                  size: 46,
                ),
              ),
            ),
            const SizedBox(height: 20),
            StaggeredReveal(
              controller: _entryController,
              begin: 0.10,
              end: 0.72,
              child: Text(
                widget.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.7,
                ),
              ),
            ),
            const SizedBox(height: 10),
            StaggeredReveal(
              controller: _entryController,
              begin: 0.20,
              end: 0.84,
              child: Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 20),
            if (_isWorking)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.accentPrimary,
                  ),
                ),
              ),
            if (_error != null) ...[
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: _retry, child: const Text('Try again')),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => const DashboardTabRoute().go(context),
                child: const Text('Continue'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
