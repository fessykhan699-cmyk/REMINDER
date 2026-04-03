enum ReminderChannel { whatsapp, sms }

extension ReminderChannelX on ReminderChannel {
  String get label {
    switch (this) {
      case ReminderChannel.whatsapp:
        return 'WhatsApp';
      case ReminderChannel.sms:
        return 'SMS';
    }
  }
}

enum ReminderStatus { queued, sent, failed }

class Reminder {
  const Reminder({
    required this.id,
    required this.invoiceId,
    required this.clientId,
    required this.sentAt,
    required this.channel,
    required this.status,
  });

  final String id;
  final String invoiceId;
  final String clientId;
  final DateTime sentAt;
  final ReminderChannel channel;
  final ReminderStatus status;
}
