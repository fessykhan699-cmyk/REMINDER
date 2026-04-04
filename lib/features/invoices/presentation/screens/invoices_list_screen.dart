import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../shared/widgets/app_async_state_view.dart';
import '../../../clients/presentation/controllers/clients_controller.dart';
import '../../../subscription/domain/entities/subscription_state.dart';
import '../../../subscription/presentation/controllers/subscription_controller.dart';
import '../../../subscription/presentation/widgets/upgrade_prompt_sheet.dart';
import '../../domain/entities/invoice.dart';
import '../controllers/invoices_controller.dart';
import '../widgets/invoice_tile.dart';

class InvoicesListScreen extends ConsumerWidget {
  const InvoicesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsState = ref.watch(clientsControllerProvider);
    final state = ref.watch(invoicesControllerProvider);
    final controller = ref.read(invoicesControllerProvider.notifier);
    final clientCount = clientsState.valueOrNull?.length ?? 0;
    final emptyTitle = clientCount > 0 ? 'Ready to bill' : 'No invoices yet';
    final emptyMessage = clientCount > 0
        ? 'Start billing your clients with your first invoice.'
        : 'Create your first invoice to start the reminder loop.';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices'),
        actions: [
          IconButton(
            tooltip: 'New Invoice',
            onPressed: () async {
              final decision = await ref
                  .read(subscriptionGatekeeperProvider)
                  .evaluate(SubscriptionGateFeature.createInvoice);
              if (!decision.isAllowed) {
                if (!context.mounted) {
                  return;
                }
                final upgraded = await promptUpgradeForDecision(
                  context,
                  decision,
                );
                if (!upgraded || !context.mounted) {
                  return;
                }
              }

              if (!context.mounted) {
                return;
              }
              await const CreateInvoiceRoute().push(context);
            },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: controller.loadInitial,
        child: AppAsyncStateView<List<Invoice>>(
          state: state,
          onRetry: controller.loadInitial,
          emptyTitle: emptyTitle,
          emptyMessage: emptyMessage,
          isEmpty: (data) => data.isEmpty,
          builder: (invoices) {
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
              itemCount: invoices.length + 1,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == invoices.length) {
                  if (!controller.hasMore) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton(
                      onPressed: controller.loadMore,
                      child: const Text('Load more'),
                    ),
                  );
                }

                final invoice = invoices[index];
                return InvoiceTile(
                  invoice: invoice,
                  onTap: () => InvoiceDetailRoute(invoice.id).push(context),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
