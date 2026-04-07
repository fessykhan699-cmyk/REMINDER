import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/storage/hive_storage.dart';
import '../../../../core/theme/app_spacing.dart';
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

class _InvoicesListScreenState extends ConsumerState<InvoicesListScreen> {
  static const InvoiceStatusService _statusService = InvoiceStatusService();

  int _visibleItemCount = 20;

  Widget _buildInvoicesList({
    required List<Invoice> invoices,
    required SubscriptionState subscription,
    required SubscriptionUsage usage,
    required bool hasMore,
    required VoidCallback onLoadMore,
  }) {
    final showNudge = !subscription.isPro;
    final itemCount = invoices.length + (showNudge ? 1 : 0) + (hasMore ? 1 : 0);

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      cacheExtent: 2,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 80,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (showNudge && index == 0) {
          return UsageLimitNudgeCard(
            usage: usage,
            focus: UsageLimitFocus.invoices,
            onUpgrade: () {
              const UpgradeToProRoute().push(context);
            },
          );
        }

        final dataIndex = index - (showNudge ? 1 : 0);
        if (hasMore && dataIndex == invoices.length) {
          return Padding(
            padding: appCardPadding,
            child: Center(
              child: TextButton(
                onPressed: onLoadMore,
                child: const Text('Load more'),
              ),
            ),
          );
        }

        final invoice = invoices[dataIndex];
        return InvoiceTile(
          invoice: invoice,
          onTap: () {
            debugPrint("LIST → OPEN DETAIL: ID = '${invoice.id}'");
            InvoiceDetailRoute(invoice.id).push(context);
          },
        );
      },
    );
  }

  List<Invoice> _sortedInvoices(Box<InvoiceModel> box) {
    final now = DateTime.now();
    final invoices = box.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

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
      if (!mounted) {
        return;
      }
      final upgraded = await promptUpgradeForDecision(context, decision);
      if (!upgraded || !mounted) {
        return;
      }
    }

    if (!mounted) {
      return;
    }
    await const CreateInvoiceRoute().push(context);
  }

  void _loadMoreInvoices(int totalCount) {
    setState(() {
      _visibleItemCount = math.min(totalCount, _visibleItemCount + 20);
    });
  }

  @override
  Widget build(BuildContext context) {
    final subscription =
        ref.watch(subscriptionControllerProvider).valueOrNull ??
        const SubscriptionState.free();
    final usage = ref.watch(subscriptionUsageProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices'),
        actions: [
          IconButton(
            tooltip: 'New Invoice',
            onPressed: _openCreateInvoice,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: SafeArea(
        child: ValueListenableBuilder<Box<InvoiceModel>>(
          valueListenable: HiveStorage.invoicesBox.listenable(),
          builder: (context, box, _) {
            debugPrint(
              "InvoicesListScreen: ValueListenableBuilder — box has ${box.length} invoices",
            );
            final invoices = _sortedInvoices(box);

            if (invoices.isEmpty) {
              return AppEmptyState(
                title: 'No invoices yet',
                message: 'Create your first invoice in seconds.',
                action: FilledButton.icon(
                  onPressed: _openCreateInvoice,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create Invoice'),
                ),
              );
            }

            final visibleCount = math.min(invoices.length, _visibleItemCount);
            final visibleInvoices = invoices
                .take(visibleCount)
                .toList(growable: false);

            return Column(
              children: [
                Expanded(
                  child: _buildInvoicesList(
                    invoices: visibleInvoices,
                    subscription: subscription,
                    usage: usage,
                    hasMore: invoices.length > visibleCount,
                    onLoadMore: () => _loadMoreInvoices(invoices.length),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
