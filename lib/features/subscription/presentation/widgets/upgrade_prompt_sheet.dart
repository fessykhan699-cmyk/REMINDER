import 'package:flutter/material.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/components/premium_frosted_card.dart';
import '../../../../shared/components/premium_primary_button.dart';
import '../../domain/entities/subscription_state.dart';

Future<bool> promptUpgradeForDecision(
  BuildContext context,
  SubscriptionGateDecision decision,
) async {
  final wantsUpgrade = await showUpgradePromptSheet(
    context,
    decision: decision,
  );
  if (!wantsUpgrade || !context.mounted) {
    return false;
  }

  final upgraded = await const UpgradeToProRoute().push<bool>(context);
  return upgraded == true;
}

Future<bool> showUpgradePromptSheet(
  BuildContext context, {
  required SubscriptionGateDecision decision,
}) async {
  final shouldUpgrade = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _UpgradePromptSheet(decision: decision),
  );

  return shouldUpgrade ?? false;
}

class _UpgradePromptSheet extends StatelessWidget {
  const _UpgradePromptSheet({required this.decision});

  final SubscriptionGateDecision decision;

  static const List<String> _benefits = <String>[
    'Unlimited invoices',
    'Remove watermark',
    'Add your logo',
    'Professional branding',
  ];

  static const List<String> _trustSignals = <String>[
    'Secure payment via Google Play',
    'Cancel anytime',
    'Used by professionals',
  ];

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + viewInsets.bottom),
        child: PremiumFrostedCard(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent.withValues(alpha: 0.14),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.28),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.workspace_premium_outlined,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          decision.promptTitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Upgrade to Pro',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Unlock unlimited invoices and remove branding',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                decision.promptMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.24),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _PricingPill(
                        title: 'Monthly',
                        price: r'$4.99',
                        subtitle: 'Simple and flexible',
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: _PricingPill(
                        title: 'Yearly',
                        price: r'$39.99',
                        subtitle: 'BEST VALUE',
                        highlighted: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ..._benefits.map(
                (benefit) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          benefit,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Unlock full access instantly',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _trustSignals
                    .map(
                      (signal) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: Text(
                          signal,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 20),
              PremiumPrimaryButton(
                label: 'Upgrade Now',
                onPressed: () async {
                  Navigator.of(context).pop(true);
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Continue with Free'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PricingPill extends StatelessWidget {
  const _PricingPill({
    required this.title,
    required this.price,
    required this.subtitle,
    this.highlighted = false,
  });

  final String title;
  final String price;
  final String subtitle;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlighted
            ? AppColors.accent.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlighted
              ? AppColors.accent.withValues(alpha: 0.30)
              : AppColors.glassBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            price,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: highlighted ? AppColors.accent : AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
