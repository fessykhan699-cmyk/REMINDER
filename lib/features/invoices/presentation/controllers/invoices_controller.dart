import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/adaptive/adaptive_system_controller.dart';
import '../../../../shared/services/notification_service.dart';
import '../../../subscription/domain/entities/subscription_state.dart';
import '../../../subscription/presentation/controllers/subscription_controller.dart';
import '../../data/datasources/invoices_local_datasource.dart';
import '../../data/repositories/invoice_repository_impl.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/repositories/invoice_repository.dart';
import '../../domain/usecases/create_invoice_usecase.dart';
import '../../domain/usecases/delete_invoice_usecase.dart';
import '../../domain/usecases/get_invoices_usecase.dart';
import '../../domain/usecases/update_invoice_usecase.dart';
import 'invoice_creation_learning_controller.dart';

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

final deleteInvoiceUseCaseProvider = Provider<DeleteInvoiceUseCase>(
  (ref) => DeleteInvoiceUseCase(ref.watch(invoiceRepositoryProvider)),
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
  late final NotificationService _notificationService = ref.read(
    notificationServiceProvider,
  );

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

  Future<Invoice> createInvoice(Invoice invoice) async {
    await ref
        .read(subscriptionGatekeeperProvider)
        .ensureAllowed(SubscriptionGateFeature.createInvoice);

    final created = await ref.read(createInvoiceUseCaseProvider).call(invoice);
    final current = state.valueOrNull ?? const <Invoice>[];
    state = AsyncValue.data([created, ...current]);
    ref.invalidate(invoiceDetailProvider(invoice.id));
    await _runBestEffortSideEffect(
      'record invoice creation learning',
      () => ref
          .read(invoiceCreationLearningProvider.notifier)
          .recordCreatedInvoice(created),
    );
    await _runBestEffortSideEffect(
      'record new invoice adaptive action',
      () => ref
          .read(adaptiveSystemProvider.notifier)
          .recordAction(AdaptiveActionKey.newInvoice),
    );
    await _runBestEffortSideEffect(
      'schedule invoice reminders',
      () => _notificationService.scheduleInvoiceReminders(created),
    );
    return created;
  }

  Future<void> deleteInvoice(String invoiceId) async {
    final current = state.valueOrNull ?? const <Invoice>[];
    final updatedList = current
        .where((item) => item.id != invoiceId)
        .toList(growable: false);

    await ref.read(deleteInvoiceUseCaseProvider).call(invoiceId);
    await _notificationService.cancelInvoiceReminders(invoiceId);

    state = AsyncValue.data(updatedList);
    ref.invalidate(invoiceDetailProvider(invoiceId));
    await ref
        .read(invoiceCreationLearningProvider.notifier)
        .rebuildFromInvoices(updatedList);
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

    final dueDateChanged =
        previousInvoice != null &&
        !previousInvoice.dueDate.isAtSameMomentAs(updated.dueDate);
    if (updated.status == InvoiceStatus.paid) {
      await _runBestEffortSideEffect(
        'cancel invoice reminders',
        () => _notificationService.cancelInvoiceReminders(updated.id),
      );
    } else if (dueDateChanged ||
        previousInvoice?.status == InvoiceStatus.paid) {
      await _runBestEffortSideEffect(
        'reschedule invoice reminders',
        () => _notificationService.scheduleInvoiceReminders(updated),
      );
    }

    final wasUnpaid =
        previousInvoice != null && previousInvoice.status != InvoiceStatus.paid;
    if (wasUnpaid && updated.status == InvoiceStatus.paid) {
      await _runBestEffortSideEffect(
        'record mark paid adaptive action',
        () => ref
            .read(adaptiveSystemProvider.notifier)
            .recordAction(AdaptiveActionKey.markPaid),
      );
    }
  }

  Future<void> _runBestEffortSideEffect(
    String label,
    Future<void> Function() task,
  ) async {
    try {
      await task();
    } catch (error, stackTrace) {
      debugPrint('Invoice side effect failed for $label: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
