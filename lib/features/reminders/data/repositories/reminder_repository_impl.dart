import '../../../invoices/domain/entities/invoice.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/entities/reminder_message_type.dart';
import '../../domain/repositories/reminder_repository.dart';
import '../datasources/reminders_local_datasource.dart';
import '../models/reminder_model.dart';
import '../../../../data/services/firestore_sync_service.dart';

class ReminderRepositoryImpl implements ReminderRepository {
  const ReminderRepositoryImpl(
    this._datasource, {
    this.syncService,
    this.userId,
    this.isPro = false,
  });

  final RemindersLocalDatasource _datasource;
  final FirestoreSyncService? syncService;
  final String? userId;
  final bool isPro;

  @override
  Future<List<Reminder>> getReminders() => _datasource.fetchReminders();

  @override
  Future<Reminder> sendReminder({
    required String invoiceId,
    required String clientId,
    required String phoneNumber,
    required ReminderChannel channel,
    required String message,
  }) {
    return _datasource.sendReminder(
      invoiceId: invoiceId,
      clientId: clientId,
      phoneNumber: phoneNumber,
      channel: channel,
      message: message,
    );
  }

  @override
  Future<Reminder> createReminderRecord({
    required String invoiceId,
    required String clientId,
    required ReminderChannel channel,
    ReminderStatus status = ReminderStatus.sent,
  }) async {
    final saved = await _datasource.createReminderRecord(
      invoiceId: invoiceId,
      clientId: clientId,
      channel: channel,
      status: status,
    );
    _syncReminder(saved);
    return saved;
  }

  @override
  Future<void> deleteByInvoiceId(String invoiceId) =>
      _datasource.deleteByInvoiceId(invoiceId);

  @override
  Future<void> deleteByClientId(String clientId) =>
      _datasource.deleteByClientId(clientId);

  @override
  String buildPreviewMessage({
    required Invoice invoice,
    required ReminderMessageType type,
  }) {
    final clientName = invoice.clientName;
    final invoiceNumber = invoice.invoiceNumber.isNotEmpty
        ? invoice.invoiceNumber
        : invoice.id;
    final amount = AppFormatters.currency(
      invoice.amount,
      currencyCode: invoice.currencyCode,
    );
    final dueDate = AppFormatters.shortDate(invoice.dueDate.toLocal());
    final paymentLinkLine = invoice.hasPaymentLink
        ? '\n\nPay here: ${invoice.normalizedPaymentLink}'
        : '';

    switch (type) {
      case ReminderMessageType.professional:
        return 'Hi $clientName, hope you\'re doing well.\n\n'
            'This is a gentle reminder that invoice $invoiceNumber for '
            '$amount was due on $dueDate.\n\n'
            'If you\'ve already processed the payment, please disregard this '
            'message. Otherwise, kindly let us know when we can expect it.\n\n'
            'Thank you for your business. 🙏'
            '$paymentLinkLine';
      case ReminderMessageType.friendly:
        return 'Hey $clientName! 😊\n\n'
            'Just a quick heads-up — invoice $invoiceNumber for $amount '
            'was due on $dueDate.\n\n'
            'No worries if it slipped through — these things happen! '
            'Let me know if you need anything from my end to process it.\n\n'
            'Thanks a lot! 🙌'
            '$paymentLinkLine';
      case ReminderMessageType.firm:
        return 'Dear $clientName,\n\n'
            'This is a follow-up regarding invoice $invoiceNumber for '
            '$amount, which was due on $dueDate and remains unpaid.\n\n'
            'Please arrange payment at your earliest convenience. '
            'If there is an issue, do reach out so we can resolve it.\n\n'
            'Thank you.'
            '$paymentLinkLine';
    }
  }

  // ── Private sync helper ────────────────────────────────────────────────

  void _syncReminder(Reminder reminder) {
    final svc = syncService;
    final uid = userId;
    if (svc == null || uid == null) return;
    svc.syncReminderToCloud(
      userId: uid,
      isPro: isPro,
      reminder: ReminderModel.fromEntity(reminder),
    );
  }
}
