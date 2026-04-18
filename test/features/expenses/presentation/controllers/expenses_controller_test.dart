import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reminder/features/expenses/data/providers/expense_repository_provider.dart';
import 'package:reminder/features/expenses/domain/entities/expense.dart';
import 'package:reminder/features/expenses/domain/repositories/expense_repository.dart';
import 'package:reminder/features/expenses/domain/usecases/add_expense_usecase.dart';
import 'package:reminder/features/expenses/domain/usecases/delete_expense_usecase.dart';
import 'package:reminder/features/expenses/domain/usecases/get_expenses_usecase.dart';
import 'package:reminder/features/expenses/presentation/controllers/expenses_controller.dart';

void main() {
  group('ExpensesController', () {
    test('state is AsyncLoading initially before load completes', () async {
      final completer = Completer<List<Expense>>();
      final repo = _SpyExpenseRepository(
        getExpensesHandler: () => completer.future,
      );
      final container = _createContainer(repo);

      addTearDown(container.dispose);

      final initialState = container.read(expensesControllerProvider);
      expect(initialState.isLoading, isTrue);

      completer.complete(const <Expense>[]);
      await _waitForExpenses(container);
    });

    test('loadExpenses populates state with expense list', () async {
      final expenses = [
        _expense(id: 'exp-1', amount: 100),
        _expense(id: 'exp-2', amount: 250),
      ];
      final repo = _SpyExpenseRepository(initialExpenses: expenses);
      final container = _createContainer(repo);

      addTearDown(container.dispose);

      final state = await _waitForExpenses(container);

      expect(state, hasLength(2));
      expect(state.map((e) => e.id), ['exp-1', 'exp-2']);
    });

    test('addExpense calls repository when gate is true (current behavior)',
        () async {
      final repo = _SpyExpenseRepository(initialExpenses: const <Expense>[]);
      final container = _createContainer(repo);

      addTearDown(container.dispose);
      await _waitForExpenses(container);

      final controller = container.read(expensesControllerProvider.notifier);
      final expense = _expense(id: 'exp-new', amount: 77);

      await controller.addExpense(expense);

      expect(repo.addedExpenses, [expense]);
    });

    test('deleteExpense calls repository.deleteExpense with correct id',
        () async {
      final repo = _SpyExpenseRepository(
        initialExpenses: [_expense(id: 'exp-delete', amount: 50)],
      );
      final container = _createContainer(repo);

      addTearDown(container.dispose);
      await _waitForExpenses(container);

      final controller = container.read(expensesControllerProvider.notifier);
      await controller.deleteExpense('exp-delete');

      expect(repo.deletedExpenseIds, ['exp-delete']);
    });

    test('totalExpensesProvider returns correct aggregate sum', () async {
      final repo = _SpyExpenseRepository(
        initialExpenses: [
          _expense(id: 'exp-a', amount: 12.5),
          _expense(id: 'exp-b', amount: 7.5),
          _expense(id: 'exp-c', amount: 30),
        ],
      );
      final container = _createContainer(repo);

      addTearDown(container.dispose);
      await _waitForExpenses(container);

      expect(container.read(totalExpensesProvider), 50.0);
    });
  });
}

ProviderContainer _createContainer(_SpyExpenseRepository repo) {
  return ProviderContainer(
    overrides: [
      expenseRepositoryProvider.overrideWithValue(repo),
      getExpensesUseCaseProvider.overrideWithValue(GetExpensesUseCase(repo)),
      addExpenseUseCaseProvider.overrideWithValue(AddExpenseUseCase(repo)),
      deleteExpenseUseCaseProvider.overrideWithValue(DeleteExpenseUseCase(repo)),
    ],
  );
}

Future<List<Expense>> _waitForExpenses(ProviderContainer container) async {
  for (var i = 0; i < 100; i++) {
    final state = container.read(expensesControllerProvider);
    if (state.hasValue) {
      return state.requireValue;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  throw StateError('Timed out waiting for expenses controller data');
}

Expense _expense({required String id, required double amount}) {
  return Expense(
    id: id,
    description: 'Expense $id',
    amount: amount,
    date: DateTime(2026, 1, 15),
    category: ExpenseCategory.software,
  );
}

class _SpyExpenseRepository implements ExpenseRepository {
  _SpyExpenseRepository({
    List<Expense>? initialExpenses,
    this.getExpensesHandler,
  }) : _expenses = initialExpenses ?? const <Expense>[];

  final Future<List<Expense>> Function()? getExpensesHandler;
  List<Expense> _expenses;

  final List<Expense> addedExpenses = <Expense>[];
  final List<String> deletedExpenseIds = <String>[];

  @override
  Future<void> addExpense(Expense expense) async {
    addedExpenses.add(expense);
    _expenses = [..._expenses, expense];
  }

  @override
  Future<void> deleteExpense(String id) async {
    deletedExpenseIds.add(id);
    _expenses = _expenses.where((expense) => expense.id != id).toList();
  }

  @override
  Future<List<Expense>> getExpenses() async {
    final handler = getExpensesHandler;
    if (handler != null) {
      return handler();
    }
    return _expenses;
  }
}
