import 'package:hive/hive.dart';

import '../../../../core/storage/hive_storage.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../shared/services/reminder_launcher_service.dart';
import '../../domain/entities/reminder.dart';
import '../models/reminder_model.dart';

class RemindersLocalDatasource {
  RemindersLocalDatasource(this._launcherService);

  final ReminderLauncherService _launcherService;
  final Box<ReminderModel> _remindersBox = Hive.box<ReminderModel>(
    HiveStorage.remindersBoxName,
  );

  Future<List<ReminderModel>> fetchReminders() async {
    final reminders = _remindersBox.values.toList()
      ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
    return List<ReminderModel>.unmodifiable(reminders);
  }

  Future<ReminderModel> sendReminder({
    required String invoiceId,
    required String clientId,
    required String phoneNumber,
    required ReminderChannel channel,
    required String message,
  }) async {
    try {
      final launchResult = await _launcherService.launchReminder(
        preferredChannel: channel,
        phoneNumber: phoneNumber,
        message: message,
      );

      return createReminderRecord(
        invoiceId: invoiceId,
        clientId: clientId,
        channel: launchResult.channel,
        status: ReminderStatus.sent,
      );
    } catch (_) {
      await createReminderRecord(
        invoiceId: invoiceId,
        clientId: clientId,
        channel: channel,
        status: ReminderStatus.failed,
      );
      rethrow;
    }
  }

  Future<void> deleteByInvoiceId(String invoiceId) async {
    final keysToDelete = _remindersBox.values
        .where((r) => r.invoiceId == invoiceId)
        .map((r) => r.id)
        .toList();
    await _remindersBox.deleteAll(keysToDelete);
  }

  Future<void> deleteByClientId(String clientId) async {
    final keysToDelete = _remindersBox.values
        .where((r) => r.clientId == clientId)
        .map((r) => r.id)
        .toList();
    await _remindersBox.deleteAll(keysToDelete);
  }

  Future<ReminderModel> createReminderRecord({
    required String invoiceId,
    required String clientId,
    required ReminderChannel channel,
    ReminderStatus status = ReminderStatus.sent,
  }) async {
    final reminder = ReminderModel(
      id: IdGenerator.nextId('rem'),
      invoiceId: invoiceId,
      clientId: clientId,
      sentAt: DateTime.now(),
      channel: channel,
      status: status,
    );

    await _remindersBox.put(reminder.id, reminder);
    return reminder;
  }
}
