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
    required this.currencyCode,
    required this.taxPercent,
    required this.paymentTermsDays,
  }) : super(
         id: id,
         clientId: clientId,
         clientName: clientName,
         service: service,
         amount: amount,
         dueDate: dueDate,
         status: status,
         createdAt: createdAt,
         currencyCode: currencyCode,
         taxPercent: taxPercent,
         paymentTermsDays: paymentTermsDays,
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

  @override
  @HiveField(8)
  final String currencyCode;

  @override
  @HiveField(9)
  final double taxPercent;

  @override
  @HiveField(10)
  final int paymentTermsDays;

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
      currencyCode: invoice.currencyCode,
      taxPercent: invoice.taxPercent,
      paymentTermsDays: invoice.paymentTermsDays,
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
      currencyCode: json['currencyCode'] as String? ?? 'USD',
      taxPercent: (json['taxPercent'] as num?)?.toDouble() ?? 0,
      paymentTermsDays: (json['paymentTermsDays'] as num?)?.toInt() ?? 0,
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
      'currencyCode': currencyCode,
      'taxPercent': taxPercent,
      'paymentTermsDays': paymentTermsDays,
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
    String? currencyCode,
    double? taxPercent,
    int? paymentTermsDays,
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
      currencyCode: currencyCode ?? this.currencyCode,
      taxPercent: taxPercent ?? this.taxPercent,
      paymentTermsDays: paymentTermsDays ?? this.paymentTermsDays,
    );
  }
}

class InvoiceModelAdapter extends TypeAdapter<InvoiceModel> {
  @override
  final int typeId = 2;

  @override
  InvoiceModel read(BinaryReader reader) {
    final id = reader.readString();
    final clientId = reader.readString();
    final clientName = reader.readString();
    final service = reader.readString();
    final amount = reader.readDouble();
    final dueDate = DateTime.parse(reader.readString());
    final status = reader.read() as InvoiceStatus;
    final createdAt = DateTime.parse(reader.readString());
    final currencyCode = reader.availableBytes > 0
        ? reader.readString()
        : 'USD';
    final taxPercent = reader.availableBytes > 0 ? reader.readDouble() : 0.0;
    final paymentTermsDays = reader.availableBytes > 0 ? reader.readInt() : 0;

    return InvoiceModel(
      id: id,
      clientId: clientId,
      clientName: clientName,
      service: service,
      amount: amount,
      dueDate: dueDate,
      status: status,
      createdAt: createdAt,
      currencyCode: currencyCode,
      taxPercent: taxPercent,
      paymentTermsDays: paymentTermsDays,
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
      ..writeString(obj.createdAt.toIso8601String())
      ..writeString(obj.currencyCode)
      ..writeDouble(obj.taxPercent)
      ..writeInt(obj.paymentTermsDays);
  }
}
