import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_routes.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/components/app_scaffold.dart';
import '../../../../shared/components/glass_card.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../controllers/expenses_controller.dart';
import '../../domain/entities/expense.dart';

class ExpensesListScreen extends ConsumerStatefulWidget {
  const ExpensesListScreen({super.key});

  @override
  ConsumerState<ExpensesListScreen> createState() => _ExpensesListScreenState();
}

class _ExpensesListScreenState extends ConsumerState<ExpensesListScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  )..forward();

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  Widget _staggeredItem({required int index, required Widget child}) {
    final begin = (index * 0.10).clamp(0.0, 0.80);
    return AnimatedBuilder(
      animation: _entryCtrl,
      child: child,
      builder: (context, stableChild) {
        final progress = Curves.easeOut.transform(
          Interval(begin, 1.0).transform(_entryCtrl.value),
        );
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, (1 - progress) * 8),
            child: stableChild,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expensesAsync = ref.watch(expensesControllerProvider);
    final totalExpenses = ref.watch(totalExpensesProvider);

    return AppScaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(spacingMD),
                child: _staggeredItem(
                  index: 0,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Expenses',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => const AddExpenseRoute().push(context),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.accent.withValues(alpha: 0.14),
                          foregroundColor: AppColors.textPrimary,
                          shape: const CircleBorder(),
                        ),
                        icon: const Icon(Icons.add, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (totalExpenses > 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: spacingMD),
                  child: _staggeredItem(
                    index: 1,
                    child: GlassCard(
                      padding: const EdgeInsets.all(spacingMD),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Expenses',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '\$${totalExpenses.toStringAsFixed(2)}',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: spacingLG)),
            expensesAsync.when(
              data: (expenses) {
                if (expenses.isEmpty) {
                  return SliverFillRemaining(
                    child: AppEmptyState(
                      title: 'No expenses yet',
                      message: 'Track your spending to stay on top of your budget.',
                      action: FilledButton.icon(
                        onPressed: () => const AddExpenseRoute().push(context),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add Expense'),
                      ),
                    ),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final expense = expenses[index];
                      return _staggeredItem(
                        index: index + 2,
                        child: _ExpenseTile(
                          expense: expense,
                          onDelete: () => ref
                              .read(expensesControllerProvider.notifier)
                              .deleteExpense(expense.id),
                        ),
                      );
                    },
                    childCount: expenses.length,
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, stack) => SliverFillRemaining(
                child: Center(child: Text('Error: $err')),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.of(context).padding.bottom + 100,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({
    required this.expense,
    required this.onDelete,
  });

  final Expense expense;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: spacingMD, vertical: spacingXS),
      child: GlassCard(
        padding: const EdgeInsets.all(spacingMD),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(spacingSM),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getCategoryIcon(expense.category),
                size: 20,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: spacingMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.description,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    dateFormat.format(expense.date),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${expense.amount.toStringAsFixed(2)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.redAccent,
                  ),
                ),
                GestureDetector(
                  onTap: onDelete,
                  child: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.meals:
        return Icons.restaurant;
      case ExpenseCategory.travel:
        return Icons.flight;
      case ExpenseCategory.supplies:
        return Icons.inventory_2;
      case ExpenseCategory.software:
        return Icons.computer;
      case ExpenseCategory.marketing:
        return Icons.campaign;
      case ExpenseCategory.rent:
        return Icons.home;
      case ExpenseCategory.utilities:
        return Icons.bolt;
      case ExpenseCategory.other:
        return Icons.more_horiz;
    }
  }
}
