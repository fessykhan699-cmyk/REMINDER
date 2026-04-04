import '../../features/reminders/domain/entities/reminder.dart';

abstract interface class ReminderService {
  Future<List<Reminder>> fetchReminders();

  Future<Reminder> sendReminder({
    required String invoiceId,
    required String clientId,
    required String phoneNumber,
    required ReminderChannel channel,
    required String message,
  });
}
