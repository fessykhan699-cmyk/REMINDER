import 'package:hive/hive.dart';

import '../../../../core/utils/id_generator.dart';
import '../../../../core/storage/hive_storage.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/entities/reminder_message_type.dart';
import '../models/reminder_model.dart';

class RemindersLocalDatasource {
  final Box<ReminderModel> _remindersBox = Hive.box<ReminderModel>(
    HiveStorage.remindersBoxName,
  );

  Future<List<ReminderModel>> fetchReminders() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final reminders = _remindersBox.values.toList()
      ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
    return List<ReminderModel>.unmodifiable(reminders);
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

    await _remindersBox.put(reminder.id, reminder);
    return reminder;
  }

  Future<void> _triggerWhatsApp({required String message}) async {
    await Future<void>.delayed(const Duration(milliseconds: 110));
  }

  Future<void> _triggerSms({required String message}) async {
    await Future<void>.delayed(const Duration(milliseconds: 110));
  }
}
