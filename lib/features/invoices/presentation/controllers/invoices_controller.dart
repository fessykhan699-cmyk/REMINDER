import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/hive_storage.dart';
import '../../../../shared/adaptive/adaptive_system_controller.dart';
import '../../../../shared/services/invoice_export_service.dart';
import '../../../../shared/services/invoice_status_service.dart';
import '../../../../shared/services/reminder_service.dart';
import '../../../subscription/domain/entities/subscription_state.dart';
import '../../../subscription/presentation/controllers/subscription_controller.dart';
import '../../../clients/presentation/controllers/clients_controller.dart';
import '../../data/datasources/invoices_local_datasource.dart';
import '../../data/repositories/invoice_repository_impl.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/repositories/invoice_repository.dart';
import '../../../reminders/data/providers/reminder_repository_provider.dart';
import '../../domain/usecases/create_invoice_usecase.dart';
import '../../domain/usecases/delete_invoice_usecase.dart';
import '../../domain/usecases/get_invoices_usecase.dart';
import '../../domain/usecases/update_invoice_usecase.dart';
import 'invoice_creation_learning_controller.dart';

final invoicesLocalDatasourceProvider = Provider<InvoicesLocalDatasource>(
  (ref) => InvoicesLocalDatasource(ref.watch(clientsLocalDatasourceProvider)),
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
  (ref) => DeleteInvoiceUseCase(
    ref.watch(invoiceRepositoryProvider),
    ref.watch(reminderRepositoryProvider),
  ),
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
  bool _didLoad = false;
  late final ReminderService _reminderService = ref.read(
    reminderServiceProvider,
  );
  late final InvoiceExportService _invoiceExportService = ref.read(
    invoiceExportServiceProvider,
  );
  static const InvoiceStatusService _invoiceStatusService =
      InvoiceStatusService();

  bool get hasMore => _hasMore;

  @override
  AsyncValue<List<Invoice>> build() {
    if (!_didLoad) {
      _didLoad = true;
      Future(() => loadInitial());
    }
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

    final draftInvoice = _invoiceStatusService.prepareForCreate(invoice);
    final created = await ref
        .read(createInvoiceUseCaseProvider)
        .call(draftInvoice);
    final current = state.valueOrNull ?? const <Invoice>[];
    state = AsyncValue.data([created, ...current]);
    ref.invalidate(invoiceDetailProvider(created.id));
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
    await _runBestEffortSideEffect('generate invoice pdf', () async {
      await _invoiceExportService.saveInvoicePdf(created);
    });
    await _runBestEffortSideEffect(
      'schedule invoice reminders',
      () => _reminderService.scheduleInvoiceReminders(created),
    );
    return created;
  }

  Future<void> deleteInvoice(String invoiceId) async {
    await ref.read(deleteInvoiceUseCaseProvider).call(invoiceId);

    // Update controller state from fresh Hive data
    final box = HiveStorage.invoicesBox;
    final updated = box.values.toList();
    state = AsyncValue.data(updated);
    ref.invalidate(invoiceDetailProvider(invoiceId));

    await _runBestEffortSideEffect(
      'cancel invoice reminders',
      () => _reminderService.cancelInvoiceReminders(invoiceId),
    );
    await _runBestEffortSideEffect(
      'rebuild invoice learning',
      () => ref
          .read(invoiceCreationLearningProvider.notifier)
          .rebuildFromInvoices(updated),
    );
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

    final normalizedInvoice = _invoiceStatusService.prepareForUpdate(invoice);
    final updated = await ref
        .read(updateInvoiceUseCaseProvider)
        .call(normalizedInvoice);
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
        () => _reminderService.cancelInvoiceReminders(updated.id),
      );
    } else if (dueDateChanged ||
        previousInvoice?.status == InvoiceStatus.paid) {
      await _runBestEffortSideEffect(
        'reschedule invoice reminders',
        () => _reminderService.rescheduleInvoiceReminders(updated),
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

  Future<Invoice> markInvoiceSent(Invoice invoice) async {
    final next = _invoiceStatusService.markSent(invoice);
    await updateInvoice(next);
    return next;
  }

  Future<Invoice> markInvoicePaid(Invoice invoice) async {
    final next = _invoiceStatusService.markPaid(invoice);
    await updateInvoice(next);
    return next;
  }

  Future<void> _runBestEffortSideEffect(
    String label,
    Future<void> Function() task,
  ) async {
    try {
      await task();
    } catch (_) {
    }
  }
}
