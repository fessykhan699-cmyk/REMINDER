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

  factory LineItem.fromJson(Map<String, dynamic> json) {
    return LineItem(
      id: json['id'] as String,
      description: json['description'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unitPrice: (json['unitPrice'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'quantity': quantity,
      'unitPrice': unitPrice,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LineItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          description == other.description &&
          quantity == other.quantity &&
          unitPrice == other.unitPrice;

  @override
  int get hashCode =>
      id.hashCode ^
      description.hashCode ^
      quantity.hashCode ^
      unitPrice.hashCode;
}
