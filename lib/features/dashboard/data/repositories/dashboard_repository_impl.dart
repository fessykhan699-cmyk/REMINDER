import '../../../invoices/domain/entities/invoice.dart';
import '../../../invoices/domain/repositories/invoice_repository.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasources/dashboard_local_datasource.dart';
import '../models/dashboard_summary_model.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  const DashboardRepositoryImpl({
    required InvoiceRepository invoiceRepository,
    required DashboardLocalDatasource localDatasource,
  }) : _invoiceRepository = invoiceRepository,
       _localDatasource = localDatasource;

  final InvoiceRepository _invoiceRepository;
  final DashboardLocalDatasource _localDatasource;

  @override
  Future<DashboardSummary> getSummary() async {
    final invoices = await _invoiceRepository.getInvoices(
      page: 1,
      pageSize: 200,
      forceRefresh: true,
    );

    final pending = invoices.where(
      (item) => item.status == InvoiceStatus.pending,
    );
    final overdue = invoices.where(
      (item) => item.status == InvoiceStatus.overdue,
    );
    final paid = invoices.where((item) => item.status == InvoiceStatus.paid);

    final totalUnpaid = invoices
        .where((item) => item.status != InvoiceStatus.paid)
        .fold<double>(0, (total, item) => total + item.amount);

    final smartTarget = _pickSmartReminderTarget(invoices);

    return DashboardSummaryModel(
      totalUnpaid: totalUnpaid,
      pendingCount: pending.length,
      overdueCount: overdue.length,
      paidCount: paid.length,
      smartReminderInvoiceId: smartTarget?.id,
      smartReminderText: smartTarget == null
          ? 'All caught up. No reminders needed right now.'
          : _localDatasource.buildSmartReminderText(smartTarget),
    );
  }

  Invoice? _pickSmartReminderTarget(List<Invoice> invoices) {
    final overdue = invoices
        .where((item) => item.status == InvoiceStatus.overdue)
        .toList(growable: false);
    if (overdue.isNotEmpty) {
      overdue.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      return overdue.first;
    }

    final pending = invoices
        .where((item) => item.status == InvoiceStatus.pending)
        .toList(growable: false);
    if (pending.isEmpty) {
      return null;
    }

    pending.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return pending.first;
  }
}
