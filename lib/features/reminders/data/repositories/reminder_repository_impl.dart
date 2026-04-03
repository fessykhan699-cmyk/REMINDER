import '../../../invoices/domain/entities/invoice.dart';
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
    required ReminderChannel channel,
    required ReminderMessageType messageType,
    required String message,
  }) {
    return _datasource.sendReminder(
      invoiceId: invoiceId,
      clientId: clientId,
      channel: channel,
      messageType: messageType,
      message: message,
    );
  }

  @override
  String buildPreviewMessage({
    required Invoice invoice,
    required ReminderMessageType type,
  }) {
    switch (type) {
      case ReminderMessageType.professional:
        return 'Hello ${invoice.clientName}, this is a reminder that invoice '
            '${invoice.id} (${invoice.service}) for '
            '\$${invoice.amount.toStringAsFixed(2)} is due on '
            '${invoice.dueDate.toLocal().toString().split(' ').first}. '
            'Please confirm your payment timeline.';
      case ReminderMessageType.friendly:
        return 'Hi ${invoice.clientName}! Quick reminder about invoice '
            '${invoice.id} for ${invoice.service} '
            '(\$${invoice.amount.toStringAsFixed(2)}). '
            'Could you please share when payment will be processed? Thanks!';
      case ReminderMessageType.firm:
        return 'Reminder: invoice ${invoice.id} for ${invoice.service} '
            '(\$${invoice.amount.toStringAsFixed(2)}) is overdue. '
            'Please arrange payment today to avoid service delays.';
    }
  }
}
