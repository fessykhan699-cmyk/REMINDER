import '../../domain/entities/reminder.dart';

class ReminderModel extends Reminder {
  const ReminderModel({
    required super.id,
    required super.invoiceId,
    required super.clientId,
    required super.sentAt,
    required super.channel,
    required super.status,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoiceId': invoiceId,
      'clientId': clientId,
      'sentAt': sentAt.toIso8601String(),
      'channel': channel.name,
      'status': status.name,
    };
  }
}
