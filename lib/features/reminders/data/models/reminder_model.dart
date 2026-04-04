// ignore_for_file: overridden_fields

import 'package:hive/hive.dart';

import '../../domain/entities/reminder.dart';

class ReminderChannelAdapter extends TypeAdapter<ReminderChannel> {
  @override
  final int typeId = 3;

  @override
  ReminderChannel read(BinaryReader reader) {
    return ReminderChannel.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, ReminderChannel obj) {
    writer.writeByte(obj.index);
  }
}

class ReminderStatusAdapter extends TypeAdapter<ReminderStatus> {
  @override
  final int typeId = 4;

  @override
  ReminderStatus read(BinaryReader reader) {
    return ReminderStatus.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, ReminderStatus obj) {
    writer.writeByte(obj.index);
  }
}

@HiveType(typeId: 5)
class ReminderModel extends Reminder {
  const ReminderModel({
    required this.id,
    required this.invoiceId,
    required this.clientId,
    required this.sentAt,
    required this.channel,
    required this.status,
  }) : super(
         id: id,
         invoiceId: invoiceId,
         clientId: clientId,
         sentAt: sentAt,
         channel: channel,
         status: status,
       );

  @override
  @HiveField(0)
  final String id;

  @override
  @HiveField(1)
  final String invoiceId;

  @override
  @HiveField(2)
  final String clientId;

  @override
  @HiveField(3)
  final DateTime sentAt;

  @override
  @HiveField(4)
  final ReminderChannel channel;

  @override
  @HiveField(5)
  final ReminderStatus status;

  factory ReminderModel.fromEntity(Reminder reminder) {
    return ReminderModel(
      id: reminder.id,
      invoiceId: reminder.invoiceId,
      clientId: reminder.clientId,
      sentAt: reminder.sentAt,
      channel: reminder.channel,
      status: reminder.status,
    );
  }

  factory ReminderModel.fromJson(Map<String, dynamic> json) {
    return ReminderModel(
      id: json['id'] as String,
      invoiceId: json['invoiceId'] as String,
      clientId: json['clientId'] as String,
      sentAt: DateTime.parse(json['sentAt'] as String),
      channel: ReminderChannel.values.firstWhere(
        (value) => value.name == json['channel'],
        orElse: () => ReminderChannel.whatsapp,
      ),
      status: ReminderStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => ReminderStatus.queued,
      ),
    );
  }

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

class ReminderModelAdapter extends TypeAdapter<ReminderModel> {
  @override
  final int typeId = 5;

  @override
  ReminderModel read(BinaryReader reader) {
    return ReminderModel(
      id: reader.readString(),
      invoiceId: reader.readString(),
      clientId: reader.readString(),
      sentAt: DateTime.parse(reader.readString()),
      channel: reader.read() as ReminderChannel,
      status: reader.read() as ReminderStatus,
    );
  }

  @override
  void write(BinaryWriter writer, ReminderModel obj) {
    writer
      ..writeString(obj.id)
      ..writeString(obj.invoiceId)
      ..writeString(obj.clientId)
      ..writeString(obj.sentAt.toIso8601String())
      ..write(obj.channel)
      ..write(obj.status);
  }
}

