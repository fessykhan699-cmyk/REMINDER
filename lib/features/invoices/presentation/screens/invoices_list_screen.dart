import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/components/app_scaffold.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../subscription/domain/entities/subscription_state.dart';
import '../../../subscription/presentation/controllers/subscription_controller.dart';
import '../../../subscription/presentation/widgets/upgrade_prompt_sheet.dart';
import '../../../subscription/presentation/widgets/usage_limit_nudge_card.dart';
import '../providers/invoice_search_filter_provider.dart';
import '../controllers/invoices_controller.dart';
import '../../../../data/services/invoice_search_filter_service.dart';
import '../../../../data/services/overdue_flip_service.dart';
import '../widgets/invoice_tile.dart';
import '../../../../shared/services/csv_export_service.dart';
import '../../../clients/presentation/controllers/clients_controller.dart';
import '../../../../data/services/payment_service.dart';
import '../../../../shared/components/glass_card.dart';

class InvoicesListScreen extends ConsumerStatefulWidget {
  const InvoicesListScreen({super.key});

  @override
  ConsumerState<InvoicesListScreen> createState() => _InvoicesListScreenState();
}

class _InvoicesListScreenState extends ConsumerState<InvoicesListScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();

  int _visibleItemCount = 20;

  late final AnimationController _entryCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  )..forward();

  @override
  void initState() {
    super.initState();
    // Scan and flip overdue status on list view
    OverdueFlipService().flipOverdueInvoices();
  }

  @override
  void dispose() {
    _searchController.dispose();
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


  Future<void> _openCreateInvoice() async {
    final decision = await ref
        .read(subscriptionGatekeeperProvider)
        .evaluate(SubscriptionGateFeature.createInvoice);
    if (!decision.isAllowed) {
      if (!mounted) return;
      final upgraded = await promptUpgradeForDecision(context, decision);
      if (!upgraded || !mounted) return;
    }
    if (!mounted) return;
    await const CreateInvoiceRoute().push(context);
  }

  Future<void> _exportInvoices() async {
    final decision = await ref
        .read(subscriptionGatekeeperProvider)
        .evaluate(SubscriptionGateFeature.exportCsv);
    if (!decision.isAllowed) {
      if (!mounted) return;
      final upgraded = await promptUpgradeForDecision(context, decision);
      if (!upgraded || !mounted) return;
    }

    // Pro-only feature from here
    try {
      final invoices = ref.read(filteredInvoicesProvider);
      if (invoices.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No invoices to export')),
        );
        return;
      }

      final clientsAsync = ref.read(clientsControllerProvider);
      final clients = clientsAsync.valueOrNull ?? [];

      await ref.read(csvExportServiceProvider).exportInvoicesToCsv(
        invoices: invoices,
        clients: clients,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  void _loadMoreInvoices(int totalCount) {
    setState(() {
      _visibleItemCount = math.min(totalCount, _visibleItemCount + 20);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subscription =
        ref.watch(subscriptionControllerProvider).valueOrNull ??
        const SubscriptionState.free();
    final usage = ref.watch(subscriptionUsageProvider);

    final filteredInvoices = ref.watch(filteredInvoicesProvider);
    final allInvoicesAsync = ref.watch(invoicesControllerProvider);
    final allInvoices = allInvoicesAsync.valueOrNull ?? [];
    
    final totalRevenue = ref.watch(totalRevenueProvider);
    final pendingBalance = ref.watch(pendingBalanceProvider);
    
    final query = ref.watch(invoiceSearchQueryProvider);
    final statusFilter = ref.watch(invoiceStatusFilterProvider);
    final fromDate = ref.watch(invoiceFromDateFilterProvider);
    final toDate = ref.watch(invoiceToDatFilterProvider);
    
    final isFiltering = query.isNotEmpty || statusFilter != null || fromDate != null || toDate != null;
    final availableStatuses = InvoiceSearchFilterService.getAvailableStatuses(allInvoices);
    
    final visibleCount = math.min(filteredInvoices.length, _visibleItemCount);
    final visibleInvoices = filteredInvoices.take(visibleCount).toList(growable: false);
    final showNudge = !subscription.isPro;
    final hasMore = filteredInvoices.length > visibleCount;

    return AppScaffold(
      extendBody: true,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Header ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  spacingMD,
                  spacingMD,
                  spacingMD,
                  spacingLG,
                ),
                child: _staggeredItem(
                  index: 0,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          'Invoices',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Export to CSV',
                        onPressed: _exportInvoices,
                        style: IconButton.styleFrom(
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          foregroundColor: AppColors.textPrimary,
                          shape: const CircleBorder(),
                        ),
                        icon: const Icon(Icons.file_download_outlined, size: 20),
                      ),
                      const SizedBox(width: spacingSM),
                      IconButton(
                        tooltip: 'New Invoice',
                        onPressed: _openCreateInvoice,
                        style: IconButton.styleFrom(
                          backgroundColor:
                              AppColors.accent.withValues(alpha: 0.14),
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

            // ── Revenue Summary (Advanced Totals) ──
            if (allInvoices.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: spacingMD),
                  child: _staggeredItem(
                    index: 1,
                    child: _RevenueSummary(
                      revenue: totalRevenue,
                      pending: pendingBalance,
                      isPro: subscription.isPro,
                      onUpgrade: () => const UpgradeToProRoute().push(context),
                    ),
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: spacingLG)),

            // ── Search & Filter ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: spacingMD),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (val) => ref.read(invoiceSearchQueryProvider.notifier).state = val,
                      decoration: InputDecoration(
                        hintText: 'Search by client, invoice number, or item',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  ref.read(invoiceSearchQueryProvider.notifier).state = "";
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                    ),
                    const SizedBox(height: spacingSM),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            initialValue: statusFilter,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                              filled: true,
                              fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            hint: const Text('Status'),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('All')),
                              ...availableStatuses.map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s[0].toUpperCase() + s.substring(1)),
                              )),
                            ],
                            onChanged: (val) => ref.read(invoiceStatusFilterProvider.notifier).state = val,
                          ),
                        ),
                        const SizedBox(width: spacingSM),
                        InkWell(
                          onTap: () async {
                            final picked = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                              initialDateRange: fromDate != null && toDate != null
                                  ? DateTimeRange(start: fromDate, end: toDate)
                                  : null,
                            );
                            if (picked != null) {
                              ref.read(invoiceFromDateFilterProvider.notifier).state = picked.start;
                              ref.read(invoiceToDatFilterProvider.notifier).state = picked.end;
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.date_range, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  fromDate != null && toDate != null
                                      ? '${fromDate.day}/${fromDate.month}'
                                      : 'Date',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (fromDate != null || toDate != null)
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              ref.read(invoiceFromDateFilterProvider.notifier).state = null;
                              ref.read(invoiceToDatFilterProvider.notifier).state = null;
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: spacingLG),
                  ],
                ),
              ),
            ),

            if (filteredInvoices.isEmpty)
              SliverFillRemaining(
                child: isFiltering
                    ? Center(
                        child: Text(
                          'No invoices match your search',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : AppEmptyState(
                        title: 'No invoices yet',
                        message: 'Create your first invoice in seconds.',
                        action: FilledButton.icon(
                          onPressed: _openCreateInvoice,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Create Invoice'),
                        ),
                      ),
              )
            else ...[
              // ── Usage nudge ──
              if (showNudge)
                SliverToBoxAdapter(
                  child: _staggeredItem(
                    index: 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: spacingMD,
                      ),
                      child: UsageLimitNudgeCard(
                        usage: usage,
                        focus: UsageLimitFocus.invoices,
                        onUpgrade: () {
                          const UpgradeToProRoute().push(context);
                        },
                      ),
                    ),
                  ),
                ),

              // ── Invoice list ──
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final invoice = visibleInvoices[index];
                    return _staggeredItem(
                      index: index + (showNudge ? 2 : 1),
                      child: InvoiceTile(
                        key: ValueKey(invoice.id),
                        invoice: invoice,
                        onTap: () async {
                          final result = await InvoiceDetailRoute(invoice.id)
                              .push<bool>(context);
                          if (mounted && result == true) {
                            // refresh logic if needed, but provider handles it
                          }
                        },
                      ),
                    );
                  },
                  childCount: visibleInvoices.length,
                ),
              ),

              // ── Load more ──
              if (hasMore)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: appCardPadding,
                    child: Center(
                      child: TextButton(
                        onPressed: () => _loadMoreInvoices(filteredInvoices.length),
                        child: const Text('Load more'),
                      ),
                    ),
                  ),
                ),

              // ── Bottom padding ──
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.of(context).padding.bottom + 100,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RevenueSummary extends StatelessWidget {
  const _RevenueSummary({
    required this.revenue,
    required this.pending,
    required this.isPro,
    required this.onUpgrade,
  });

  final double revenue;
  final double pending;
  final bool isPro;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GlassCard(
      padding: const EdgeInsets.all(spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Financial Overview',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              if (!isPro)
                GestureDetector(
                  onTap: onUpgrade,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'PRO',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: spacingMD),
          Row(
            children: [
              _StatItem(
                label: 'Total Revenue',
                value: isPro ? '\$${revenue.toStringAsFixed(2)}' : '\$ ••••',
                color: Colors.greenAccent,
              ),
              const SizedBox(width: spacingLG),
              _StatItem(
                label: 'Pending',
                value: isPro ? '\$${pending.toStringAsFixed(2)}' : '\$ ••••',
                color: Colors.orangeAccent,
              ),
            ],
          ),
          if (!isPro) ...[
            const SizedBox(height: spacingMD),
            Text(
              'Upgrade to Pro to see detailed revenue and pending balance analysis.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}
