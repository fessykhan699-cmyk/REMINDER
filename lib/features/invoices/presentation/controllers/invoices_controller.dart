import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/adaptive/adaptive_system_controller.dart';
import '../../data/datasources/invoices_local_datasource.dart';
import '../../data/repositories/invoice_repository_impl.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/repositories/invoice_repository.dart';
import '../../domain/usecases/create_invoice_usecase.dart';
import '../../domain/usecases/get_invoices_usecase.dart';
import '../../domain/usecases/update_invoice_usecase.dart';

final invoicesLocalDatasourceProvider = Provider<InvoicesLocalDatasource>(
  (ref) => InvoicesLocalDatasource(),
);

final invoiceRepositoryProvider = Provider<InvoiceRepository>(
  (ref) => InvoiceRepositoryImpl(ref.watch(invoicesLocalDatasourceProvider)),
);

final getInvoicesUseCaseProvider = Provider<GetInvoicesUseCase>(
  (ref) => GetInvoicesUseCase(ref.watch(invoiceRepositoryProvider)),
);

final createInvoiceUseCaseProvider = Provider<CreateInvoiceUseCase>(
  (ref) => CreateInvoiceUseCase(ref.watch(invoiceRepositoryProvider)),
);

final updateInvoiceUseCaseProvider = Provider<UpdateInvoiceUseCase>(
  (ref) => UpdateInvoiceUseCase(ref.watch(invoiceRepositoryProvider)),
);

final invoicesControllerProvider =
    NotifierProvider<InvoicesController, AsyncValue<List<Invoice>>>(
      InvoicesController.new,
    );

final invoiceDetailProvider = FutureProvider.family<Invoice?, String>((
  ref,
  id,
) {
  return ref.watch(invoiceRepositoryProvider).getInvoiceById(id);
});

class InvoicesController extends Notifier<AsyncValue<List<Invoice>>> {
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  bool get hasMore => _hasMore;

  @override
  AsyncValue<List<Invoice>> build() {
    Future<void>(loadInitial);
    return const AsyncValue.loading();
  }

  Future<void> loadInitial() async {
    _currentPage = 1;
    _hasMore = true;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref
          .read(getInvoicesUseCaseProvider)
          .call(
            page: 1,
            pageSize: AppConstants.defaultPageSize,
            forceRefresh: true,
          ),
    );
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore || state.isLoading) {
      return;
    }

    _isLoadingMore = true;

    try {
      final current = state.valueOrNull ?? const <Invoice>[];
      final nextPage = _currentPage + 1;
      final next = await ref
          .read(getInvoicesUseCaseProvider)
          .call(page: nextPage, pageSize: AppConstants.defaultPageSize);

      if (next.isEmpty) {
        _hasMore = false;
      } else {
        _currentPage = nextPage;
        state = AsyncValue.data([...current, ...next]);
      }
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> createInvoice(Invoice invoice) async {
    final created = await ref.read(createInvoiceUseCaseProvider).call(invoice);
    final current = state.valueOrNull ?? const <Invoice>[];
    state = AsyncValue.data([created, ...current]);
    ref.invalidate(invoiceDetailProvider(invoice.id));
    await ref
        .read(adaptiveSystemProvider.notifier)
        .recordAction(AdaptiveActionKey.newInvoice);
  }

  Future<void> updateInvoice(Invoice invoice) async {
    final current = state.valueOrNull ?? const <Invoice>[];
    Invoice? previousInvoice;
    for (final item in current) {
      if (item.id == invoice.id) {
        previousInvoice = item;
        break;
      }
    }

    final updated = await ref.read(updateInvoiceUseCaseProvider).call(invoice);

    final updatedList = current
        .map((item) => item.id == updated.id ? updated : item)
        .toList(growable: false);

    state = AsyncValue.data(updatedList);
    ref.invalidate(invoiceDetailProvider(invoice.id));

    final wasUnpaid =
        previousInvoice != null && previousInvoice.status != InvoiceStatus.paid;
    if (wasUnpaid && updated.status == InvoiceStatus.paid) {
      await ref
          .read(adaptiveSystemProvider.notifier)
          .recordAction(AdaptiveActionKey.markPaid);
    }
  }
}
