import 'line_item.dart';

enum InvoiceStatus { draft, sent, viewed, paid, overdue }

extension InvoiceStatusX on InvoiceStatus {
  String get label {
    switch (this) {
      case InvoiceStatus.draft:
        return 'Draft';
      case InvoiceStatus.sent:
        return 'Sent';
      case InvoiceStatus.viewed:
        return 'Viewed';
      case InvoiceStatus.paid:
        return 'Paid';
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

  bool get isPaid => status == InvoiceStatus.paid;
  bool get isOverdue =>
      status != InvoiceStatus.paid && dueDate.isBefore(DateTime.now());

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
    );
  }
}
