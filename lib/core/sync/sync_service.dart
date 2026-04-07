import '../../features/clients/data/models/client_model.dart';
import '../../features/invoices/data/models/invoice_model.dart';

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  // Firebase sync disabled (permission-denied). Hive is the single source of truth.
  Future<void> syncClientToFirebase(ClientModel client) async {}

  Future<void> syncInvoiceToFirebase(InvoiceModel invoice) async {}

  Future<void> deleteClientFromFirebase(String clientId) async {}

  Future<void> deleteInvoiceFromFirebase(String invoiceId) async {}
}
