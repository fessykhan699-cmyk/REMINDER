import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/hive_storage.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../shared/adaptive/adaptive_system_controller.dart';
import '../../../../shared/services/invoice_export_service.dart';
import '../../../../shared/services/invoice_status_service.dart';
import '../../../../shared/services/reminder_service.dart';
import '../../../subscription/domain/entities/subscription_state.dart';
import '../../../subscription/presentation/controllers/subscription_controller.dart';
import '../../data/datasources/invoices_local_datasource.dart';
import '../../data/models/invoice_model.dart';
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
    SyncService.instance.syncInvoiceToFirebase(
      InvoiceModel.fromEntity(created),
    );
    return created;
  }

  Future<void> deleteInvoice(String invoiceId) async {
    debugPrint("DELETE START: $invoiceId");

    // 🔥 FORCE DELETE FROM HIVE
    try {
      debugPrint("HIVE: Attempting direct delete from invoices box");
      final box = HiveStorage.invoicesBox;
      debugPrint("HIVE: Box contains ${box.length} invoices");
      debugPrint("HIVE: All keys: ${box.keys.toList()}");

      dynamic keyToDelete;
      for (final key in box.keys) {
        final item = box.get(key);
        if (item != null && item.id == invoiceId) {
          keyToDelete = key;
          debugPrint(
            "HIVE: Found matching key: $keyToDelete for id: $invoiceId",
          );
          break;
        }
      }

      if (keyToDelete != null) {
        await box.delete(keyToDelete);
        debugPrint("HIVE DELETE SUCCESS");
      } else {
        debugPrint("HIVE: ID NOT FOUND in box");
      }

      final updated = box.values.toList();
      debugPrint("HIVE COUNT AFTER DELETE: ${updated.length}");

      // Update controller state
      state = AsyncValue.data(updated);
      ref.invalidate(invoiceDetailProvider(invoiceId));
    } catch (e, st) {
      debugPrint("HIVE ERROR: $e");
      debugPrintStack(stackTrace: st);
    }

    // 🔥 ALSO DELETE FROM FIREBASE (safety net)
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('invoices')
            .doc(invoiceId)
            .delete();
        debugPrint("FIREBASE DELETE SUCCESS");
      } else {
        debugPrint("FIREBASE: No user logged in, skipping");
      }
    } catch (e) {
      debugPrint("FIREBASE DELETE ERROR: $e");
    }

    // 🔥 Cancel reminders
    try {
      await _reminderService.cancelInvoiceReminders(invoiceId);
    } catch (e) {
      debugPrint("REMINDER CANCEL ERROR: $e");
    }

    debugPrint("FINAL STATE LENGTH: ${state.value?.length ?? 0}");

    await ref
        .read(invoiceCreationLearningProvider.notifier)
        .rebuildFromInvoices(state.value ?? []);
  }

  Future<void> updateInvoice(Invoice invoice) async {
    debugPrint("Controller: updateInvoice called for ID: ${invoice.id}");
    final current = state.valueOrNull ?? const <Invoice>[];
    debugPrint("Controller: current state has ${current.length} invoices");
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
    debugPrint("Controller: update completed, ID: ${updated.id}");

    final updatedList = current
        .map((item) => item.id == updated.id ? updated : item)
        .toList(growable: false);

    state = AsyncValue.data(updatedList);
    ref.invalidate(invoiceDetailProvider(invoice.id));
    SyncService.instance.syncInvoiceToFirebase(
      InvoiceModel.fromEntity(updated),
    );

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
    debugPrint("Controller: markInvoiceSent for ID: ${invoice.id}");
    final next = _invoiceStatusService.markSent(invoice);
    await updateInvoice(next);
    return next;
  }

  Future<Invoice> markInvoicePaid(Invoice invoice) async {
    debugPrint("Controller: markInvoicePaid for ID: ${invoice.id}");
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
    } catch (error, stackTrace) {
      debugPrint('Invoice side effect failed for $label: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
