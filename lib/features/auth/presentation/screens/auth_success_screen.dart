import 'package:flutter/material.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/components/premium_frosted_card.dart';
import '../../../../shared/widgets/premium_galaxy_background.dart';

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

class _AuthSuccessScreenState extends State<AuthSuccessScreen> {
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: PremiumGalaxyBackground()),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: PremiumFrostedCard(
                  borderRadius: BorderRadius.circular(24),
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
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
                      const SizedBox(height: 32),
                      Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.7,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.subtitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 40),
                      if (_isWorking)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.accentPrimary,
                            ),
                          ),
                        ),
                      if (_error != null) ...[
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextButton(
                          onPressed: _retry,
                          child: const Text('Try again'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => const DashboardTabRoute().go(context),
                          child: const Text('Continue to Dashboard'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
