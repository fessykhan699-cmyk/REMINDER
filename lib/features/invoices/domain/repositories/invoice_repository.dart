import '../entities/invoice.dart';

abstract interface class InvoiceRepository {
  Future<List<Invoice>> getInvoices({
    int page = 1,
    int pageSize = 20,
    bool forceRefresh = false,
  });

  Future<Invoice> createInvoice(Invoice invoice);

  Future<Invoice> updateInvoice(Invoice invoice);

  Future<Invoice?> getInvoiceById(String id);
}
