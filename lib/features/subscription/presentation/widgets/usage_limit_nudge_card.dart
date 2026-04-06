import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/subscription_state.dart';

enum UsageLimitFocus { invoices, clients }

class UsageLimitNudgeCard extends StatelessWidget {
  const UsageLimitNudgeCard({
    super.key,
    required this.usage,
    required this.focus,
    required this.onUpgrade,
  });

  final SubscriptionUsage usage;
  final UsageLimitFocus focus;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final limit = focus == UsageLimitFocus.invoices
        ? SubscriptionState.freeMonthlyInvoiceLimit
        : SubscriptionState.freeClientLimit;
    final used = focus == UsageLimitFocus.invoices
        ? usage.monthlyInvoiceCount
        : usage.clientCount;
    final remaining = focus == UsageLimitFocus.invoices
        ? usage.remainingMonthlyInvoiceSlots
        : usage.remainingClientSlots;
    final progress = (used / limit).clamp(0.0, 1.0);
    final unitLabel = focus == UsageLimitFocus.invoices ? 'invoice' : 'client';
    final cycleLabel = focus == UsageLimitFocus.invoices
        ? 'this month'
        : 'on Free';

    final title = switch (remaining) {
      0 => 'You\'ve reached your free limit',
      1 => '1 $unitLabel left $cycleLabel',
      _ => '$used/$limit ${unitLabel}s used',
    };

    final message = switch (remaining) {
      0 => 'Upgrade to continue without limits.',
      1 => 'Unlock full access instantly before you hit the limit.',
      _ =>
        'Upgrade early to remove branding and keep growing without friction.',
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: appCardMargin,
      padding: appCardPadding,
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.14),
                ),
                alignment: Alignment.center,
                child: Icon(
                  focus == UsageLimitFocus.invoices
                      ? Icons.description_outlined
                      : Icons.people_alt_outlined,
                  size: 18,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: spacingSM),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(onPressed: onUpgrade, child: const Text('Upgrade')),
            ],
          ),
          const SizedBox(height: spacingSM),
          Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: spacingMD),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: spacingSM - 2,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
            ),
          ),
          const SizedBox(height: spacingSM),
          Text(
            '$used of $limit ${unitLabel}s used ${focus == UsageLimitFocus.invoices ? 'this month' : 'on Free'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
