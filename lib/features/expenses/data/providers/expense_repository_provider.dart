import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/providers/firestore_sync_provider.dart';
import '../../../subscription/presentation/controllers/subscription_controller.dart';
import '../../domain/repositories/expense_repository.dart';
import '../../domain/usecases/add_expense_usecase.dart';
import '../../domain/usecases/delete_expense_usecase.dart';
import '../../domain/usecases/get_expenses_usecase.dart';
import '../datasources/expenses_local_datasource.dart';
import '../repositories/expense_repository_impl.dart';

final expensesLocalDatasourceProvider = Provider<ExpensesLocalDatasource>(
  (ref) => ExpensesLocalDatasource(),
);

final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (ref) {
    final datasource = ref.watch(expensesLocalDatasourceProvider);
    return ExpenseRepositoryImpl(
      datasource,
      syncService: ref.watch(firestoreSyncServiceProvider),
      userId: ref.watch(currentUserIdProvider),
      isPro: ref.watch(subscriptionControllerProvider).valueOrNull?.isPro ?? false,
    );
  },
);

final getExpensesUseCaseProvider = Provider<GetExpensesUseCase>(
  (ref) => GetExpensesUseCase(ref.watch(expenseRepositoryProvider)),
);

final addExpenseUseCaseProvider = Provider<AddExpenseUseCase>(
  (ref) => AddExpenseUseCase(ref.watch(expenseRepositoryProvider)),
);

final deleteExpenseUseCaseProvider = Provider<DeleteExpenseUseCase>(
  (ref) => DeleteExpenseUseCase(ref.watch(expenseRepositoryProvider)),
);
