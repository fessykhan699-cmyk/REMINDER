import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/storage/hive_storage.dart';
import '../models/expense_model.dart';
import '../../domain/entities/expense.dart';

class ExpensesLocalDatasource {
  Box<ExpenseModel> get _box => Hive.box<ExpenseModel>(HiveStorage.expensesBoxName);

  Future<List<Expense>> getExpenses() async {
    return _box.values.toList();
  }

  Future<void> addExpense(Expense expense) async {
    final model = ExpenseModel.fromEntity(expense);
    await _box.put(model.id, model);
  }

  Future<void> deleteExpense(String id) async {
    await _box.delete(id);
  }
}
