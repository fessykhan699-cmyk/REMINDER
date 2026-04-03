import '../../../invoices/domain/entities/invoice.dart';

class DashboardLocalDatasource {
  String buildSmartReminderText(Invoice invoice) {
    if (invoice.status == InvoiceStatus.overdue) {
      return 'Overdue alert: ${invoice.clientName} (${invoice.id}) needs a firm reminder now.';
    }

    return 'Upcoming due date: ${invoice.clientName} (${invoice.id}) is the best next reminder.';
  }
}
