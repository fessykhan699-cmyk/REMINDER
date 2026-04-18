// ignore_for_file: overridden_fields

import 'package:hive/hive.dart';
import '../../domain/entities/expense.dart';

class ExpenseCategoryAdapter extends TypeAdapter<ExpenseCategory> {
  @override
  final int typeId = 14;

  @override
  ExpenseCategory read(BinaryReader reader) {
    return ExpenseCategory.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, ExpenseCategory obj) {
    writer.writeByte(obj.index);
  }
}

@HiveType(typeId: 13)
class ExpenseModel extends Expense {
  const ExpenseModel({
    required this.id,
    required this.description,
    required this.amount,
    required this.date,
    required this.category,
    this.notes,
  }) : super(
          id: id,
          description: description,
          amount: amount,
          date: date,
          category: category,
          notes: notes,
        );

  @override
  @HiveField(0)
  final String id;

  @override
  @HiveField(1)
  final String description;

  @override
  @HiveField(2)
  final double amount;

  @override
  @HiveField(3)
  final DateTime date;

  @override
  @HiveField(4)
  final ExpenseCategory category;

  @override
  @HiveField(5)
  final String? notes;

  factory ExpenseModel.fromEntity(Expense expense) {
    return ExpenseModel(
      id: expense.id,
      description: expense.description,
      amount: expense.amount,
      date: expense.date,
      category: expense.category,
      notes: expense.notes,
    );
  }

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id'] as String,
      description: json['description'] as String,
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      category: ExpenseCategory.values.firstWhere(
        (e) => e.name == (json['category'] as String),
        orElse: () => ExpenseCategory.other,
      ),
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category.name,
      'notes': notes,
    };
  }
}

class ExpenseModelAdapter extends TypeAdapter<ExpenseModel> {
  @override
  final int typeId = 13;

  @override
  ExpenseModel read(BinaryReader reader) {
    final id = reader.readString();
    final description = reader.readString();
    final amount = reader.readDouble();
    final date = DateTime.parse(reader.readString());
    final categoryIndex = reader.readByte();
    final category = ExpenseCategory.values[categoryIndex];
    final notes = reader.availableBytes > 0 ? reader.readString() : null;

    return ExpenseModel(
      id: id,
      description: description,
      amount: amount,
      date: date,
      category: category,
      notes: notes?.isEmpty == true ? null : notes,
    );
  }

  @override
  void write(BinaryWriter writer, ExpenseModel obj) {
    writer
      ..writeString(obj.id)
      ..writeString(obj.description)
      ..writeDouble(obj.amount)
      ..writeString(obj.date.toIso8601String())
      ..writeByte(obj.category.index)
      ..writeString(obj.notes ?? '');
  }
}
