import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_controller.dart';

final expenseCurrencyControllerProvider =
    NotifierProvider<ExpenseCurrencyController, String>(
  ExpenseCurrencyController.new,
);

class ExpenseCurrencyController extends Notifier<String> {
  @override
  String build() {
    // We start with a default and load the real value asynchronously.
    // However, since build must return a value synchronously, we use 'AED' as initial.
    // We then trigger a load.
    _load();
    return 'AED';
  }

  Future<void> _load() async {
    final repository = ref.read(settingsRepositoryProvider);
    final currency = await repository.getExpenseCurrency();
    state = currency;
  }

  Future<void> setCurrency(String currency) async {
    final repository = ref.read(settingsRepositoryProvider);
    await repository.saveExpenseCurrency(currency);
    state = currency;
  }
}
