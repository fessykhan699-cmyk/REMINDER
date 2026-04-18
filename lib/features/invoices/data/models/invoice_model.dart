// ignore_for_file: overridden_fields

import 'package:hive/hive.dart';

import '../../domain/entities/invoice.dart';
import 'line_item_model.dart';
import '../../domain/entities/line_item.dart';
import '../../../../domain/entities/payment.dart';
import '../../../../data/models/payment_model.dart';

const Object _invoiceModelPaymentLinkSentinel = Object();
const Object _invoiceModelNotesSentinel = Object();

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
      case 5:
        return InvoiceStatus.partiallyPaid;
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
      InvoiceStatus.partiallyPaid => 5,
    });
  }
}

class RecurringIntervalAdapter extends TypeAdapter<RecurringInterval> {
  @override
  final int typeId = 9; // Changed from 5 to avoid collision with ReminderModelAdapter

  @override
  RecurringInterval read(BinaryReader reader) {
    final rawValue = reader.readByte();
    switch (rawValue) {
      case 0:
        return RecurringInterval.none;
      case 1:
        return RecurringInterval.weekly;
      case 2:
        return RecurringInterval.biweekly;
      case 3:
        return RecurringInterval.monthly;
      case 4:
        return RecurringInterval.quarterly;
      default:
        return RecurringInterval.none;
    }
  }

  @override
  void write(BinaryWriter writer, RecurringInterval obj) {
    writer.writeByte(switch (obj) {
      RecurringInterval.none => 0,
      RecurringInterval.weekly => 1,
      RecurringInterval.biweekly => 2,
      RecurringInterval.monthly => 3,
      RecurringInterval.quarterly => 4,
    });
  }
}

@HiveType(typeId: 2)
class InvoiceModel extends Invoice {
  const InvoiceModel({
    required this.id,
    required this.invoiceNumber,
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
    required this.discountAmount,
    this.paymentLink,
    this.notes,
    this.items = const [],
    this.isRecurring = false,
    this.recurringInterval = RecurringInterval.none,
    this.recurringNextDate,
    this.recurringParentId,
    this.payments = const [],
  }) : super(
          id: id,
          invoiceNumber: invoiceNumber,
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
          discountAmount: discountAmount,
          paymentLink: paymentLink,
          notes: notes,
          items: items,
          isRecurring: isRecurring,
          recurringInterval: recurringInterval,
          recurringNextDate: recurringNextDate,
          recurringParentId: recurringParentId,
          payments: payments,
        );

  @override
  @HiveField(0)
  final String id;

  @override
  @HiveField(14)
  final String invoiceNumber;

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

  @override
  @HiveField(12)
  final double discountAmount;

  @override
  @HiveField(13)
  final String? notes;

  @override
  @HiveField(15)
  final List<LineItemModel> items;

  @override
  @HiveField(16)
  final bool isRecurring;

  @override
  @HiveField(17)
  final RecurringInterval recurringInterval;

  @override
  @HiveField(18)
  final DateTime? recurringNextDate;

  @override
  @HiveField(19)
  final String? recurringParentId;

  @override
  @HiveField(20)
  final List<PaymentModel> payments;

  factory InvoiceModel.fromEntity(Invoice invoice) {
    return InvoiceModel(
      id: invoice.id,
      invoiceNumber: invoice.invoiceNumber,
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
      discountAmount: invoice.discountAmount,
      paymentLink: invoice.paymentLink,
      notes: invoice.notes,
      items: invoice.items.map((e) => LineItemModel.fromEntity(e)).toList(),
      isRecurring: invoice.isRecurring,
      recurringInterval: invoice.recurringInterval,
      recurringNextDate: invoice.recurringNextDate,
      recurringParentId: invoice.recurringParentId,
      payments: invoice.payments.map((e) => PaymentModel.fromEntity(e)).toList(),
    );
  }

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    return InvoiceModel(
      id: json['id'] as String,
      invoiceNumber: json['invoiceNumber'] as String? ?? '',
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
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0,
      paymentLink: json['paymentLink'] as String?,
      notes: json['notes'] as String?,
      items: (json['items'] as List?)
              ?.map((e) => LineItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      isRecurring: json['isRecurring'] as bool? ?? false,
      recurringInterval: RecurringInterval.values.firstWhere(
        (e) => e.name == json['recurringInterval'],
        orElse: () => RecurringInterval.none,
      ),
      recurringNextDate: json['recurringNextDate'] != null
          ? DateTime.parse(json['recurringNextDate'] as String)
          : null,
      recurringParentId: json['recurringParentId'] as String?,
      payments: (json['payments'] as List?)
              ?.map((e) => PaymentModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoiceNumber': invoiceNumber,
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
      'discountAmount': discountAmount,
      'paymentLink': paymentLink,
      'notes': notes,
      'items': items.map((e) => e.toJson()).toList(),
      'isRecurring': isRecurring,
      'recurringInterval': recurringInterval.name,
      'recurringNextDate': recurringNextDate?.toIso8601String(),
      'recurringParentId': recurringParentId,
      'payments': payments.map((e) => e.toJson()).toList(),
    };
  }

  @override
  InvoiceModel copyWith({
    String? id,
    String? invoiceNumber,
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
    double? discountAmount,
    Object? paymentLink = _invoiceModelPaymentLinkSentinel,
    Object? notes = _invoiceModelNotesSentinel,
    List<LineItem>? items,
    bool? isRecurring,
    RecurringInterval? recurringInterval,
    DateTime? recurringNextDate,
    String? recurringParentId,
    List<Payment>? payments,
  }) {
    return InvoiceModel(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
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
      discountAmount: discountAmount ?? this.discountAmount,
      paymentLink: identical(paymentLink, _invoiceModelPaymentLinkSentinel)
          ? this.paymentLink
          : paymentLink as String?,
      notes: identical(notes, _invoiceModelNotesSentinel)
          ? this.notes
          : notes as String?,
      items: items != null
          ? items.map((e) => LineItemModel.fromEntity(e)).toList()
          : this.items,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringInterval: recurringInterval ?? this.recurringInterval,
      recurringNextDate: recurringNextDate ?? this.recurringNextDate,
      recurringParentId: recurringParentId ?? this.recurringParentId,
      payments: payments != null
          ? payments.map((e) => PaymentModel.fromEntity(e)).toList()
          : this.payments,
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
      case 'partiallyPaid':
        return InvoiceStatus.partiallyPaid;
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
    final currencyCode = reader.availableBytes > 0 ? reader.readString() : 'USD';
    final taxPercent = reader.availableBytes > 0 ? reader.readDouble() : 0.0;
    final paymentTermsDays = reader.availableBytes > 0 ? reader.readInt() : 0;
    final paymentLink = reader.availableBytes > 0 ? reader.readString() : '';
    final discountAmount = reader.availableBytes > 0 ? reader.readDouble() : 0.0;
    final notes = reader.availableBytes > 0 ? reader.readString() : '';
    final invoiceNumber = reader.availableBytes > 0 ? reader.readString() : '';

    List<LineItemModel> items = [];
    if (reader.availableBytes > 0) {
      final itemsRaw = reader.readList();
      items = itemsRaw.cast<LineItemModel>();
    }

    final isRecurring = reader.availableBytes > 0 ? reader.readBool() : false;
    final recurringInterval = reader.availableBytes > 0
        ? reader.read() as RecurringInterval
        : RecurringInterval.none;
    final recurringNextDateStr =
        reader.availableBytes > 0 ? reader.readString() : '';
    final recurringNextDate = recurringNextDateStr.isEmpty
        ? null
        : DateTime.parse(recurringNextDateStr);
    final recurringParentId =
        reader.availableBytes > 0 ? reader.readString() : '';

    List<PaymentModel> payments = [];
    if (reader.availableBytes > 0) {
      final paymentsRaw = reader.readList();
      payments = paymentsRaw.cast<PaymentModel>();
    }

    return InvoiceModel(
      id: id,
      invoiceNumber: invoiceNumber,
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
      discountAmount: discountAmount,
      paymentLink: paymentLink.isEmpty ? null : paymentLink,
      notes: notes.isEmpty ? null : notes,
      items: items,
      isRecurring: isRecurring,
      recurringInterval: recurringInterval,
      recurringNextDate: recurringNextDate,
      recurringParentId: recurringParentId.isEmpty ? null : recurringParentId,
      payments: payments,
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
      ..writeString(obj.paymentLink ?? '')
      ..writeDouble(obj.discountAmount)
      ..writeString(obj.notes ?? '')
      ..writeString(obj.invoiceNumber)
      ..writeList(obj.items)
      ..writeBool(obj.isRecurring)
      ..write(obj.recurringInterval)
      ..writeString(obj.recurringNextDate?.toIso8601String() ?? '')
      ..writeString(obj.recurringParentId ?? '')
      ..writeList(obj.payments);
  }
}
