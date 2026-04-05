import '../../../invoices/domain/entities/invoice.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/entities/reminder_message_type.dart';
import '../../domain/repositories/reminder_repository.dart';
import '../datasources/reminders_local_datasource.dart';

class ReminderRepositoryImpl implements ReminderRepository {
  const ReminderRepositoryImpl(this._datasource);

  final RemindersLocalDatasource _datasource;

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
  }) {
    return _datasource.createReminderRecord(
      invoiceId: invoiceId,
      clientId: clientId,
      channel: channel,
      status: status,
    );
  }

  @override
  String buildPreviewMessage({
    required Invoice invoice,
    required ReminderMessageType type,
  }) {
    final dueDate = invoice.dueDate.toLocal().toString().split(' ').first;
    final amount = AppFormatters.currency(
      invoice.amount,
      currencyCode: invoice.currencyCode,
    );
    final paymentLinkLine = invoice.hasPaymentLink
        ? ' You can view or pay here: ${invoice.normalizedPaymentLink}'
        : '';

    switch (type) {
      case ReminderMessageType.professional:
        return 'Hello ${invoice.clientName}, this is a reminder that invoice '
            '${invoice.id} (${invoice.service}) for '
            '$amount is due on $dueDate. '
            'Please confirm your payment timeline.'
            '$paymentLinkLine';
      case ReminderMessageType.friendly:
        return 'Hi ${invoice.clientName}! Quick reminder about invoice '
            '${invoice.id} for ${invoice.service} '
            '($amount). '
            'It is due on $dueDate. '
            'Could you please share when payment will be processed? Thanks!'
            '$paymentLinkLine';
      case ReminderMessageType.firm:
        return 'Reminder: invoice ${invoice.id} for ${invoice.service} '
            '($amount) is due on $dueDate. '
            'Please arrange payment today to avoid service delays.'
            '$paymentLinkLine';
    }
  }
}
