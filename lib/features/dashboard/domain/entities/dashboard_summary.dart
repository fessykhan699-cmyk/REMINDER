class DashboardSummary {
  const DashboardSummary({
    required this.totalUnpaid,
    required this.pendingCount,
    required this.overdueCount,
    required this.paidCount,
    required this.smartReminderInvoiceId,
    required this.smartReminderText,
  });

  final double totalUnpaid;
  final int pendingCount;
  final int overdueCount;
  final int paidCount;
  final String? smartReminderInvoiceId;
  final String smartReminderText;
}
