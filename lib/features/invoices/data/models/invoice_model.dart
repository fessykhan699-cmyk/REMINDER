// ignore_for_file: overridden_fields

import 'package:hive/hive.dart';

import '../../domain/entities/invoice.dart';

class InvoiceStatusAdapter extends TypeAdapter<InvoiceStatus> {
  @override
  final int typeId = 1;

  @override
  InvoiceStatus read(BinaryReader reader) {
    return InvoiceStatus.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, InvoiceStatus obj) {
    writer.writeByte(obj.index);
  }
}

@HiveType(typeId: 2)
class InvoiceModel extends Invoice {
  const InvoiceModel({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.service,
    required this.amount,
    required this.dueDate,
    required this.status,
    required this.createdAt,
  }) : super(
         id: id,
         clientId: clientId,
         clientName: clientName,
         service: service,
         amount: amount,
         dueDate: dueDate,
         status: status,
         createdAt: createdAt,
       );

  @override
  @HiveField(0)
  final String id;

  @override
  @HiveField(1)
  final String clientId;

  @override
  @HiveField(2)
  final String clientName;

  @override
  @HiveField(3)
  final String service;

  @override
  @HiveField(4)
  final double amount;

  @override
  @HiveField(5)
  final DateTime dueDate;

  @override
  @HiveField(6)
  final InvoiceStatus status;

  @override
  @HiveField(7)
  final DateTime createdAt;

  factory InvoiceModel.fromEntity(Invoice invoice) {
    return InvoiceModel(
      id: invoice.id,
      clientId: invoice.clientId,
      clientName: invoice.clientName,
      service: invoice.service,
      amount: invoice.amount,
      dueDate: invoice.dueDate,
      status: invoice.status,
      createdAt: invoice.createdAt,
    );
  }

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    return InvoiceModel(
      id: json['id'] as String,
      clientId: json['clientId'] as String,
      clientName: json['clientName'] as String,
      service: json['service'] as String,
      amount: (json['amount'] as num).toDouble(),
      dueDate: DateTime.parse(json['dueDate'] as String),
      status: InvoiceStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => InvoiceStatus.pending,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clientId': clientId,
      'clientName': clientName,
      'service': service,
      'amount': amount,
      'dueDate': dueDate.toIso8601String(),
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  InvoiceModel copyWith({
    String? id,
    String? clientId,
    String? clientName,
    String? service,
    double? amount,
    DateTime? dueDate,
    InvoiceStatus? status,
    DateTime? createdAt,
  }) {
    return InvoiceModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      service: service ?? this.service,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class InvoiceModelAdapter extends TypeAdapter<InvoiceModel> {
  @override
  final int typeId = 2;

  @override
  InvoiceModel read(BinaryReader reader) {
    return InvoiceModel(
      id: reader.readString(),
      clientId: reader.readString(),
      clientName: reader.readString(),
      service: reader.readString(),
      amount: reader.readDouble(),
      dueDate: DateTime.parse(reader.readString()),
      status: reader.read() as InvoiceStatus,
      createdAt: DateTime.parse(reader.readString()),
    );
  }

  @override
  void write(BinaryWriter writer, InvoiceModel obj) {
    writer
      ..writeString(obj.id)
      ..writeString(obj.clientId)
      ..writeString(obj.clientName)
      ..writeString(obj.service)
      ..writeDouble(obj.amount)
      ..writeString(obj.dueDate.toIso8601String())
      ..write(obj.status)
      ..writeString(obj.createdAt.toIso8601String());
  }
}

