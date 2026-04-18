import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/storage/hive_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../shared/adaptive/adaptive_system_controller.dart';
import '../../../../shared/components/glass_card.dart';
import '../../../clients/presentation/controllers/clients_controller.dart';
import '../../../invoices/domain/entities/invoice.dart';
import '../../../invoices/presentation/controllers/invoices_controller.dart';
import '../../../reminders/presentation/controllers/reminders_controller.dart';
import '../../../settings/presentation/controllers/app_preferences_controller.dart';
import '../../../settings/presentation/controllers/settings_controller.dart';
import '../../../subscription/domain/entities/subscription_state.dart';
import '../../../subscription/presentation/controllers/subscription_controller.dart';
import '../../../subscription/presentation/widgets/upgrade_prompt_sheet.dart';
import '../../../../data/services/cash_flow_service.dart';
import '../../../../presentation/widgets/cash_flow_chart_widget.dart';
import '../../../expenses/presentation/controllers/expenses_controller.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  )..forward();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final invoices = ref.read(invoicesControllerProvider).valueOrNull;
      if (invoices == null) {
        return;
      }
      ref
          .read(adaptiveSystemProvider.notifier)
          .recordReminderOpportunity(
            overdueCount: _effectiveOverdueCount(invoices),
          );
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  Widget _staggeredCard({required int index, required Widget child}) {
    final begin = (index * 0.125).clamp(0.0, 0.85);
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

  Widget _fadeListItem({required int index, required Widget child}) {
    final begin = (0.50 + (index * 0.10)).clamp(0.0, 0.95);
    return AnimatedBuilder(
      animation: _entryCtrl,
      child: child,
      builder: (context, stableChild) {
        final progress = Curves.easeOut.transform(
          Interval(begin, 1.0).transform(_entryCtrl.value),
        );
        return Opacity(opacity: progress, child: stableChild);
      },
    );
  }

  Widget _buildAnimatedDashboardSection({
    required String keyValue,
    required Widget child,
  }) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(keyValue),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: child,
      builder: (context, value, stableChild) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 12),
            child: stableChild,
          ),
        );
      },
    );
  }

  Widget _buildRecentActivitySection(
    BuildContext context,
    _DashboardViewModel model,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        if (model.recentActivity.isEmpty)
          const GlassCard(
            padding: EdgeInsets.all(16),
            child: Text(
              'No invoice activity yet.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          )
        else
          ...List<Widget>.generate(model.recentActivity.length, (index) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: index < model.recentActivity.length - 1 ? 16 : 0,
              ),
              child: _fadeListItem(
                index: index,
                child: _RecentActivityRow(invoice: model.recentActivity[index]),
              ),
            );
          }),
      ],
    );
  }

  Future<void> _handleSuggestionTap(
    BuildContext context,
    _DashboardSuggestion suggestion,
  ) async {
    switch (suggestion.action) {
      case _DashboardSuggestionAction.createInvoice:
        final decision = await ref
            .read(subscriptionGatekeeperProvider)
            .evaluate(SubscriptionGateFeature.createInvoice);
        if (!decision.isAllowed) {
          if (!context.mounted) {
            return;
          }
          final upgraded = await promptUpgradeForDecision(context, decision);
          if (!upgraded || !context.mounted) {
            return;
          }
        }

        if (!mounted || !context.mounted) {
          return;
        }

        await const CreateInvoiceRoute().push(context);
        return;
      case _DashboardSuggestionAction.addClient:
        final decision = await ref
            .read(subscriptionGatekeeperProvider)
            .evaluate(SubscriptionGateFeature.addClient);
        if (!decision.isAllowed) {
          if (!context.mounted) {
            return;
          }
          final upgraded = await promptUpgradeForDecision(context, decision);
          if (!upgraded || !context.mounted) {
            return;
          }
        }

        if (!mounted || !context.mounted) {
          return;
        }

        await const AddClientRoute().push(context);
        return;
      case _DashboardSuggestionAction.reviewPayments:
        const InvoicesTabRoute().go(context);
        return;
      case _DashboardSuggestionAction.sendReminder:
        final invoiceId = suggestion.invoiceId;
        if (invoiceId == null) {
          return;
        }
        await ReminderFlowRoute(invoiceId).push(context);
        return;
    }
  }

  Future<void> _handleSmartReminderTap(
    BuildContext context,
    _SmartReminderData reminder,
    SubscriptionState subscription,
  ) async {
    if (!subscription.isPro) {
      final decision = await ref
          .read(subscriptionGatekeeperProvider)
          .evaluate(SubscriptionGateFeature.smartReminders);
      if (!context.mounted) {
        return;
      }
      final upgraded = await promptUpgradeForDecision(context, decision);
      if (!upgraded || !context.mounted) {
        return;
      }
    }

    final invoiceId = reminder.invoiceId;
    if (invoiceId == null || !context.mounted) {
      return;
    }

    await ReminderFlowRoute(invoiceId).push(context);
  }

  Widget _buildSuggestionsSection(
    BuildContext context,
    _DashboardViewModel model,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Next Actions',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        ...List<Widget>.generate(model.suggestions.length, (index) {
          final suggestion = model.suggestions[index];
          return Padding(
            padding: EdgeInsets.only(
              bottom: index < model.suggestions.length - 1 ? 16 : 0,
            ),
            child: GestureDetector(
              onTap: () {
                _handleSuggestionTap(context, suggestion);
              },
              behavior: HitTestBehavior.opaque,
              child: GlassCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent.withValues(alpha: 0.14),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.30),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        suggestion.icon,
                        size: 18,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            suggestion.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            suggestion.detail,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    _DashboardViewModel model,
    SubscriptionState subscription,
    String currencyCode,
    AsyncValue<List<Invoice>> invoicesState,
    double totalExpenses,
  ) {
    final sections = <Widget>[];

    void addSection(String id, Widget child) {
      if (sections.isNotEmpty) {
        sections.add(const SizedBox(height: 24));
      }
      sections.add(
        _buildAnimatedDashboardSection(
          keyValue: '${model.animationKey}-$id',
          child: child,
        ),
      );
    }

    switch (model.urgency) {
      case _DashboardUrgency.empty:
        addSection(
          'empty',
          _EmptyDashboardState(subtitle: model.emptySubtitle),
        );
        break;
      case _DashboardUrgency.overdue:
        addSection(
          'priority',
          _PriorityFocusSection(data: model.prioritySection!),
        );
        addSection(
          'reminder',
          _SmartReminderSection(
            data: model.reminder,
            isLocked: !subscription.isPro,
            onTap: () {
              _handleSmartReminderTap(context, model.reminder, subscription);
            },
          ),
        );
        if (model.suggestions.isNotEmpty) {
          addSection('suggestions', _buildSuggestionsSection(context, model));
        }
        addSection('stats', _StatsSection(totals: model.totals, totalExpenses: totalExpenses));
        addSection('cash_flow', _buildCashFlowSection(context, invoicesState, subscription));
        addSection('recent', _buildRecentActivitySection(context, model));
        break;
      case _DashboardUrgency.dueSoon:
        addSection(
          'priority',
          _PriorityFocusSection(data: model.prioritySection!),
        );
        addSection(
          'reminder',
          _SmartReminderSection(
            data: model.reminder,
            isLocked: !subscription.isPro,
            onTap: () {
              _handleSmartReminderTap(context, model.reminder, subscription);
            },
          ),
        );
        if (model.suggestions.isNotEmpty) {
          addSection('suggestions', _buildSuggestionsSection(context, model));
        }
        addSection('stats', _StatsSection(totals: model.totals, totalExpenses: totalExpenses));
        addSection('cash_flow', _buildCashFlowSection(context, invoicesState, subscription));
        addSection('recent', _buildRecentActivitySection(context, model));
        break;
      case _DashboardUrgency.calm:
        if (model.focusMode == _DashboardFocusMode.overview) {
          addSection('stats', _StatsSection(totals: model.totals, totalExpenses: totalExpenses));
          if (model.suggestions.isNotEmpty) {
            addSection('suggestions', _buildSuggestionsSection(context, model));
          }
          addSection(
            'reminder',
            _SmartReminderSection(
              data: model.reminder,
              isLocked: !subscription.isPro,
              onTap: () {
                _handleSmartReminderTap(context, model.reminder, subscription);
              },
            ),
          );
        } else {
          addSection(
            'reminder',
            _SmartReminderSection(
              data: model.reminder,
              isLocked: !subscription.isPro,
              onTap: () {
                _handleSmartReminderTap(context, model.reminder, subscription);
              },
            ),
          );
          if (model.suggestions.isNotEmpty) {
            addSection('suggestions', _buildSuggestionsSection(context, model));
          }
          addSection('stats', _StatsSection(totals: model.totals, totalExpenses: totalExpenses));
        }
      addSection('cash_flow', _buildCashFlowSection(context, invoicesState, subscription));
      addSection('recent', _buildRecentActivitySection(context, model));
        break;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        final offsetAnimation = Tween<Offset>(
          begin: const Offset(0, 0.05),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offsetAnimation, child: child),
        );
      },
      child: SizedBox(
        key: ValueKey(model.animationKey),
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: sections,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(settingsControllerProvider);
    final clientsState = ref.watch(clientsControllerProvider);
    final invoicesState = ref.watch(invoicesControllerProvider);
    final remindersState = ref.watch(remindersHistoryProvider);
    final adaptiveState = ref.watch(adaptiveSystemProvider);

    ref.listen<AsyncValue<List<Invoice>>>(invoicesControllerProvider, (
      previous,
      next,
    ) {
      final data = next.valueOrNull;
      if (data == null) {
        return;
      }
      ref
          .read(adaptiveSystemProvider.notifier)
          .recordReminderOpportunity(
            overdueCount: _effectiveOverdueCount(data),
          );
    });

    final profileName = profileState.valueOrNull?.name ?? 'Studio Owner';
    final invoices = invoicesState.valueOrNull ?? const <Invoice>[];
    final clientCount = clientsState.valueOrNull?.length ?? 0;
    final reminderCount = remindersState.valueOrNull?.length ?? 0;
    final subscription =
        ref.watch(subscriptionControllerProvider).valueOrNull ??
        const SubscriptionState.free();
    final currencyCode =
        ref.watch(appPreferencesControllerProvider).valueOrNull?.defaultCurrency
        ?? 'USD';
    final dashboard = _DashboardViewModel.fromSignals(
      invoices: invoices,
      adaptiveState: adaptiveState,
      clientCount: clientCount,
      reminderCount: reminderCount,
      currencyCode: currencyCode,
    );
    final totalExpenses = ref.watch(totalExpensesProvider);
    final dashboardSections = <Widget>[
      _staggeredCard(
        index: 0,
        child: _HeaderSection(
          name: profileName,
          unpaidByCurrency: dashboard.totals.unpaidByCurrency,
          avatar: const DashboardAvatar(),
        ),
      ),
      _buildDashboardContent(context, dashboard, subscription, currencyCode, invoicesState, totalExpenses),
    ];

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          const Positioned.fill(child: _DashboardGalaxyBackground()),
          Positioned.fill(
            child: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        spacingMD,
                        spacingMD,
                        spacingMD,
                        MediaQuery.of(context).padding.bottom + 80,
                      ),
                      itemCount: dashboardSections.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == dashboardSections.length - 1
                                ? 0
                                : spacingLG,
                          ),
                          child: dashboardSections[index],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildCashFlowSection(
    BuildContext context,
    AsyncValue<List<Invoice>> invoicesState,
    SubscriptionState subscription,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cash Flow — Last 6 Months',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        invoicesState.when(
          data: (invoices) {
            if (!subscription.isPro) {
              return _buildLockedCashFlowPlaceholder(context);
            }
            final chartData = CashFlowService().getLast6MonthsCashFlow(invoices);
            return CashFlowChartWidget(data: chartData);
          },
          loading: () => const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => const SizedBox(
            height: 220,
            child: Center(child: Text('Could not load chart')),
          ),
        ),
      ],
    );
  }

  Widget _buildLockedCashFlowPlaceholder(BuildContext context) {
    return SizedBox(
      height: 220,
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: Stack(
        children: [
          // Background "faked" bars
          Opacity(
            opacity: 0.1,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(6, (index) {
                  final heights = [0.4, 0.7, 0.5, 0.9, 0.6, 0.8];
                  return Container(
                    width: 16,
                    height: 180 * heights[index],
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
          ),
          // Content
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, color: AppColors.accent, size: 32),
                const SizedBox(height: 12),
                const Text(
                  'Pro Feature',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Visualize your earnings over time',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    const UpgradeToProRoute().push(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text('Upgrade to Pro'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
   );
  }

}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({
    required this.name,
    required this.unpaidByCurrency,
    required this.avatar,
  });

  final String name;
  final List<({String currencyCode, double amount})> unpaidByCurrency;
  final Widget avatar;

  @override
  Widget build(BuildContext context) {
    // Build display string: single currency → "AED 2,278.00"
    // Multiple currencies → "AED 2,000 · USD 500"
    final String amountText;
    if (unpaidByCurrency.isEmpty) {
      amountText = AppFormatters.currency(0);
    } else if (unpaidByCurrency.length == 1) {
      final entry = unpaidByCurrency.first;
      amountText = AppFormatters.currency(
        entry.amount,
        currencyCode: entry.currencyCode,
      );
    } else {
      amountText = unpaidByCurrency
          .map(
            (e) => AppFormatters.currency(
              e.amount,
              currencyCode: e.currencyCode,
              includeDecimals: false,
            ),
          )
          .join(' · ');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Good evening,',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Align(alignment: Alignment.topRight, child: avatar),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                'You are owed',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  amountText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({
    required this.totals,
    required this.totalExpenses,
  });

  final _DashboardTotals totals;
  final double totalExpenses;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatsCard(
                value: totals.pendingCount.toString(),
                label: 'Pending',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatsCard(
                value: totals.overdueCount.toString(),
                label: 'Overdue',
                valueColor: AppColors.danger,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatsCard(
                value: totals.paidCount.toString(),
                label: 'Paid',
                valueColor: AppColors.success,
              ),
            ),
          ],
        ),
        if (totalExpenses > 0) ...[
          const SizedBox(height: 12),
          _StatsCard(
            value: AppFormatters.currency(totalExpenses),
            label: 'Total Expenses',
            valueColor: Colors.redAccent,
            isFullWidth: true,
          ),
        ],
      ],
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.value,
    required this.label,
    this.valueColor,
    this.isFullWidth = false,
  });

  final String value;
  final String label;
  final Color? valueColor;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: SizedBox(
        width: isFullWidth ? double.infinity : null,
        child: Column(
          children: [
            Text(
              value,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: valueColor,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}


class _PriorityFocusSection extends StatelessWidget {
  const _PriorityFocusSection({required this.data});

  final _PrioritySectionData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: data.tint.withValues(alpha: 0.14),
                border: Border.all(color: data.tint.withValues(alpha: 0.30)),
              ),
              alignment: Alignment.center,
              child: Icon(data.icon, size: 18, color: AppColors.textPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...List<Widget>.generate(data.invoices.length, (index) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index < data.invoices.length - 1 ? 16 : 0,
                  ),
                  child: _PriorityInvoiceRow(invoice: data.invoices[index]),
                );
              }),
              if (data.ctaInvoiceId != null) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ReminderFlowRoute(data.ctaInvoiceId!).push(context);
                    },
                    icon: const Icon(Icons.send_rounded),
                    label: Text(
                      data.ctaLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PriorityInvoiceRow extends StatelessWidget {
  const _PriorityInvoiceRow({required this.invoice});

  final _RankedInvoice invoice;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accent.withValues(alpha: 0.14),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.30)),
          ),
          alignment: Alignment.center,
          child: Text(
            invoice.invoice.clientName.isEmpty
                ? '?'
                : invoice.invoice.clientName.characters.first.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                invoice.invoice.clientName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '${invoice.invoice.items.length > 1 ? "${invoice.invoice.items.length} Items" : (invoice.invoice.items.isNotEmpty ? invoice.invoice.items.first.description : invoice.invoice.service)} • ${invoice.dueLabel}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: invoice.isOverdue
                      ? AppColors.danger
                      : invoice.invoice.status == InvoiceStatus.paid
                          ? AppColors.success
                          : AppColors.warning,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              AppFormatters.currency(
                invoice.invoice.amount,
                currencyCode: invoice.invoice.currencyCode,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: invoice.isOverdue ? AppColors.danger : null,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyDashboardState extends StatelessWidget {
  const _EmptyDashboardState({required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "You're all set",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _SmartReminderSection extends StatelessWidget {
  const _SmartReminderSection({
    required this.data,
    this.onTap,
    this.isLocked = false,
  });

  final _SmartReminderData data;
  final VoidCallback? onTap;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: RepaintBoundary(
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.14),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.30),
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.notifications_active_outlined,
                  size: 18,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart Reminders',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.headline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isLocked
                          ? 'Upgrade to unlock proactive smart reminders.'
                          : data.detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isLocked ? Icons.lock_outline_rounded : Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentActivityRow extends StatelessWidget {
  const _RecentActivityRow({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.14),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.30),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                invoice.clientName.isEmpty
                    ? '?'
                    : invoice.clientName.characters.first.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invoice.clientName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${invoice.items.length > 1 ? "${invoice.items.length} Items" : (invoice.items.isNotEmpty ? invoice.items.first.description : invoice.service)} • ${invoice.status.label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: switch (invoice.status) {
                        InvoiceStatus.overdue => AppColors.danger,
                        InvoiceStatus.paid => AppColors.success,
                        _ => AppColors.warning,
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  AppFormatters.currency(
                    invoice.amount,
                    currencyCode: invoice.currencyCode,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: invoice.status == InvoiceStatus.overdue
                        ? AppColors.danger
                        : null,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardGalaxyBackground extends StatelessWidget {
  const _DashboardGalaxyBackground();

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: const Color(0xFF0F1115)),
          Image.asset(
            'assets/images/galaxy.jpg',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.40),
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.50),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0.03,
              child: Image.asset(
                'assets/noise.png',
                repeat: ImageRepeat.repeat,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardTotals {
  const _DashboardTotals({
    required this.totalUnpaid,
    required this.pendingAmount,
    required this.paidCount,
    required this.pendingCount,
    required this.overdueCount,
    required this.unpaidByCurrency,
  });

  /// Sum of all unpaid invoice amounts regardless of currency.
  /// Used only for threshold comparisons (e.g. "is more than 2500 at risk?").
  /// Do NOT display this as a money value — use [unpaidByCurrency] instead.
  final double totalUnpaid;
  final double pendingAmount;
  final int paidCount;
  final int pendingCount;
  final int overdueCount;

  /// Unpaid totals grouped by currency code, sorted descending by amount.
  /// Use this for display so multi-currency invoices are shown accurately.
  final List<({String currencyCode, double amount})> unpaidByCurrency;

  factory _DashboardTotals.fromInvoices(List<Invoice> invoices) {
    var pendingAmount = 0.0;
    var overdueAmount = 0.0;
    var paidCount = 0;
    var pendingCount = 0;
    var overdueCount = 0;
    final Map<String, double> byCurrency = {};

    for (final invoice in invoices) {
      switch (invoice.status) {
        case InvoiceStatus.paid:
          paidCount++;
        case InvoiceStatus.draft:
        case InvoiceStatus.sent:
        case InvoiceStatus.viewed:
          pendingCount++;
          pendingAmount += invoice.amount;
          byCurrency[invoice.currencyCode] =
              (byCurrency[invoice.currencyCode] ?? 0) + invoice.amount;
        case InvoiceStatus.overdue:
          overdueCount++;
          overdueAmount += invoice.amount;
          byCurrency[invoice.currencyCode] =
              (byCurrency[invoice.currencyCode] ?? 0) + invoice.amount;
      }
    }

    final unpaidByCurrency = byCurrency.entries
        .map((e) => (currencyCode: e.key, amount: e.value))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    return _DashboardTotals(
      totalUnpaid: pendingAmount + overdueAmount,
      pendingAmount: pendingAmount,
      paidCount: paidCount,
      pendingCount: pendingCount,
      overdueCount: overdueCount,
      unpaidByCurrency: unpaidByCurrency,
    );
  }
}

enum _DashboardUrgency { empty, overdue, dueSoon, calm }

enum _DashboardFocusMode { overview, pending, followUp }

enum _DashboardSuggestionAction {
  createInvoice,
  addClient,
  reviewPayments,
  sendReminder,
}

class _DashboardSuggestion {
  const _DashboardSuggestion({
    required this.id,
    required this.title,
    required this.detail,
    required this.icon,
    required this.action,
    this.invoiceId,
  });

  final String id;
  final String title;
  final String detail;
  final IconData icon;
  final _DashboardSuggestionAction action;
  final String? invoiceId;
}

class _DashboardViewModel {
  const _DashboardViewModel({
    required this.totals,
    required this.overdueInvoices,
    required this.dueSoonInvoices,
    required this.pendingInvoices,
    required this.paidInvoices,
    required this.prioritySection,
    required this.topPriorityInvoices,
    required this.recentActivity,
    required this.reminder,
    required this.suggestions,
    required this.emptySubtitle,
    required this.focusMode,
    required this.urgency,
    required this.animationKey,
  });

  final _DashboardTotals totals;
  final List<Invoice> overdueInvoices;
  final List<Invoice> dueSoonInvoices;
  final List<Invoice> pendingInvoices;
  final List<Invoice> paidInvoices;
  final _PrioritySectionData? prioritySection;
  final List<_RankedInvoice> topPriorityInvoices;
  final List<Invoice> recentActivity;
  final _SmartReminderData reminder;
  final List<_DashboardSuggestion> suggestions;
  final String emptySubtitle;
  final _DashboardFocusMode focusMode;
  final _DashboardUrgency urgency;
  final String animationKey;

  factory _DashboardViewModel.fromSignals({
    required List<Invoice> invoices,
    required AdaptiveSystemState adaptiveState,
    required int clientCount,
    required int reminderCount,
    String currencyCode = 'USD',
  }) {
    final now = DateTime.now();
    final overdueInvoices = <Invoice>[];
    final dueSoonInvoices = <Invoice>[];
    final pendingInvoices = <Invoice>[];
    final paidInvoices = <Invoice>[];
    final topPriorityInvoices = <_RankedInvoice>[];
    final overdueHighlights = <_RankedInvoice>[];
    final dueSoonHighlights = <_RankedInvoice>[];
    final recentActivity = <Invoice>[];

    for (final invoice in invoices) {
      final isPaid = invoice.status == InvoiceStatus.paid;
      final isOverdue =
          !isPaid &&
          (invoice.status == InvoiceStatus.overdue ||
              invoice.dueDate.isBefore(now));
      final isDueSoon =
          !isPaid &&
          !isOverdue &&
          invoice.dueDate.difference(now) <= const Duration(hours: 24);

      if (isPaid) {
        paidInvoices.add(invoice);
      } else if (isOverdue) {
        overdueInvoices.add(invoice);
      } else if (isDueSoon) {
        dueSoonInvoices.add(invoice);
      } else {
        pendingInvoices.add(invoice);
      }

      _insertSortedLimited<Invoice>(
        recentActivity,
        invoice,
        5,
        _compareRecentActivity,
      );

      if (isPaid) {
        continue;
      }

      final rankedInvoice = _RankedInvoice(
        invoice: invoice,
        score: _buildPriorityScore(
          invoice: invoice,
          now: now,
          isOverdue: isOverdue,
          isDueSoon: isDueSoon,
        ),
        isOverdue: isOverdue,
        isDueSoon: isDueSoon,
        dueLabel: _formatInvoiceDueLabel(
          invoice: invoice,
          now: now,
          isOverdue: isOverdue,
        ),
      );

      _insertSortedLimited<_RankedInvoice>(
        topPriorityInvoices,
        rankedInvoice,
        2,
        _compareRankedInvoices,
      );

      if (isOverdue) {
        _insertSortedLimited<_RankedInvoice>(
          overdueHighlights,
          rankedInvoice,
          2,
          _compareRankedInvoices,
        );
      }

      if (isDueSoon) {
        _insertSortedLimited<_RankedInvoice>(
          dueSoonHighlights,
          rankedInvoice,
          2,
          _compareRankedInvoices,
        );
      }
    }

    final totals = _DashboardTotals.fromInvoices(invoices);
    final unpaidCount =
        overdueInvoices.length +
        dueSoonInvoices.length +
        pendingInvoices.length;

    final urgency = invoices.isEmpty
        ? _DashboardUrgency.empty
        : overdueInvoices.isNotEmpty
        ? _DashboardUrgency.overdue
        : dueSoonInvoices.isNotEmpty
        ? _DashboardUrgency.dueSoon
        : _DashboardUrgency.calm;

    final focusMode = _resolveDashboardFocusMode(
      now: now,
      adaptiveState: adaptiveState,
      hasUnpaidInvoices: unpaidCount > 0,
    );

    final prioritySection = switch (urgency) {
      _DashboardUrgency.overdue => _PrioritySectionData.overdue(
        overdueHighlights,
        totalUnpaid: totals.totalUnpaid,
        ignoredReminderCount: adaptiveState.ignoredReminderCount,
        hasRecentResolution: adaptiveState.hasRecentResolution,
        currencyCode: currencyCode,
      ),
      _DashboardUrgency.dueSoon => _PrioritySectionData.dueSoon(
        dueSoonHighlights,
        totalUnpaid: totals.totalUnpaid,
        ignoredReminderCount: adaptiveState.ignoredReminderCount,
        hasRecentResolution: adaptiveState.hasRecentResolution,
        currencyCode: currencyCode,
      ),
      _DashboardUrgency.empty || _DashboardUrgency.calm => null,
    };

    final suggestions = _buildDashboardSuggestions(
      topPriorityInvoices: topPriorityInvoices,
      overdueInvoices: overdueInvoices,
      dueSoonInvoices: dueSoonInvoices,
      pendingInvoices: pendingInvoices,
      totals: totals,
      adaptiveState: adaptiveState,
      reminderCount: reminderCount,
      focusMode: focusMode,
      currencyCode: currencyCode,
    );

    final emptySubtitle = clientCount > 0
        ? 'Start billing your clients with your first invoice'
        : 'Create your first invoice to get started';

    final animationKey = [
      urgency.name,
      focusMode.name,
      adaptiveState.ignoredReminderCount,
      reminderCount,
      clientCount,
      ...topPriorityInvoices.map((item) => item.invoice.id),
      ...suggestions.map((item) => item.id),
      ...recentActivity.map((item) => item.id),
    ].join('|');

    return _DashboardViewModel(
      totals: totals,
      overdueInvoices: overdueInvoices,
      dueSoonInvoices: dueSoonInvoices,
      pendingInvoices: pendingInvoices,
      paidInvoices: paidInvoices,
      prioritySection: prioritySection,
      topPriorityInvoices: topPriorityInvoices,
      recentActivity: recentActivity,
      reminder: _SmartReminderData.fromPriority(
        topPriorityInvoices.isEmpty ? null : topPriorityInvoices.first,
        adaptiveState: adaptiveState,
        reminderCount: reminderCount,
      ),
      suggestions: suggestions,
      emptySubtitle: emptySubtitle,
      focusMode: focusMode,
      urgency: urgency,
      animationKey: animationKey,
    );
  }
}

class _PrioritySectionData {
  const _PrioritySectionData({
    required this.title,
    required this.summary,
    required this.invoices,
    required this.ctaLabel,
    required this.ctaInvoiceId,
    required this.icon,
    required this.tint,
  });

  final String title;
  final String summary;
  final List<_RankedInvoice> invoices;
  final String ctaLabel;
  final String? ctaInvoiceId;
  final IconData icon;
  final Color tint;

  factory _PrioritySectionData.overdue(
    List<_RankedInvoice> invoices, {
    required double totalUnpaid,
    required int ignoredReminderCount,
    required bool hasRecentResolution,
    String currencyCode = 'USD',
  }) {
    final leadClient = invoices.isEmpty
        ? 'Top overdue invoice'
        : invoices.first.invoice.clientName;

    String summary;
    if (ignoredReminderCount >= 2) {
      summary =
          '$leadClient still needs attention. ${AppFormatters.currency(totalUnpaid, currencyCode: currencyCode)} remains at risk.';
    } else if (hasRecentResolution) {
      summary = 'You are catching up. $leadClient is the next follow-up.';
    } else if (invoices.length > 1) {
      summary =
          '$leadClient and ${invoices.length - 1} more overdue invoices need attention.';
    } else {
      summary = '$leadClient needs a reminder right away.';
    }

    return _PrioritySectionData(
      title: 'Action Required',
      summary: summary,
      invoices: invoices,
      ctaLabel: ignoredReminderCount >= 2
          ? 'Send WhatsApp Reminder Now'
          : 'Send WhatsApp Reminder',
      ctaInvoiceId: invoices.isEmpty ? null : invoices.first.invoice.id,
      icon: Icons.priority_high_rounded,
      tint: AppColors.danger,
    );
  }

  factory _PrioritySectionData.dueSoon(
    List<_RankedInvoice> invoices, {
    required double totalUnpaid,
    required int ignoredReminderCount,
    required bool hasRecentResolution,
    String currencyCode = 'USD',
  }) {
    final leadClient = invoices.isEmpty
        ? 'Upcoming invoice'
        : invoices.first.invoice.clientName;

    String summary;
    if (hasRecentResolution) {
      summary = 'You are ahead of the curve. Keep $leadClient on track.';
    } else if (totalUnpaid >= 2500) {
      summary =
          '${AppFormatters.currency(totalUnpaid, currencyCode: currencyCode)} is due soon. Start with $leadClient.';
    } else if (ignoredReminderCount >= 2) {
      summary = '$leadClient is coming due and still needs a follow-up.';
    } else if (invoices.length > 1) {
      summary = '${invoices.length} invoices are due within 24 hours.';
    } else {
      summary = '$leadClient is due within the next 24 hours.';
    }

    return _PrioritySectionData(
      title: 'Due Soon',
      summary: summary,
      invoices: invoices,
      ctaLabel: 'Send WhatsApp Reminder',
      ctaInvoiceId: invoices.isEmpty ? null : invoices.first.invoice.id,
      icon: Icons.schedule_rounded,
      tint: AppColors.warning,
    );
  }
}

class _RankedInvoice {
  const _RankedInvoice({
    required this.invoice,
    required this.score,
    required this.isOverdue,
    required this.isDueSoon,
    required this.dueLabel,
  });

  final Invoice invoice;
  final double score;
  final bool isOverdue;
  final bool isDueSoon;
  final String dueLabel;
}

class _SmartReminderData {
  const _SmartReminderData({
    required this.headline,
    required this.detail,
    required this.invoiceId,
  });

  final String headline;
  final String detail;
  final String? invoiceId;

  factory _SmartReminderData.fromPriority(
    _RankedInvoice? invoice, {
    required AdaptiveSystemState adaptiveState,
    required int reminderCount,
  }) {
    if (invoice == null) {
      return const _SmartReminderData(
        headline: 'No reminders needed right now',
        detail: 'Create an invoice to start tracking follow-ups.',
        invoiceId: null,
      );
    }

    final clientName = invoice.invoice.clientName.isEmpty
        ? 'this client'
        : invoice.invoice.clientName;

    final headline =
        adaptiveState.ignoredReminderCount >= 2 && invoice.isOverdue
        ? 'Follow up again with $clientName'
        : 'Reminder needed for $clientName';
    final detail = reminderCount == 0 && !invoice.isOverdue
        ? 'Send your first reminder • ${AppFormatters.currency(invoice.invoice.amount, currencyCode: invoice.invoice.currencyCode)}'
        : '${invoice.dueLabel} • ${AppFormatters.currency(invoice.invoice.amount, currencyCode: invoice.invoice.currencyCode)}';

    return _SmartReminderData(
      headline: headline,
      detail: detail,
      invoiceId: invoice.invoice.id,
    );
  }
}

_DashboardFocusMode _resolveDashboardFocusMode({
  required DateTime now,
  required AdaptiveSystemState adaptiveState,
  required bool hasUnpaidInvoices,
}) {
  final inactiveDays = adaptiveState.inactiveDays;
  if (inactiveDays != null && inactiveDays >= 3 && hasUnpaidInvoices) {
    return _DashboardFocusMode.followUp;
  }

  if (now.hour >= 17 && hasUnpaidInvoices) {
    return _DashboardFocusMode.pending;
  }

  return _DashboardFocusMode.overview;
}

List<_DashboardSuggestion> _buildDashboardSuggestions({
  required List<_RankedInvoice> topPriorityInvoices,
  required List<Invoice> overdueInvoices,
  required List<Invoice> dueSoonInvoices,
  required List<Invoice> pendingInvoices,
  required _DashboardTotals totals,
  required AdaptiveSystemState adaptiveState,
  required int reminderCount,
  required _DashboardFocusMode focusMode,
  String currencyCode = 'USD',
}) {
  final suggestions = <_DashboardSuggestion>[];
  final topPriority = topPriorityInvoices.isEmpty
      ? null
      : topPriorityInvoices.first;
  final unpaidCount =
      overdueInvoices.length + dueSoonInvoices.length + pendingInvoices.length;

  void addSuggestion(_DashboardSuggestion suggestion) {
    if (suggestions.length >= 2) {
      return;
    }
    final exists = suggestions.any((item) => item.id == suggestion.id);
    if (!exists) {
      suggestions.add(suggestion);
    }
  }

  final inactiveDays = adaptiveState.inactiveDays;
  if (inactiveDays != null && inactiveDays >= 3 && topPriority != null) {
    addSuggestion(
      _DashboardSuggestion(
        id: 'inactive-follow-up',
        title: 'You have not followed up in $inactiveDays days',
        detail: '${topPriority.invoice.clientName} still needs attention.',
        icon: Icons.update_rounded,
        action: _DashboardSuggestionAction.sendReminder,
        invoiceId: topPriority.invoice.id,
      ),
    );
  }

  if (overdueInvoices.isNotEmpty && topPriority != null) {
    addSuggestion(
      _DashboardSuggestion(
        id: 'overdue-summary',
        title: '${overdueInvoices.length} invoices are overdue',
        detail: 'Start with ${topPriority.invoice.clientName}.',
        icon: Icons.priority_high_rounded,
        action: _DashboardSuggestionAction.sendReminder,
        invoiceId: topPriority.invoice.id,
      ),
    );
  }

  if (reminderCount == 0 && unpaidCount > 0 && topPriority != null) {
    addSuggestion(
      _DashboardSuggestion(
        id: 'first-reminder',
        title: 'Send your first reminder',
        detail: 'Stay ahead before invoices slip further overdue.',
        icon: Icons.notifications_active_outlined,
        action: _DashboardSuggestionAction.sendReminder,
        invoiceId: topPriority.invoice.id,
      ),
    );
  }

  if (totals.totalUnpaid >= 2500) {
    addSuggestion(
      _DashboardSuggestion(
        id: 'monetary-risk',
        title: '${AppFormatters.currency(totals.totalUnpaid, currencyCode: currencyCode)} is still unpaid',
        detail: 'Review payments to reduce your cash-risk exposure.',
        icon: Icons.account_balance_wallet_outlined,
        action: _DashboardSuggestionAction.reviewPayments,
      ),
    );
  }

  switch (focusMode) {
    case _DashboardFocusMode.overview:
      if (unpaidCount > 0) {
        addSuggestion(
          _DashboardSuggestion(
            id: 'morning-overview',
            title: 'Morning overview',
            detail: '$unpaidCount invoices need attention today.',
            icon: Icons.wb_sunny_outlined,
            action: _DashboardSuggestionAction.reviewPayments,
          ),
        );
      }
    case _DashboardFocusMode.pending:
      if (unpaidCount > 0) {
        addSuggestion(
          _DashboardSuggestion(
            id: 'evening-follow-up',
            title: 'Evening follow-up',
            detail: 'Close the day by reviewing pending payments.',
            icon: Icons.nights_stay_outlined,
            action: _DashboardSuggestionAction.reviewPayments,
          ),
        );
      }
    case _DashboardFocusMode.followUp:
      if (topPriority != null) {
        addSuggestion(
          _DashboardSuggestion(
            id: 'focus-follow-up',
            title: '${topPriority.invoice.clientName} has not paid yet',
            detail: topPriority.dueLabel,
            icon: Icons.mark_email_unread_outlined,
            action: _DashboardSuggestionAction.sendReminder,
            invoiceId: topPriority.invoice.id,
          ),
        );
      }
  }

  return suggestions;
}

int _effectiveOverdueCount(List<Invoice> invoices) {
  final now = DateTime.now();
  var count = 0;
  for (final invoice in invoices) {
    if (invoice.status == InvoiceStatus.paid) {
      continue;
    }
    if (invoice.status == InvoiceStatus.overdue ||
        invoice.dueDate.isBefore(now)) {
      count++;
    }
  }
  return count;
}

double _buildPriorityScore({
  required Invoice invoice,
  required DateTime now,
  required bool isOverdue,
  required bool isDueSoon,
}) {
  final amountWeight = (invoice.amount / 125).clamp(0.0, 40.0);
  final hoursSinceCreated = now
      .difference(invoice.createdAt)
      .inHours
      .toDouble();
  final recencyWeight = (24 - (hoursSinceCreated / 6)).clamp(0.0, 24.0);

  return (isOverdue ? 100.0 : 0.0) +
      (isDueSoon ? 70.0 : 0.0) +
      amountWeight +
      recencyWeight;
}

String _formatInvoiceDueLabel({
  required Invoice invoice,
  required DateTime now,
  required bool isOverdue,
}) {
  final difference = invoice.dueDate.difference(now);

  if (isOverdue) {
    final overdueDays = difference.inDays.abs().clamp(0, 9999);
    return 'Overdue by $overdueDays day${overdueDays == 1 ? '' : 's'}';
  }

  final dueHours = difference.inHours.clamp(1, 9999);
  return 'Due in $dueHours h';
}

void _insertSortedLimited<T>(
  List<T> target,
  T item,
  int limit,
  int Function(T a, T b) compare,
) {
  target.add(item);
  target.sort(compare);
  if (target.length > limit) {
    target.removeRange(limit, target.length);
  }
}

int _compareRankedInvoices(_RankedInvoice a, _RankedInvoice b) {
  final scoreCompare = b.score.compareTo(a.score);
  if (scoreCompare != 0) {
    return scoreCompare;
  }

  final amountCompare = b.invoice.amount.compareTo(a.invoice.amount);
  if (amountCompare != 0) {
    return amountCompare;
  }

  return a.invoice.dueDate.compareTo(b.invoice.dueDate);
}

int _compareRecentActivity(Invoice a, Invoice b) {
  return b.createdAt.compareTo(a.createdAt);
}

class DashboardAvatar extends StatefulWidget {
  const DashboardAvatar({super.key});

  @override
  State<DashboardAvatar> createState() => _DashboardAvatarState();
}

class _DashboardAvatarState extends State<DashboardAvatar> {
  static const String _avatarPathKey = 'dashboard_avatar_path';
  static final ImagePicker _picker = ImagePicker();

  File? _avatarImage;
  bool _avatarPressed = false;
  bool _isPickingAvatar = false;

  @override
  void initState() {
    super.initState();
    _restoreAvatar();
  }

  Future<void> _restoreAvatar() async {
    final storedPath = HiveStorage.settingsBox.get(_avatarPathKey) as String?;
    if (storedPath == null) return;
    final file = File(storedPath);
    if (!file.existsSync()) {
      await HiveStorage.settingsBox.delete(_avatarPathKey);
      return;
    }
    if (!mounted) return;
    setState(() => _avatarImage = file);
  }

  Future<void> _openProfileSheet() async {
    if (!mounted || _isPickingAvatar) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.backgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.account_circle_outlined),
                  title: const Text('Profile Photo'),
                  subtitle: Text(
                    _avatarImage == null
                        ? 'No photo selected'
                        : 'Photo selected',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Take Photo'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _pickAvatar(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choose from Gallery'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _pickAvatar(ImageSource.gallery);
                  },
                ),
                if (_avatarImage != null)
                  ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('Remove Photo'),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _clearAvatar();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _clearAvatar() async {
    await HiveStorage.settingsBox.delete(_avatarPathKey);
    if (!mounted) return;
    setState(() => _avatarImage = null);
  }

  Future<void> _pickAvatar(ImageSource source) async {
    if (_isPickingAvatar) return;
    setState(() => _isPickingAvatar = true);
    try {
      PermissionStatus status;
      if (source == ImageSource.camera) {
        status = await Permission.camera.request();
      } else {
        status = await Permission.photos.request();
        if (!status.isGranted && !status.isLimited) {
          status = await Permission.storage.request();
        }
      }
      final granted = status.isGranted || status.isLimited;
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Permission is required to update your avatar.',
            ),
            action: status.isPermanentlyDenied || status.isRestricted
                ? SnackBarAction(label: 'Settings', onPressed: openAppSettings)
                : null,
          ),
        );
        return;
      }
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 1200,
      );
      if (file == null || !mounted) return;
      setState(() => _avatarImage = File(file.path));
      await HiveStorage.settingsBox.put(_avatarPathKey, file.path);
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open image picker right now.')),
      );
    } finally {
      if (mounted) setState(() => _isPickingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _avatarPressed ? 0.97 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeInOut,
      child: GestureDetector(
        onTapDown: (_) {
          if (!_avatarPressed) setState(() => _avatarPressed = true);
        },
        onTapUp: (_) {
          if (_avatarPressed) setState(() => _avatarPressed = false);
        },
        onTapCancel: () {
          if (_avatarPressed) setState(() => _avatarPressed = false);
        },
        onTap: _openProfileSheet,
        child: Semantics(
          button: true,
          label: 'Open profile photo options',
          child: Tooltip(
            message: 'Profile photo',
            child: CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.cardBackground,
              child: _isPickingAvatar
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _avatarImage == null
                  ? const Icon(
                      Icons.person_outline,
                      color: AppColors.textPrimary,
                    )
                  : ClipOval(
                      child: Image.file(
                        _avatarImage!,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
