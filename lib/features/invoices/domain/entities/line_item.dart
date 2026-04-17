class LineItem {
  const LineItem({
    required this.id,
    required this.description,
    required this.quantity,
    required this.unitPrice,
  });

  final String id;
  final String description;
  final double quantity;
  final double unitPrice;

  double get amount => quantity * unitPrice;

  LineItem copyWith({
    String? id,
    String? description,
    double? quantity,
    double? unitPrice,
  }) {
    return LineItem(
      id: id ?? this.id,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
    );
  }
}
