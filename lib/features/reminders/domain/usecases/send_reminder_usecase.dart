import '../entities/reminder.dart';
import '../repositories/reminder_repository.dart';

class SendReminderUseCase {
  const SendReminderUseCase(this._repository);

  final ReminderRepository _repository;

  Future<Reminder> call({
    required String invoiceId,
    required String clientId,
    required String phoneNumber,
    required ReminderChannel channel,
    required String message,
  }) {
    return _repository.sendReminder(
      invoiceId: invoiceId,
      clientId: clientId,
      phoneNumber: phoneNumber,
      channel: channel,
      message: message,
    );
  }
}
