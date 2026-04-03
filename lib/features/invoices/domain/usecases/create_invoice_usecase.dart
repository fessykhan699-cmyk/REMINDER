import '../entities/invoice.dart';
import '../repositories/invoice_repository.dart';

class CreateInvoiceUseCase {
  const CreateInvoiceUseCase(this._repository);

  final InvoiceRepository _repository;

  Future<Invoice> call(Invoice invoice) => _repository.createInvoice(invoice);
}
