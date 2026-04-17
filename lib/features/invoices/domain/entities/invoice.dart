const Object _paymentLinkSentinel = Object();
const Object _notesSentinel = Object();

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
    required this.invoiceNumber,
    required this.clientId,
    required this.clientName,
    required this.service,
    required this.amount,
    required this.dueDate,
    required this.status,
    required this.createdAt,
    this.currencyCode = 'USD',
    this.taxPercent = 0,
    this.paymentTermsDays = 0,
    this.discountAmount = 0,
    this.paymentLink,
    this.notes,
  });

  final String id;
  final String invoiceNumber;
  final String clientId;
  final String clientName;
  final String service;
  final double amount;
  final DateTime dueDate;
  final InvoiceStatus status;
  final DateTime createdAt;
  final String currencyCode;
  final double taxPercent;
  final int paymentTermsDays;
  final double discountAmount;
  final String? paymentLink;
  final String? notes;

  bool get hasPaymentLink {
    final trimmed = paymentLink?.trim() ?? '';
    return trimmed.isNotEmpty;
  }

  String? get normalizedPaymentLink {
    final trimmed = paymentLink?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  String? get normalizedNotes {
    final trimmed = notes?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  bool get hasNotes => normalizedNotes != null;

  double get appliedDiscountAmount {
    final normalizedDiscount = discountAmount < 0 ? 0 : discountAmount;
    final taxableSubtotal = taxableSubtotalAmount;
    return normalizedDiscount > taxableSubtotal
        ? taxableSubtotal
        : normalizedDiscount.toDouble();
  }

  double get taxableSubtotalAmount {
    if (taxPercent <= 0) {
      return amount;
    }

    return amount / (1 + (taxPercent / 100));
  }

  double get subtotalAmount {
    return taxableSubtotalAmount + appliedDiscountAmount;
  }

  double get taxAmount => amount - taxableSubtotalAmount;

  Invoice copyWith({
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
    Object? paymentLink = _paymentLinkSentinel,
    Object? notes = _notesSentinel,
  }) {
    return Invoice(
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
      paymentLink: identical(paymentLink, _paymentLinkSentinel)
          ? this.paymentLink
          : paymentLink as String?,
      notes: identical(notes, _notesSentinel) ? this.notes : notes as String?,
    );
  }
}
