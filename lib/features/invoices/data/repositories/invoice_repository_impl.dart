import '../../domain/entities/invoice.dart';
import '../../domain/repositories/invoice_repository.dart';
import '../datasources/invoices_local_datasource.dart';
import '../models/invoice_model.dart';
import '../../../../data/services/firestore_sync_service.dart';
import '../../../../data/services/notification_service.dart';
import '../../../../data/services/analytics_service.dart';

class InvoiceRepositoryImpl implements InvoiceRepository {
  const InvoiceRepositoryImpl(
    this._datasource, {
    this.syncService,
    this.userId,
  });

  final InvoicesLocalDatasource _datasource;
  final FirestoreSyncService? syncService;
  final String? userId;

  @override
  Future<List<Invoice>> getInvoices({
    int page = 1,
    int pageSize = 20,
    bool forceRefresh = false,
  }) {
    return _datasource.fetchInvoices(
      page: page,
      pageSize: pageSize,
      forceRefresh: forceRefresh,
    );
  }

  @override
  Future<Invoice> createInvoice(Invoice invoice) async {
    final model = InvoiceModel.fromEntity(invoice);
    final saved = await _datasource.createInvoice(model);
    _syncInvoice(saved);
    try {
      if (!saved.status.isPaid) {
        NotificationService.scheduleInvoiceReminders(saved);
      } else {
        NotificationService.cancelInvoiceReminders(saved.id);
      }
    } catch (_) {}
    
    // Log to Analytics
    AnalyticsService.instance.logInvoiceCreated(
      invoiceId: saved.id,
      amount: saved.amount,
      currency: saved.currencyCode,
    );

    return saved;
  }

  @override
  Future<Invoice> updateInvoice(Invoice invoice) async {
    final model = InvoiceModel.fromEntity(invoice);
    final saved = await _datasource.updateInvoice(model);
    _syncInvoice(saved);
    try {
      if (!saved.status.isPaid) {
        NotificationService.scheduleInvoiceReminders(saved);
      } else {
        NotificationService.cancelInvoiceReminders(saved.id);
      }
    } catch (_) {}
    return saved;
  }

  @override
  Future<void> deleteInvoice(String id) async {
    await _datasource.deleteInvoice(id);
    _deleteInvoice(id);
    try {
      NotificationService.cancelInvoiceReminders(id);
    } catch (_) {}
  }

  @override
  Future<Invoice?> getInvoiceById(String id) => _datasource.getInvoiceById(id);

  @override
  Future<String> getNextInvoiceId({required String prefix}) {
    return _datasource.getNextInvoiceId(prefix: prefix);
  }

  @override
  Future<void> deleteByClientId(String clientId) =>
      _datasource.deleteByClientId(clientId);

  // ── Private sync helpers (fire-and-forget) ─────────────────────────────

  void _syncInvoice(InvoiceModel model) {
    final svc = syncService;
    final uid = userId;
    if (svc == null || uid == null) return;
    svc.syncInvoiceToCloud(userId: uid, invoice: model);
  }

  void _deleteInvoice(String invoiceId) {
    final svc = syncService;
    final uid = userId;
    if (svc == null || uid == null) return;
    svc.deleteInvoiceFromCloud(userId: uid, invoiceId: invoiceId);
  }
}
