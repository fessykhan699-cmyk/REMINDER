import '../../../../core/utils/id_generator.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/entities/reminder_message_type.dart';
import '../models/reminder_model.dart';

class RemindersLocalDatasource {
  final List<ReminderModel> _reminders = [];

  Future<List<ReminderModel>> fetchReminders() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return List<ReminderModel>.unmodifiable(_reminders);
  }

  Future<ReminderModel> sendReminder({
    required String invoiceId,
    required String clientId,
    required ReminderChannel channel,
    required ReminderMessageType messageType,
    required String message,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 260));

    // Placeholder trigger logic for external channels.
    if (channel == ReminderChannel.whatsapp) {
      await _triggerWhatsApp(message: message);
    } else {
      await _triggerSms(message: message);
    }

    final reminder = ReminderModel(
      id: IdGenerator.nextId('rem'),
      invoiceId: invoiceId,
      clientId: clientId,
      sentAt: DateTime.now(),
      channel: channel,
      status: ReminderStatus.sent,
    );

    _reminders.insert(0, reminder);
    return reminder;
  }

  Future<void> _triggerWhatsApp({required String message}) async {
    await Future<void>.delayed(const Duration(milliseconds: 110));
  }

  Future<void> _triggerSms({required String message}) async {
    await Future<void>.delayed(const Duration(milliseconds: 110));
  }
}
