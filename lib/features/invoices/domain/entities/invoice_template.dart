import 'line_item.dart';

class InvoiceTemplate {
  final String id;
  final String name;
  final String service;
  final double amount;
  final List<LineItem> items;
  final String? notes;
  final String? paymentLink;

  const InvoiceTemplate({
    required this.id,
    required this.name,
    required this.service,
    required this.amount,
    this.items = const [],
    this.notes,
    this.paymentLink,
  });

  InvoiceTemplate copyWith({
    String? id,
    String? name,
    String? service,
    double? amount,
    List<LineItem>? items,
    String? notes,
    String? paymentLink,
  }) {
    return InvoiceTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      service: service ?? this.service,
      amount: amount ?? this.amount,
      items: items ?? this.items,
      notes: notes ?? this.notes,
      paymentLink: paymentLink ?? this.paymentLink,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InvoiceTemplate &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          service == other.service &&
          amount == other.amount &&
          items == other.items &&
          notes == other.notes &&
          paymentLink == other.paymentLink;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      service.hashCode ^
      amount.hashCode ^
      items.hashCode ^
      notes.hashCode ^
      paymentLink.hashCode;
}
