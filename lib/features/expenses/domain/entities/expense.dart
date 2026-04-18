import 'expense_category.dart';
export 'expense_category.dart';

class Expense {
  final String id;
  final String description;
  final double amount;
  final DateTime date;
  final ExpenseCategory category;
  final String? notes;

  const Expense({
    required this.id,
    required this.description,
    required this.amount,
    required this.date,
    required this.category,
    this.notes,
  });

  Expense copyWith({
    String? id,
    String? description,
    double? amount,
    DateTime? date,
    ExpenseCategory? category,
    String? notes,
  }) {
    return Expense(
      id: id ?? this.id,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      category: category ?? this.category,
      notes: notes ?? this.notes,
    );
  }


}
