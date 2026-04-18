import 'package:flutter_test/flutter_test.dart';
import 'package:reminder/features/expenses/domain/entities/expense.dart';

void main() {
  Expense buildExpense() {
    return Expense(
      id: 'exp-1',
      description: 'Taxi',
      amount: 45.0,
      date: DateTime(2026, 4, 20),
      category: ExpenseCategory.travel,
      notes: 'Airport ride',
    );
  }

  test('copyWith preserves all fields when no arguments passed', () {
    final expense = buildExpense();
    final copied = expense.copyWith();

    expect(copied.id, expense.id);
    expect(copied.description, expense.description);
    expect(copied.amount, expense.amount);
    expect(copied.date, expense.date);
    expect(copied.category, expense.category);
    expect(copied.notes, expense.notes);
  });

  test('copyWith overrides only specified fields', () {
    final expense = buildExpense();
    final updated = expense.copyWith(
      amount: 60.0,
      description: 'Taxi + toll',
    );

    expect(updated.amount, 60.0);
    expect(updated.description, 'Taxi + toll');
    expect(updated.id, expense.id);
    expect(updated.category, expense.category);
    expect(updated.notes, expense.notes);
  });

  test('different instances with same id are not value-equal by default', () {
    final first = buildExpense();
    final second = buildExpense();

    expect(identical(first, second), isFalse);
    expect(first == second, isFalse);
  });

  test('expense stores category enum correctly', () {
    final expense = buildExpense().copyWith(category: ExpenseCategory.software);
    expect(expense.category, ExpenseCategory.software);
  });

  test('expense amount of 0.0 is valid', () {
    final expense = buildExpense().copyWith(amount: 0.0);
    expect(expense.amount, 0.0);
  });
}
