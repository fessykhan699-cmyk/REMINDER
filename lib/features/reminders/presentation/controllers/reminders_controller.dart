import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../invoices/domain/entities/invoice.dart';
import '../../../invoices/domain/repositories/invoice_repository.dart';
import '../../../invoices/presentation/controllers/invoices_controller.dart';
import '../../data/datasources/reminders_local_datasource.dart';
import '../../data/repositories/reminder_repository_impl.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/entities/reminder_message_type.dart';
import '../../domain/repositories/reminder_repository.dart';
import '../../domain/usecases/send_reminder_usecase.dart';

class ReminderFlowState {
  const ReminderFlowState({
    required this.invoice,
    required this.messageType,
    required this.previewMessage,
    required this.isSending,
    required this.errorMessage,
    required this.successMessage,
  });

  factory ReminderFlowState.initial() {
    return const ReminderFlowState(
      invoice: null,
      messageType: ReminderMessageType.professional,
      previewMessage: '',
      isSending: false,
      errorMessage: null,
      successMessage: null,
    );
  }

  final Invoice? invoice;
  final ReminderMessageType messageType;
  final String previewMessage;
  final bool isSending;
  final String? errorMessage;
  final String? successMessage;

  ReminderFlowState copyWith({
    Invoice? invoice,
    bool replaceInvoice = false,
    ReminderMessageType? messageType,
    String? previewMessage,
    bool? isSending,
    String? errorMessage,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return ReminderFlowState(
      invoice: replaceInvoice ? invoice : (invoice ?? this.invoice),
      messageType: messageType ?? this.messageType,
      previewMessage: previewMessage ?? this.previewMessage,
      isSending: isSending ?? this.isSending,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess
          ? null
          : (successMessage ?? this.successMessage),
    );
  }
}

final remindersLocalDatasourceProvider = Provider<RemindersLocalDatasource>(
  (ref) => RemindersLocalDatasource(),
);

final reminderRepositoryProvider = Provider<ReminderRepository>(
  (ref) => ReminderRepositoryImpl(ref.watch(remindersLocalDatasourceProvider)),
);

final sendReminderUseCaseProvider = Provider<SendReminderUseCase>(
  (ref) => SendReminderUseCase(ref.watch(reminderRepositoryProvider)),
);

final reminderFlowControllerProvider =
    AutoDisposeNotifierProviderFamily<
      RemindersController,
      ReminderFlowState,
      String
    >(RemindersController.new);

class RemindersController
    extends AutoDisposeFamilyNotifier<ReminderFlowState, String> {
  late final ReminderRepository _reminderRepository = ref.read(
    reminderRepositoryProvider,
  );
  late final InvoiceRepository _invoiceRepository = ref.read(
    invoiceRepositoryProvider,
  );

  @override
  ReminderFlowState build(String invoiceId) {
    Future<void>(() => _bootstrap(invoiceId));
    return ReminderFlowState.initial();
  }

  Future<void> _bootstrap(String invoiceId) async {
    final invoice = await _invoiceRepository.getInvoiceById(invoiceId);

    if (invoice == null) {
      state = state.copyWith(errorMessage: 'Invoice not found.');
      return;
    }

    state = state.copyWith(
      invoice: invoice,
      previewMessage: _reminderRepository.buildPreviewMessage(
        invoice: invoice,
        type: state.messageType,
      ),
      clearError: true,
      clearSuccess: true,
    );
  }

  void selectMessageType(ReminderMessageType type) {
    final invoice = state.invoice;
    if (invoice == null) {
      return;
    }

    state = state.copyWith(
      messageType: type,
      previewMessage: _reminderRepository.buildPreviewMessage(
        invoice: invoice,
        type: type,
      ),
      clearError: true,
      clearSuccess: true,
    );
  }

  Future<void> sendReminder(ReminderChannel channel) async {
    final invoice = state.invoice;
    if (invoice == null || state.isSending) {
      return;
    }

    state = state.copyWith(
      isSending: true,
      clearError: true,
      clearSuccess: true,
    );

    try {
      final message = _reminderRepository.buildPreviewMessage(
        invoice: invoice,
        type: state.messageType,
      );

      await ref
          .read(sendReminderUseCaseProvider)
          .call(
            invoiceId: invoice.id,
            clientId: invoice.clientId,
            channel: channel,
            messageType: state.messageType,
            message: message,
          );

      state = state.copyWith(
        isSending: false,
        successMessage: 'Reminder queued via ${channel.label}.',
      );
    } catch (error) {
      state = state.copyWith(isSending: false, errorMessage: error.toString());
    }
  }
}
