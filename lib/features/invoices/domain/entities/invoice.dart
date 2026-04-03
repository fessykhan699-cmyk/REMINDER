enum InvoiceStatus { pending, paid, overdue }

extension InvoiceStatusX on InvoiceStatus {
  String get label {
    switch (this) {
      case InvoiceStatus.pending:
        return 'Pending';
      case InvoiceStatus.paid:
        return 'Paid';
      case InvoiceStatus.overdue:
        return 'Overdue';
    }
  }
}

class Invoice {
  const Invoice({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.service,
    required this.amount,
    required this.dueDate,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String clientId;
  final String clientName;
  final String service;
  final double amount;
  final DateTime dueDate;
  final InvoiceStatus status;
  final DateTime createdAt;

  Invoice copyWith({
    String? id,
    String? clientId,
    String? clientName,
    String? service,
    double? amount,
    DateTime? dueDate,
    InvoiceStatus? status,
    DateTime? createdAt,
  }) {
    return Invoice(
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
