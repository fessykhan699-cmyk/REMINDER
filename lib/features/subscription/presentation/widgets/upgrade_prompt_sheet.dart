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
    'Unlimited clients',
    'Unlimited invoices',
    'No PDF watermark',
    'Smart reminders',
    'WhatsApp sharing',
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
                    child: Text(
                      decision.promptTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                decision.promptMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _benefits
                    .map(
                      (benefit) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: Text(
                          benefit,
                          style: theme.textTheme.bodySmall?.copyWith(
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
                  child: const Text('Maybe later'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
