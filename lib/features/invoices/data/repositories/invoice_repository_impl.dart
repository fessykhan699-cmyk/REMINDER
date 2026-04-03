import '../../domain/entities/invoice.dart';
import '../../domain/repositories/invoice_repository.dart';
import '../datasources/invoices_local_datasource.dart';
import '../models/invoice_model.dart';

class InvoiceRepositoryImpl implements InvoiceRepository {
  const InvoiceRepositoryImpl(this._datasource);

  final InvoicesLocalDatasource _datasource;

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
  Future<Invoice> createInvoice(Invoice invoice) {
    return _datasource.createInvoice(InvoiceModel.fromEntity(invoice));
  }

  @override
  Future<Invoice> updateInvoice(Invoice invoice) {
    return _datasource.updateInvoice(InvoiceModel.fromEntity(invoice));
  }

  @override
  Future<void> deleteInvoice(String id) {
    return _datasource.deleteInvoice(id);
  }

  @override
  Future<Invoice?> getInvoiceById(String id) => _datasource.getInvoiceById(id);
}
