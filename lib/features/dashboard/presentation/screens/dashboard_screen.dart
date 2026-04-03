import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../shared/widgets/app_async_state_view.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../controllers/dashboard_controller.dart';
import '../widgets/dashboard_summary_card.dart';
import '../widgets/smart_reminder_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardControllerProvider);
    final controller = ref.read(dashboardControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: RefreshIndicator(
        onRefresh: controller.load,
        child: AppAsyncStateView<DashboardSummary>(
          state: state,
          onRetry: controller.load,
          builder: (summary) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
              children: [
                DashboardSummaryCard(
                  totalUnpaid: summary.totalUnpaid,
                  pendingCount: summary.pendingCount,
                  overdueCount: summary.overdueCount,
                  paidCount: summary.paidCount,
                ),
                const SizedBox(height: 12),
                SmartReminderCard(
                  message: summary.smartReminderText,
                  enabled: summary.smartReminderInvoiceId != null,
                  onAction: () {
                    final invoiceId = summary.smartReminderInvoiceId;
                    if (invoiceId == null) {
                      return;
                    }
                    ReminderFlowRoute(invoiceId).push(context);
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
