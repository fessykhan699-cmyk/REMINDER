import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/expense.dart';

import '../../data/providers/expense_repository_provider.dart';

final expensesControllerProvider =
    NotifierProvider<ExpensesController, AsyncValue<List<Expense>>>(
      ExpensesController.new,
    );

class ExpensesController extends Notifier<AsyncValue<List<Expense>>> {
  @override
  AsyncValue<List<Expense>> build() {
    loadExpenses();
    return const AsyncValue.loading();
  }

  Future<void> loadExpenses() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(getExpensesUseCaseProvider).call(),
    );
  }

  Future<void> addExpense(Expense expense) async {
    await ref.read(addExpenseUseCaseProvider).call(expense);
    await loadExpenses();
  }

  Future<void> deleteExpense(String id) async {
    await ref.read(deleteExpenseUseCaseProvider).call(id);
    await loadExpenses();
  }
}

final totalExpensesProvider = Provider<double>((ref) {
  final expenses = ref.watch(expensesControllerProvider).valueOrNull ?? [];
  return expenses.fold(0.0, (sum, e) => sum + e.amount);
});
