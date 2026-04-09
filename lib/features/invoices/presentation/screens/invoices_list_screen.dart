import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/storage/hive_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/components/app_scaffold.dart';
import '../../../../shared/services/invoice_status_service.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../subscription/domain/entities/subscription_state.dart';
import '../../../subscription/presentation/controllers/subscription_controller.dart';
import '../../../subscription/presentation/widgets/upgrade_prompt_sheet.dart';
import '../../../subscription/presentation/widgets/usage_limit_nudge_card.dart';
import '../../data/models/invoice_model.dart';
import '../../domain/entities/invoice.dart';
import '../widgets/invoice_tile.dart';

class InvoicesListScreen extends ConsumerStatefulWidget {
  const InvoicesListScreen({super.key});

  @override
  ConsumerState<InvoicesListScreen> createState() => _InvoicesListScreenState();
}

class _InvoicesListScreenState extends ConsumerState<InvoicesListScreen>
    with SingleTickerProviderStateMixin {
  static const InvoiceStatusService _statusService = InvoiceStatusService();

  int _visibleItemCount = 20;

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

  List<Invoice> _sortedInvoices(Box<InvoiceModel> box) {
    final now = DateTime.now();
    final invoices = box.values.toList();
    invoices.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return invoices
        .map(
          (invoice) => invoice.copyWith(
            status: _statusService.resolveStatus(invoice, now: now),
            paymentLink: invoice.normalizedPaymentLink,
          ),
        )
        .toList(growable: false);
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

    return AppScaffold(
      extendBody: true,
      body: SafeArea(
        child: ValueListenableBuilder<Box<InvoiceModel>>(
          valueListenable: HiveStorage.invoicesBox.listenable(),
          builder: (context, box, _) {
            final invoices = _sortedInvoices(box);
            final visibleCount = math.min(invoices.length, _visibleItemCount);
            final visibleInvoices = invoices.take(visibleCount).toList(growable: false);
            final showNudge = !subscription.isPro;
            final hasMore = invoices.length > visibleCount;

            return CustomScrollView(
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

                if (invoices.isEmpty)
                  SliverFillRemaining(
                    child: AppEmptyState(
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
                              await InvoiceDetailRoute(invoice.id)
                                  .push<bool>(context);
                              if (mounted) setState(() {});
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
                            onPressed: () => _loadMoreInvoices(invoices.length),
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
            );
          },
        ),
      ),
    );
  }
}
