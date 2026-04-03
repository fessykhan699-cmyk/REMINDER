import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/components/glass_card.dart';

class DashboardSummaryCard extends StatelessWidget {
  const DashboardSummaryCard({
    super.key,
    required this.totalUnpaid,
    required this.pendingCount,
    required this.overdueCount,
    required this.paidCount,
  });

  final double totalUnpaid;
  final int pendingCount;
  final int overdueCount;
  final int paidCount;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total Unpaid', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            AppFormatters.currency(totalUnpaid),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricPill(label: 'Pending', value: pendingCount.toString()),
              _MetricPill(label: 'Overdue', value: overdueCount.toString()),
              _MetricPill(label: 'Paid', value: paidCount.toString()),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.accentPrimary.withValues(alpha: 0.16),
        border: Border.all(
          color: AppColors.accentPrimary.withValues(alpha: 0.24),
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
