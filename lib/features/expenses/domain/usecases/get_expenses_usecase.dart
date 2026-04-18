import '../entities/expense.dart';
import '../repositories/expense_repository.dart';

class GetExpensesUseCase {
  const GetExpensesUseCase(this._repository);
  final ExpenseRepository _repository;

  Future<List<Expense>> call() => _repository.getExpenses();
}




