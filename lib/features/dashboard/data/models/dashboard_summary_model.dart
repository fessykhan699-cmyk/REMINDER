import '../../domain/entities/dashboard_summary.dart';

class DashboardSummaryModel extends DashboardSummary {
  const DashboardSummaryModel({
    required super.totalUnpaid,
    required super.pendingCount,
    required super.overdueCount,
    required super.paidCount,
    required super.smartReminderInvoiceId,
    required super.smartReminderText,
  });
}
