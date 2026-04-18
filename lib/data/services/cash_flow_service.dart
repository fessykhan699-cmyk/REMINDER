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
          for (final payment in invoice.payments) {
            if (payment.date.year == monthDate.year &&
                payment.date.month == monthDate.month) {
              total += payment.amount;
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
