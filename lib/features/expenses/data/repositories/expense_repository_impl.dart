import '../../../../data/services/firestore_sync_service.dart';
import '../../domain/entities/expense.dart';
import '../../domain/repositories/expense_repository.dart';
import '../datasources/expenses_local_datasource.dart';
import '../models/expense_model.dart';

class ExpenseRepositoryImpl implements ExpenseRepository {
  const ExpenseRepositoryImpl(
    this._datasource, {
    this.syncService,
    this.userId,
    this.isPro = false,
  });

  final ExpensesLocalDatasource _datasource;
  final FirestoreSyncService? syncService;
  final String? userId;
  final bool isPro;

  @override
  Future<List<Expense>> getExpenses() => _datasource.getExpenses();

  @override
  Future<void> addExpense(Expense expense) async {
    await _datasource.addExpense(expense);
    _syncExpense(ExpenseModel.fromEntity(expense));
  }

  @override
  Future<void> deleteExpense(String id) async {
    await _datasource.deleteExpense(id);
    _deleteExpense(id);
  }

  void _syncExpense(ExpenseModel model) {
    final svc = syncService;
    final uid = userId;
    if (svc == null || uid == null) return;
    svc.syncExpenseToCloud(userId: uid, isPro: isPro, expense: model);
  }

  void _deleteExpense(String expenseId) {
    final svc = syncService;
    final uid = userId;
    if (svc == null || uid == null) return;
    svc.deleteExpenseFromCloud(userId: uid, isPro: isPro, expenseId: expenseId);
  }
}
