// ignore_for_file: overridden_fields

import 'package:hive/hive.dart';
import '../../domain/entities/invoice_template.dart';
import 'line_item_model.dart';

@HiveType(typeId: 12)
class InvoiceTemplateModel extends InvoiceTemplate {
  const InvoiceTemplateModel({
    required this.id,
    required this.name,
    required this.service,
    required this.amount,
    this.items = const [],
    this.notes,
    this.paymentLink,
  }) : super(
          id: id,
          name: name,
          service: service,
          amount: amount,
          items: items,
          notes: notes,
          paymentLink: paymentLink,
        );

  @override
  @HiveField(0)
  final String id;

  @override
  @HiveField(1)
  final String name;

  @override
  @HiveField(2)
  final String service;

  @override
  @HiveField(3)
  final double amount;

  @override
  @HiveField(4)
  final List<LineItemModel> items;

  @override
  @HiveField(5)
  final String? notes;

  @override
  @HiveField(6)
  final String? paymentLink;

  factory InvoiceTemplateModel.fromEntity(InvoiceTemplate template) {
    return InvoiceTemplateModel(
      id: template.id,
      name: template.name,
      service: template.service,
      amount: template.amount,
      items: template.items.map((e) => LineItemModel.fromEntity(e)).toList(),
      notes: template.notes,
      paymentLink: template.paymentLink,
    );
  }

  factory InvoiceTemplateModel.fromJson(Map<String, dynamic> json) {
    return InvoiceTemplateModel(
      id: json['id'] as String,
      name: json['name'] as String,
      service: json['service'] as String,
      amount: (json['amount'] as num).toDouble(),
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => LineItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      notes: json['notes'] as String?,
      paymentLink: json['paymentLink'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'service': service,
      'amount': amount,
      'items': items.map((e) => e.toJson()).toList(),
      'notes': notes,
      'paymentLink': paymentLink,
    };
  }
}

class InvoiceTemplateModelAdapter extends TypeAdapter<InvoiceTemplateModel> {
  @override
  final int typeId = 12;

  @override
  InvoiceTemplateModel read(BinaryReader reader) {
    final id = reader.readString();
    final name = reader.readString();
    final service = reader.readString();
    final amount = reader.readDouble();
    final notes = reader.availableBytes > 0 ? reader.readString() : null;
    final paymentLink = reader.availableBytes > 0 ? reader.readString() : null;

    List<LineItemModel> items = [];
    if (reader.availableBytes > 0) {
      final itemsRaw = reader.readList();
      items = itemsRaw.cast<LineItemModel>();
    }

    return InvoiceTemplateModel(
      id: id,
      name: name,
      service: service,
      amount: amount,
      notes: notes == '' ? null : notes,
      paymentLink: paymentLink == '' ? null : paymentLink,
      items: items,
    );
  }

  @override
  void write(BinaryWriter writer, InvoiceTemplateModel obj) {
    writer
      ..writeString(obj.id)
      ..writeString(obj.name)
      ..writeString(obj.service)
      ..writeDouble(obj.amount)
      ..writeString(obj.notes ?? '')
      ..writeString(obj.paymentLink ?? '')
      ..writeList(obj.items);
  }
}
