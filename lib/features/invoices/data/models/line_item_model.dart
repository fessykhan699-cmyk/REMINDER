// ignore_for_file: overridden_fields

import 'package:hive/hive.dart';
import '../../domain/entities/line_item.dart';

@HiveType(typeId: 11)
class LineItemModel extends LineItem {
  const LineItemModel({
    required this.id,
    required this.description,
    required this.quantity,
    required this.unitPrice,
  }) : super(
          id: id,
          description: description,
          quantity: quantity,
          unitPrice: unitPrice,
        );

  @override
  @HiveField(0)
  final String id;

  @override
  @HiveField(1)
  final String description;

  @override
  @HiveField(2)
  final double quantity;

  @override
  @HiveField(3)
  final double unitPrice;

  factory LineItemModel.fromEntity(LineItem item) {
    return LineItemModel(
      id: item.id,
      description: item.description,
      quantity: item.quantity,
      unitPrice: item.unitPrice,
    );
  }

  factory LineItemModel.fromJson(Map<String, dynamic> json) {
    return LineItemModel(
      id: json['id'] as String,
      description: json['description'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unitPrice: (json['unitPrice'] as num).toDouble(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'quantity': quantity,
      'unitPrice': unitPrice,
    };
  }
}

class LineItemModelAdapter extends TypeAdapter<LineItemModel> {
  @override
  final int typeId = 11;

  @override
  LineItemModel read(BinaryReader reader) {
    final id = reader.readString();
    final description = reader.readString();
    final quantity = reader.readDouble();
    final unitPrice = reader.readDouble();

    return LineItemModel(
      id: id,
      description: description,
      quantity: quantity,
      unitPrice: unitPrice,
    );
  }

  @override
  void write(BinaryWriter writer, LineItemModel obj) {
    writer
      ..writeString(obj.id)
      ..writeString(obj.description)
      ..writeDouble(obj.quantity)
      ..writeDouble(obj.unitPrice);
  }
}
