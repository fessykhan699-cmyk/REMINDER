import '../entities/expense.dart';
import '../repositories/expense_repository.dart';

class AddExpenseUseCase {
  const AddExpenseUseCase(this._repository);
  final ExpenseRepository _repository;

  Future<void> call(Expense expense) => _repository.addExpense(expense);
}
