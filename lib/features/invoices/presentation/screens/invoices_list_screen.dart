import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../shared/widgets/app_async_state_view.dart';
import '../../domain/entities/invoice.dart';
import '../controllers/invoices_controller.dart';
import '../widgets/invoice_tile.dart';

class InvoicesListScreen extends ConsumerWidget {
  const InvoicesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(invoicesControllerProvider);
    final controller = ref.read(invoicesControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Invoices')),
      body: RefreshIndicator(
        onRefresh: controller.loadInitial,
        child: AppAsyncStateView<List<Invoice>>(
          state: state,
          onRetry: controller.loadInitial,
          emptyTitle: 'No invoices yet',
          emptyMessage: 'Create your first invoice to start the reminder loop.',
          isEmpty: (data) => data.isEmpty,
          builder: (invoices) {
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
              itemCount: invoices.length + 1,
              separatorBuilder: (context, index) => const SizedBox(height: 4),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => const CreateInvoiceRoute().push(context),
        icon: const Icon(Icons.add),
        label: const Text('Create Invoice'),
      ),
    );
  }
}
