import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:reminder/domain/entities/payment.dart';
import 'package:reminder/features/clients/domain/entities/client.dart';
import 'package:reminder/features/clients/presentation/controllers/clients_controller.dart';
import 'package:reminder/features/invoices/domain/entities/invoice.dart';
import 'package:reminder/features/invoices/domain/repositories/invoice_repository.dart';
import 'package:reminder/features/invoices/domain/usecases/create_invoice_usecase.dart';
import 'package:reminder/features/invoices/domain/usecases/delete_invoice_usecase.dart';
import 'package:reminder/features/invoices/domain/usecases/get_invoices_usecase.dart';
import 'package:reminder/features/invoices/domain/usecases/update_invoice_usecase.dart';
import 'package:reminder/features/invoices/presentation/controllers/invoices_controller.dart';
import 'package:reminder/features/reminders/domain/entities/reminder.dart';
import 'package:reminder/features/reminders/domain/entities/reminder_message_type.dart';
import 'package:reminder/features/reminders/domain/repositories/reminder_repository.dart';
import 'package:reminder/features/subscription/domain/entities/subscription_state.dart';
import 'package:reminder/features/subscription/presentation/controllers/subscription_controller.dart';
import 'package:reminder/shared/services/notification_service.dart';
import 'package:reminder/shared/services/reminder_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('InvoicesController', () {
    test('state is AsyncLoading initially before load completes', () async {
      final getInvoicesCompleter = Completer<List<Invoice>>();
      final repo = _SpyInvoiceRepository(
        getInvoicesHandler: ({
          required int page,
          required int pageSize,
          required bool forceRefresh,
        }) => getInvoicesCompleter.future,
      );
      final container = _createContainer(repo: repo);

      addTearDown(container.dispose);

      final initialState = container.read(invoicesControllerProvider);
      expect(initialState.isLoading, isTrue);

      getInvoicesCompleter.complete(const <Invoice>[]);
      await _waitForInvoices(container);
    });

    test('loadInitial populates state with invoice list', () async {
      final invoices = [
        _invoice(id: 'inv-1'),
        _invoice(id: 'inv-2'),
        _invoice(id: 'inv-3'),
      ];
      final repo = _SpyInvoiceRepository(initialInvoices: invoices);
      final container = _createContainer(repo: repo);

      addTearDown(container.dispose);

      final state = await _waitForInvoices(container);

      expect(state, hasLength(3));
      expect(state.map((e) => e.id), ['inv-1', 'inv-2', 'inv-3']);
    });

    test('createInvoice calls repository.createInvoice once', () async {
      final repo = _SpyInvoiceRepository(initialInvoices: const <Invoice>[]);
      final container = _createContainer(repo: repo, allowCreateInvoice: true);

      addTearDown(container.dispose);
      await _waitForInvoices(container);

      final controller = container.read(invoicesControllerProvider.notifier);
      final invoice = _invoice(id: 'inv-create');

      await controller.createInvoice(invoice);

      expect(repo.createInvoiceCalls, 1);
      expect(repo.createdInvoices.single.id, 'inv-create');
    });

    test('updateInvoice calls repository.updateInvoice once', () async {
      final existing = _invoice(id: 'inv-update');
      final updatedInvoice = existing.copyWith(service: 'Updated Service');
      final repo = _SpyInvoiceRepository(
        initialInvoices: [existing],
        updateInvoiceResult: updatedInvoice,
      );
      final container = _createContainer(repo: repo);

      addTearDown(container.dispose);
      await _waitForInvoices(container);

      final controller = container.read(invoicesControllerProvider.notifier);
      await controller.updateInvoice(updatedInvoice);

      expect(repo.updateInvoiceCalls, 1);
      expect(repo.updatedInvoices.single.id, 'inv-update');
      expect(repo.updatedInvoices.single.service, 'Updated Service');
    });

    test('deleteInvoice calls repository.deleteInvoice with correct id', () async {
      final repo = _SpyInvoiceRepository(
        initialInvoices: [_invoice(id: 'inv-delete')],
      );
      final container = _createContainer(repo: repo);

      addTearDown(container.dispose);
      await _waitForInvoices(container);

      final controller = container.read(invoicesControllerProvider.notifier);
      await controller.deleteInvoice('inv-delete');

      expect(repo.deletedInvoiceIds, ['inv-delete']);
    });

    test(
      'createInvoice is blocked when subscription gate denies invoice creation',
      () async {
        final repo = _SpyInvoiceRepository(initialInvoices: const <Invoice>[]);
        final container = _createContainer(repo: repo, allowCreateInvoice: false);

        addTearDown(container.dispose);
        await _waitForInvoices(container);

        final controller = container.read(invoicesControllerProvider.notifier);

        await expectLater(
          () => controller.createInvoice(_invoice(id: 'inv-blocked')),
          throwsA(isA<SubscriptionGateException>()),
        );

        expect(repo.createInvoiceCalls, 0);
      },
    );
  });
}

Future<List<Invoice>> _waitForInvoices(ProviderContainer container) async {
  for (var i = 0; i < 100; i++) {
    final state = container.read(invoicesControllerProvider);
    if (state.hasValue) {
      return state.requireValue;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  throw StateError('Timed out waiting for invoices controller data');
}

ProviderContainer _createContainer({
  required _SpyInvoiceRepository repo,
  bool allowCreateInvoice = true,
}) {
  return ProviderContainer(
    overrides: [
      clientsControllerProvider.overrideWith(_StubClientsController.new),
      getInvoicesUseCaseProvider.overrideWithValue(GetInvoicesUseCase(repo)),
      createInvoiceUseCaseProvider.overrideWithValue(CreateInvoiceUseCase(repo)),
      updateInvoiceUseCaseProvider.overrideWithValue(UpdateInvoiceUseCase(repo)),
      deleteInvoiceUseCaseProvider.overrideWithValue(
        DeleteInvoiceUseCase(repo, _NoopReminderRepository()),
      ),
      subscriptionGatekeeperProvider.overrideWith(
        (ref) => _FakeGatekeeper(
          ref,
          allowCreateInvoice: allowCreateInvoice,
        ),
      ),
      reminderServiceProvider.overrideWithValue(_NoopReminderService()),
    ],
  );
}

Invoice _invoice({required String id}) {
  final now = DateTime(2026, 1, 10);
  return Invoice(
    id: id,
    clientId: 'client-1',
    clientName: 'Acme LLC',
    amount: 500,
    dueDate: now.add(const Duration(days: 7)),
    createdAt: now,
    status: InvoiceStatus.draft,
    service: 'Design',
    invoiceNumber: 'INV-001',
    payments: const <Payment>[],
  );
}

class _StubClientsController extends ClientsController {
  @override
  AsyncValue<List<Client>> build() => const AsyncValue.data(<Client>[]);
}

class _FakeGatekeeper extends SubscriptionGatekeeper {
  _FakeGatekeeper(super.ref, {required this.allowCreateInvoice});

  final bool allowCreateInvoice;

  @override
  Future<void> ensureAllowed(SubscriptionGateFeature feature) async {
    if (feature == SubscriptionGateFeature.createInvoice && !allowCreateInvoice) {
      throw SubscriptionGateException(
        SubscriptionGateDecision.blocked(
          feature: feature,
          reason: SubscriptionGateReason.premiumFeature,
          promptTitle: 'Blocked',
          promptMessage: 'Blocked',
        ),
      );
    }
  }
}

class _NoopReminderRepository implements ReminderRepository {
  @override
  String buildPreviewMessage({
    required Invoice invoice,
    required ReminderMessageType type,
  }) => '';

  @override
  Future<Reminder> createReminderRecord({
    required String invoiceId,
    required String clientId,
    required ReminderChannel channel,
    ReminderStatus status = ReminderStatus.sent,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteByClientId(String clientId) async {}

  @override
  Future<void> deleteByInvoiceId(String invoiceId) async {}

  @override
  Future<List<Reminder>> getReminders() async => const <Reminder>[];

  @override
  Future<Reminder> sendReminder({
    required String invoiceId,
    required String clientId,
    required String phoneNumber,
    required ReminderChannel channel,
    required String message,
  }) {
    throw UnimplementedError();
  }
}

class _NoopReminderService extends ReminderService {
  _NoopReminderService() : super(notificationService: NotificationService.instance);

  @override
  Future<void> cancelInvoiceReminders(String invoiceId) async {}

  @override
  Future<void> rescheduleInvoiceReminders(Invoice invoice) async {}

  @override
  Future<void> scheduleInvoiceReminders(Invoice invoice) async {}
}

class _SpyInvoiceRepository implements InvoiceRepository {
  _SpyInvoiceRepository({
    List<Invoice>? initialInvoices,
    this.getInvoicesHandler,
    Invoice? createInvoiceResult,
    Invoice? updateInvoiceResult,
  }) : _invoices = initialInvoices ?? const <Invoice>[],
       _createInvoiceResult = createInvoiceResult,
       _updateInvoiceResult = updateInvoiceResult;

  final Future<List<Invoice>> Function({
    required int page,
    required int pageSize,
    required bool forceRefresh,
  })?
  getInvoicesHandler;
  List<Invoice> _invoices;
  final Invoice? _createInvoiceResult;
  final Invoice? _updateInvoiceResult;

  int createInvoiceCalls = 0;
  int updateInvoiceCalls = 0;
  final List<Invoice> createdInvoices = <Invoice>[];
  final List<Invoice> updatedInvoices = <Invoice>[];
  final List<String> deletedInvoiceIds = <String>[];

  @override
  Future<Invoice> createInvoice(Invoice invoice) async {
    createInvoiceCalls += 1;
    createdInvoices.add(invoice);
    final result = _createInvoiceResult ?? invoice;
    _invoices = [result, ..._invoices];
    return result;
  }

  @override
  Future<void> deleteByClientId(String clientId) async {}

  @override
  Future<void> deleteInvoice(String id) async {
    deletedInvoiceIds.add(id);
    _invoices = _invoices.where((invoice) => invoice.id != id).toList();
  }

  @override
  Future<Invoice?> getInvoiceById(String id) async {
    for (final invoice in _invoices) {
      if (invoice.id == id) {
        return invoice;
      }
    }
    return null;
  }

  @override
  Future<List<Invoice>> getInvoices({
    int page = 1,
    int pageSize = 20,
    bool forceRefresh = false,
  }) async {
    final handler = getInvoicesHandler;
    if (handler != null) {
      return handler(page: page, pageSize: pageSize, forceRefresh: forceRefresh);
    }
    return _invoices;
  }

  @override
  Future<String> getNextInvoiceId({required String prefix}) async =>
      '${prefix}0001';

  @override
  Future<Invoice> updateInvoice(Invoice invoice) async {
    updateInvoiceCalls += 1;
    updatedInvoices.add(invoice);
    final result = _updateInvoiceResult ?? invoice;
    _invoices = [
      for (final existing in _invoices)
        if (existing.id == invoice.id) result else existing,
    ];
    return result;
  }
}
