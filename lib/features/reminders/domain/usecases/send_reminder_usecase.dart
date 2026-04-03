import '../entities/reminder.dart';
import '../entities/reminder_message_type.dart';
import '../repositories/reminder_repository.dart';

class SendReminderUseCase {
  const SendReminderUseCase(this._repository);

  final ReminderRepository _repository;

  Future<Reminder> call({
    required String invoiceId,
    required String clientId,
    required ReminderChannel channel,
    required ReminderMessageType messageType,
    required String message,
  }) {
    return _repository.sendReminder(
      invoiceId: invoiceId,
      clientId: clientId,
      channel: channel,
      messageType: messageType,
      message: message,
    );
  }
}
