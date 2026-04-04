import '../../../invoices/domain/entities/invoice.dart';
import '../entities/reminder.dart';
import '../entities/reminder_message_type.dart';

abstract interface class ReminderRepository {
  Future<List<Reminder>> getReminders();

  Future<Reminder> sendReminder({
    required String invoiceId,
    required String clientId,
    required String phoneNumber,
    required ReminderChannel channel,
    required String message,
  });

  String buildPreviewMessage({
    required Invoice invoice,
    required ReminderMessageType type,
  });
}
