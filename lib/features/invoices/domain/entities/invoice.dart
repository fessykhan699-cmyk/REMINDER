import 'line_item.dart';
import '../../../../domain/entities/payment.dart';

enum InvoiceStatus { draft, sent, viewed, partiallyPaid, paid, overdue }

enum RecurringInterval { none, weekly, biweekly, monthly, quarterly }

extension RecurringIntervalX on RecurringInterval {
  String get label {
    switch (this) {
      case RecurringInterval.none:
        return 'None';
      case RecurringInterval.weekly:
        return 'Weekly';
      case RecurringInterval.biweekly:
        return 'Bi-weekly';
      case RecurringInterval.monthly:
        return 'Monthly';
      case RecurringInterval.quarterly:
        return 'Quarterly';
    }
  }

  DateTime calculateNextDate(DateTime from) {
    switch (this) {
      case RecurringInterval.weekly:
        return from.add(const Duration(days: 7));
      case RecurringInterval.biweekly:
        return from.add(const Duration(days: 14));
      case RecurringInterval.monthly:
        var nextMonth = from.month + 1;
        var year = from.year;
        if (nextMonth > 12) {
          nextMonth = 1;
          year++;
        }
        var lastDayOfNextMonth = DateTime(year, nextMonth + 1, 0).day;
        var day = from.day > lastDayOfNextMonth ? lastDayOfNextMonth : from.day;
        return DateTime(year, nextMonth, day);
      case RecurringInterval.quarterly:
        var nextMonth = from.month + 3;
        var year = from.year;
        if (nextMonth > 12) {
          nextMonth = nextMonth - 12;
          year++;
        }
        var lastDayOfNextMonth = DateTime(year, nextMonth + 1, 0).day;
        var day = from.day > lastDayOfNextMonth ? lastDayOfNextMonth : from.day;
        return DateTime(year, nextMonth, day);
      case RecurringInterval.none:
        return from;
    }
  }
}

extension InvoiceStatusX on InvoiceStatus {
  String get label {
    switch (this) {
      case InvoiceStatus.draft:
      case InvoiceStatus.sent:
      case InvoiceStatus.viewed:
        return 'Pending';
      case InvoiceStatus.paid:
        return 'Paid';
      case InvoiceStatus.partiallyPaid:
        return 'Partially Paid';
      case InvoiceStatus.overdue:
        return 'Overdue';
    }
  }

  bool get isPaid => this == InvoiceStatus.paid;
  bool get isShareable => !isPaid;
}

class Invoice {
  const Invoice({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.amount,
    required this.dueDate,
    required this.createdAt,
    this.status = InvoiceStatus.draft,
    this.service = '',
    this.currencyCode = 'USD',
    this.notes,
    this.paymentLink,
    this.taxPercent = 0.0,
    this.discountAmount = 0.0,
    this.invoiceNumber = '',
    this.paymentTermsDays = 0,
    this.items = const [],
    this.isRecurring = false,
    this.recurringInterval = RecurringInterval.none,
    this.recurringNextDate,
    this.recurringParentId,
    this.payments = const [],
  });

  final String id;
  final String clientId;
  final String clientName;
  final double amount; // Total amount (after tax and discount)
  final DateTime dueDate;
  final DateTime createdAt;
  final InvoiceStatus status;
  final String service;
  final String currencyCode;
  final String? notes;
  final String? paymentLink;
  final double taxPercent;
  final double discountAmount;
  final String invoiceNumber;
  final int paymentTermsDays;
  final List<LineItem> items;
  final bool isRecurring;
  final RecurringInterval recurringInterval;
  final DateTime? recurringNextDate;
  final String? recurringParentId;
  final List<Payment> payments;

  bool get isPaid => status == InvoiceStatus.paid;
  bool get isOverdue =>
      status != InvoiceStatus.paid && dueDate.isBefore(DateTime.now());

  double get totalPaid => payments.fold(0.0, (sum, p) => sum + p.amount);

  bool get isFullyPaid => totalPaid >= (amount - 0.01);

  bool get isPartiallyPaid => totalPaid > 0.01 && !isFullyPaid;

  double get remainingBalance {
    final balance = amount - totalPaid;
    return balance < 0 ? 0.0 : balance;
  }


  String? get normalizedNotes => notes?.trim().isEmpty == true ? null : notes;
  String? get normalizedPaymentLink =>
      paymentLink?.trim().isEmpty == true ? null : paymentLink;

  bool get hasNotes => normalizedNotes != null;
  bool get hasPaymentLink => normalizedPaymentLink != null;

  // New calculation logic
  double get calculatedSubtotal {
    if (items.isEmpty) {
      // Backward compatibility: infer subtotal from total amount
      // amount = subtotal + subtotal * (taxPercent / 100) - discountAmount
      // amount + discountAmount = subtotal * (1 + (taxPercent / 100))
      return (amount + discountAmount) / (1 + (taxPercent / 100));
    }
    return items.fold(0, (sum, item) => sum + item.amount);
  }

  double get subtotalAmount => calculatedSubtotal;

  double get taxAmount => subtotalAmount * (taxPercent / 100);

  double get appliedDiscountAmount => discountAmount;

  double get calculatedTotal => subtotalAmount + taxAmount - discountAmount;

  Invoice copyWith({
    String? id,
    String? clientId,
    String? clientName,
    double? amount,
    DateTime? dueDate,
    DateTime? createdAt,
    InvoiceStatus? status,
    String? service,
    String? currencyCode,
    String? notes,
    String? paymentLink,
    double? taxPercent,
    double? discountAmount,
    String? invoiceNumber,
    int? paymentTermsDays,
    List<LineItem>? items,
    bool? isRecurring,
    RecurringInterval? recurringInterval,
    DateTime? recurringNextDate,
    String? recurringParentId,
    List<Payment>? payments,
  }) {
    return Invoice(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      service: service ?? this.service,
      currencyCode: currencyCode ?? this.currencyCode,
      notes: notes ?? this.notes,
      paymentLink: paymentLink ?? this.paymentLink,
      taxPercent: taxPercent ?? this.taxPercent,
      discountAmount: discountAmount ?? this.discountAmount,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      paymentTermsDays: paymentTermsDays ?? this.paymentTermsDays,
      items: items ?? this.items,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringInterval: recurringInterval ?? this.recurringInterval,
      recurringNextDate: recurringNextDate ?? this.recurringNextDate,
      recurringParentId: recurringParentId ?? this.recurringParentId,
      payments: payments ?? this.payments,
    );
  }

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'] as String,
      clientId: json['clientId'] as String,
      clientName: json['clientName'] as String,
      amount: (json['amount'] as num).toDouble(),
      dueDate: DateTime.parse(json['dueDate'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: InvoiceStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => InvoiceStatus.draft,
      ),
      service: json['service'] as String? ?? '',
      currencyCode: json['currencyCode'] as String? ?? 'USD',
      notes: json['notes'] as String?,
      paymentLink: json['paymentLink'] as String?,
      taxPercent: (json['taxPercent'] as num? ?? 0.0).toDouble(),
      discountAmount: (json['discountAmount'] as num? ?? 0.0).toDouble(),
      invoiceNumber: json['invoiceNumber'] as String? ?? '',
      paymentTermsDays: (json['paymentTermsDays'] as num? ?? 0).toInt(),
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => LineItem.fromJson(e as Map<String, dynamic>))
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
      payments: (json['payments'] as List<dynamic>?)
              ?.map((e) => Payment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clientId': clientId,
      'clientName': clientName,
      'amount': amount,
      'dueDate': dueDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'status': status.name,
      'service': service,
      'currencyCode': currencyCode,
      'notes': notes,
      'paymentLink': paymentLink,
      'taxPercent': taxPercent,
      'discountAmount': discountAmount,
      'invoiceNumber': invoiceNumber,
      'paymentTermsDays': paymentTermsDays,
      'items': items.map((e) => e.toJson()).toList(),
      'isRecurring': isRecurring,
      'recurringInterval': recurringInterval.name,
      'recurringNextDate': recurringNextDate?.toIso8601String(),
      'recurringParentId': recurringParentId,
      'payments': payments.map((e) => e.toJson()).toList(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Invoice &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          clientId == other.clientId &&
          clientName == other.clientName &&
          amount == other.amount &&
          dueDate == other.dueDate &&
          createdAt == other.createdAt &&
          status == other.status &&
          service == other.service &&
          currencyCode == other.currencyCode &&
          notes == other.notes &&
          paymentLink == other.paymentLink &&
          taxPercent == other.taxPercent &&
          discountAmount == other.discountAmount &&
          invoiceNumber == other.invoiceNumber &&
          paymentTermsDays == other.paymentTermsDays &&
          _listEquals(items, other.items) &&
          isRecurring == other.isRecurring &&
          recurringInterval == other.recurringInterval &&
          recurringNextDate == other.recurringNextDate &&
          recurringParentId == other.recurringParentId &&
          _listEquals(payments, other.payments);

  @override
  int get hashCode =>
      id.hashCode ^
      clientId.hashCode ^
      clientName.hashCode ^
      amount.hashCode ^
      dueDate.hashCode ^
      createdAt.hashCode ^
      status.hashCode ^
      service.hashCode ^
      currencyCode.hashCode ^
      notes.hashCode ^
      paymentLink.hashCode ^
      taxPercent.hashCode ^
      discountAmount.hashCode ^
      invoiceNumber.hashCode ^
      paymentTermsDays.hashCode ^
      items.hashCode ^
      isRecurring.hashCode ^
      recurringInterval.hashCode ^
      recurringNextDate.hashCode ^
      recurringParentId.hashCode ^
      payments.hashCode;

  bool _listEquals(List a, List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
