import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/adaptive/adaptive_system_controller.dart';
import '../../../../shared/services/reminder_launcher_service.dart';
import '../../../clients/domain/repositories/client_repository.dart';
import '../../../clients/presentation/controllers/clients_controller.dart';
import '../../../invoices/domain/entities/invoice.dart';
import '../../../invoices/domain/repositories/invoice_repository.dart';
import '../../../invoices/presentation/controllers/invoices_controller.dart';
import '../../../settings/domain/repositories/settings_repository.dart';
import '../../../settings/presentation/controllers/settings_controller.dart';
import '../../../subscription/domain/entities/subscription_state.dart';
import '../../../subscription/presentation/controllers/subscription_controller.dart';
import '../../data/datasources/reminders_local_datasource.dart';
import '../../data/repositories/reminder_repository_impl.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/entities/reminder_message_type.dart';
import '../../domain/repositories/reminder_repository.dart';
import '../../domain/usecases/send_reminder_usecase.dart';

class ReminderFlowState {
  const ReminderFlowState({
    required this.invoice,
    required this.clientPhone,
    required this.messageType,
    required this.previewMessage,
    required this.isSending,
    required this.errorMessage,
    required this.successMessage,
  });

  factory ReminderFlowState.initial() {
    return const ReminderFlowState(
      invoice: null,
      clientPhone: null,
      messageType: ReminderMessageType.professional,
      previewMessage: '',
      isSending: false,
      errorMessage: null,
      successMessage: null,
    );
  }

  final Invoice? invoice;
  final String? clientPhone;
  final ReminderMessageType messageType;
  final String previewMessage;
  final bool isSending;
  final String? errorMessage;
  final String? successMessage;

  bool get canSendReminder {
    final digits = (clientPhone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 8 && digits.length <= 15;
  }

  ReminderFlowState copyWith({
    Invoice? invoice,
    bool replaceInvoice = false,
    String? clientPhone,
    bool replaceClientPhone = false,
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
      clientPhone: replaceClientPhone
          ? clientPhone
          : (clientPhone ?? this.clientPhone),
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
  (ref) => RemindersLocalDatasource(ref.watch(reminderLauncherServiceProvider)),
);

final reminderRepositoryProvider = Provider<ReminderRepository>(
  (ref) => ReminderRepositoryImpl(ref.watch(remindersLocalDatasourceProvider)),
);

final sendReminderUseCaseProvider = Provider<SendReminderUseCase>(
  (ref) => SendReminderUseCase(ref.watch(reminderRepositoryProvider)),
);

final remindersHistoryProvider = FutureProvider<List<Reminder>>((ref) {
  return ref.watch(reminderRepositoryProvider).getReminders();
});

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
  late final ClientRepository _clientRepository = ref.read(
    clientRepositoryProvider,
  );
  late final InvoiceRepository _invoiceRepository = ref.read(
    invoiceRepositoryProvider,
  );
  late final SettingsRepository _settingsRepository = ref.read(
    settingsRepositoryProvider,
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

    final client = await _clientRepository.getClientById(invoice.clientId);

    state = state.copyWith(
      invoice: invoice,
      clientPhone: client?.phone,
      replaceClientPhone: true,
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

    if (channel == ReminderChannel.whatsapp) {
      await ref
          .read(subscriptionGatekeeperProvider)
          .ensureAllowed(SubscriptionGateFeature.whatsappSharing);
    }

    final preferences = await _settingsRepository.getAppPreferences();
    final isChannelEnabled = switch (channel) {
      ReminderChannel.whatsapp => preferences.whatsAppRemindersEnabled,
      ReminderChannel.sms => preferences.smsRemindersEnabled,
    };
    if (!isChannelEnabled) {
      state = state.copyWith(
        errorMessage: '${channel.label} reminders are turned off in Settings.',
        clearSuccess: true,
      );
      return;
    }

    final phoneNumber = state.clientPhone;
    if (!state.canSendReminder || phoneNumber == null) {
      state = state.copyWith(
        errorMessage: 'Client phone number is missing.',
        clearSuccess: true,
      );
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

      final reminder = await ref
          .read(sendReminderUseCaseProvider)
          .call(
            invoiceId: invoice.id,
            clientId: invoice.clientId,
            phoneNumber: phoneNumber,
            channel: channel,
            message: message,
          );

      state = state.copyWith(
        isSending: false,
        successMessage: reminder.channel == channel
            ? 'Reminder opened in ${reminder.channel.label}.'
            : 'WhatsApp unavailable. Opened SMS instead.',
      );
      ref.invalidate(remindersHistoryProvider);
      await ref
          .read(adaptiveSystemProvider.notifier)
          .recordAction(AdaptiveActionKey.sendReminder);
    } catch (error) {
      state = state.copyWith(isSending: false, errorMessage: error.toString());
    }
  }
}
