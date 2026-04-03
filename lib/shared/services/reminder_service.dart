import '../../features/reminders/domain/entities/reminder.dart';
import '../../features/reminders/domain/entities/reminder_message_type.dart';

abstract interface class ReminderService {
  Future<List<Reminder>> fetchReminders();

  Future<Reminder> sendReminder({
    required String invoiceId,
    required String clientId,
    required ReminderChannel channel,
    required ReminderMessageType messageType,
    required String message,
  });
}
