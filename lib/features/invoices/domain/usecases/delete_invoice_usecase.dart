import '../repositories/invoice_repository.dart';

class DeleteInvoiceUseCase {
  const DeleteInvoiceUseCase(this._repository);

  final InvoiceRepository _repository;

  Future<void> call(String invoiceId) => _repository.deleteInvoice(invoiceId);
}
