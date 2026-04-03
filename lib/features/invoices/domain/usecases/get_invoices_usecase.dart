import '../entities/invoice.dart';
import '../repositories/invoice_repository.dart';

class GetInvoicesUseCase {
  const GetInvoicesUseCase(this._repository);

  final InvoiceRepository _repository;

  Future<List<Invoice>> call({
    int page = 1,
    int pageSize = 20,
    bool forceRefresh = false,
  }) {
    return _repository.getInvoices(
      page: page,
      pageSize: pageSize,
      forceRefresh: forceRefresh,
    );
  }
}
