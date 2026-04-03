import '../entities/invoice.dart';
import '../repositories/invoice_repository.dart';

class UpdateInvoiceUseCase {
  const UpdateInvoiceUseCase(this._repository);

  final InvoiceRepository _repository;

  Future<Invoice> call(Invoice invoice) => _repository.updateInvoice(invoice);
}
