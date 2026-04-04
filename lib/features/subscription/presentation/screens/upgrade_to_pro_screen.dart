import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/components/glass_card.dart';
import '../../../../shared/components/premium_frosted_card.dart';
import '../../../../shared/components/premium_primary_button.dart';
import '../../domain/entities/subscription_state.dart';
import '../controllers/subscription_controller.dart';

class UpgradeToProScreen extends ConsumerStatefulWidget {
  const UpgradeToProScreen({super.key});

  @override
  ConsumerState<UpgradeToProScreen> createState() => _UpgradeToProScreenState();
}

class _UpgradeToProScreenState extends ConsumerState<UpgradeToProScreen> {
  static const String _monthlyPriceLabel = r'$12 / month';

  bool _isSubmitting = false;

  Future<void> _upgrade() async {
    if (_isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);
    await ref.read(subscriptionControllerProvider.notifier).upgradeToPro();
    ref.invalidate(subscriptionUsageProvider);

    if (!mounted) {
      return;
    }

    setState(() => _isSubmitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invoice Flow Pro is now active.')),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subscription =
        ref.watch(subscriptionControllerProvider).valueOrNull ??
        const SubscriptionState.free();
    final usage = ref.watch(subscriptionUsageProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Invoice Flow Pro')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PremiumFrostedCard(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upgrade to Invoice Flow Pro',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Unlock unlimited growth, premium reminder tools, and watermark-free PDF exports.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _PlanOptionCard(
                      title: 'Free',
                      subtitle: 'Good for getting started',
                      highlights: <String>[
                        'Up to 5 clients',
                        'Up to 5 invoices each month',
                        'PDF watermark included',
                      ],
                      isHighlighted: false,
                      trailingLabel: subscription.isPro ? null : 'Current',
                    ),
                    const SizedBox(height: 12),
                    _PlanOptionCard(
                      title: 'Pro Monthly',
                      subtitle: _monthlyPriceLabel,
                      highlights: const <String>[
                        'Unlimited clients',
                        'Unlimited invoices',
                        'No PDF watermark',
                        'Smart reminders',
                        'WhatsApp sharing',
                      ],
                      isHighlighted: true,
                      trailingLabel: subscription.isPro
                          ? 'Active'
                          : 'Best value',
                    ),
                    const SizedBox(height: 18),
                    PremiumPrimaryButton(
                      label: subscription.isPro
                          ? 'Invoice Flow Pro Active'
                          : 'Upgrade Now',
                      isLoading: _isSubmitting,
                      onPressed: subscription.isPro ? null : _upgrade,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Payments are not connected yet. This upgrade is simulated locally on this device.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your current usage',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(usage.clientUsageLabel),
                    const SizedBox(height: 6),
                    Text(usage.invoiceUsageLabel),
                    if (!subscription.isPro) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Free exports include the "Generated by Invoice Flow" watermark.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanOptionCard extends StatelessWidget {
  const _PlanOptionCard({
    required this.title,
    required this.subtitle,
    required this.highlights,
    required this.isHighlighted,
    this.trailingLabel,
  });

  final String title;
  final String subtitle;
  final List<String> highlights;
  final bool isHighlighted;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighlighted
            ? AppColors.accent.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isHighlighted
              ? AppColors.accent.withValues(alpha: 0.36)
              : AppColors.glassBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailingLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Text(
                    trailingLabel!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...highlights.map(
            (highlight) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(highlight)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
