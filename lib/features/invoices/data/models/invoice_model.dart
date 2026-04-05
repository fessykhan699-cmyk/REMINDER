// ignore_for_file: overridden_fields

import 'package:hive/hive.dart';

import '../../domain/entities/invoice.dart';

const Object _invoiceModelPaymentLinkSentinel = Object();

class InvoiceStatusAdapter extends TypeAdapter<InvoiceStatus> {
  @override
  final int typeId = 1;

  @override
  InvoiceStatus read(BinaryReader reader) {
    final rawValue = reader.readByte();
    switch (rawValue) {
      case 0:
        return InvoiceStatus.draft;
      case 1:
        return InvoiceStatus.paid;
      case 2:
        return InvoiceStatus.overdue;
      case 3:
        return InvoiceStatus.sent;
      case 4:
        return InvoiceStatus.viewed;
      default:
        return InvoiceStatus.draft;
    }
  }

  @override
  void write(BinaryWriter writer, InvoiceStatus obj) {
    writer.writeByte(switch (obj) {
      InvoiceStatus.draft => 0,
      InvoiceStatus.paid => 1,
      InvoiceStatus.overdue => 2,
      InvoiceStatus.sent => 3,
      InvoiceStatus.viewed => 4,
    });
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
    this.paymentLink,
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
         paymentLink: paymentLink,
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

  @override
  @HiveField(11)
  final String? paymentLink;

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
      paymentLink: invoice.paymentLink,
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
      status: _statusFromJson(json['status'] as String?),
      createdAt: DateTime.parse(json['createdAt'] as String),
      currencyCode: json['currencyCode'] as String? ?? 'USD',
      taxPercent: (json['taxPercent'] as num?)?.toDouble() ?? 0,
      paymentTermsDays: (json['paymentTermsDays'] as num?)?.toInt() ?? 0,
      paymentLink: json['paymentLink'] as String?,
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
      'paymentLink': paymentLink,
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
    Object? paymentLink = _invoiceModelPaymentLinkSentinel,
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
      paymentLink: identical(paymentLink, _invoiceModelPaymentLinkSentinel)
          ? this.paymentLink
          : paymentLink as String?,
    );
  }

  static InvoiceStatus _statusFromJson(String? rawStatus) {
    switch (rawStatus) {
      case 'draft':
      case 'pending':
        return InvoiceStatus.draft;
      case 'sent':
        return InvoiceStatus.sent;
      case 'viewed':
        return InvoiceStatus.viewed;
      case 'paid':
        return InvoiceStatus.paid;
      case 'overdue':
        return InvoiceStatus.overdue;
      default:
        return InvoiceStatus.draft;
    }
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
    final paymentLink = reader.availableBytes > 0 ? reader.readString() : '';

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
      paymentLink: paymentLink.isEmpty ? null : paymentLink,
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
      ..writeInt(obj.paymentTermsDays)
      ..writeString(obj.paymentLink ?? '');
  }
}
