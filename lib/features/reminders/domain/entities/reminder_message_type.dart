enum ReminderMessageType { professional, friendly, firm }

extension ReminderMessageTypeX on ReminderMessageType {
  String get label {
    switch (this) {
      case ReminderMessageType.professional:
        return 'Professional';
      case ReminderMessageType.friendly:
        return 'Friendly';
      case ReminderMessageType.firm:
        return 'Firm';
    }
  }
}
