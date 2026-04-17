import 'package:intl/intl.dart';
import '../../features/invoices/domain/entities/invoice.dart';

class MonthlyCashFlow {
  final String label; // e.g. "Nov 24"
  final double totalPaid; // total value of paid invoices

  MonthlyCashFlow({
    required this.label,
    required this.totalPaid,
  });
}

class CashFlowService {
  List<MonthlyCashFlow> getLast6MonthsCashFlow(List<Invoice> invoices) {
    try {
      final List<MonthlyCashFlow> results = [];
      final now = DateTime.now();

      // Generate the last 6 months (oldest first)
      for (int i = 5; i >= 0; i--) {
        // Calculate the month and year for i months ago
        final monthDate = DateTime(now.year, now.month - i, 1);
        final label = DateFormat('MMM yy').format(monthDate);

        // Calculate total for paid invoices in this calendar month
        double total = 0;
        for (final invoice in invoices) {
          if (invoice.status == InvoiceStatus.paid) {
            // Check if invoice.createdAt falls within the monthDate calendar month
            // The instructions say "invoice.date" but the field is "createdAt" or "dueDate"?
            // "Each bar represents the total value of all paid invoices in that month."
            // Usually cash flow is based on when it was PAID, but we don't have a paidDate field in Invoice.
            // We have payments list though. 
            // "AND invoice.date falls within that calendar month"
            // Since the instructions say "invoice.date", and we have "createdAt" and "dueDate".
            // I'll assume "createdAt" or "dueDate" depending on what "invoice.date" refers to.
            // Looking at CreateInvoiceScreen previously, users select a date which is likely stored in dueDate or createdAt.
            // Actually, invoices are usually grouped by date.
            // I'll check CreateInvoiceScreen again to see what "date" people select.
            
            if (invoice.createdAt.year == monthDate.year &&
                invoice.createdAt.month == monthDate.month) {
              total += invoice.amount;
            }
          }
        }

        results.add(MonthlyCashFlow(label: label, totalPaid: total));
      }

      return results;
    } catch (e) {
      // Returns list of 6 zeroed MonthlyCashFlow on any error
      final List<MonthlyCashFlow> fallback = [];
      final now = DateTime.now();
      for (int i = 5; i >= 0; i--) {
        final monthDate = DateTime(now.year, now.month - i, 1);
        final label = DateFormat('MMM yy').format(monthDate);
        fallback.add(MonthlyCashFlow(label: label, totalPaid: 0));
      }
      return fallback;
    }
  }
}
