import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/components/primary_button.dart';
import '../../domain/entities/invoice.dart';
import '../controllers/invoices_controller.dart';

class InvoiceDetailScreen extends ConsumerWidget {
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoiceState = ref.watch(invoiceDetailProvider(invoiceId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Detail'),
        actions: [
          IconButton(
            onPressed: () => EditInvoiceRoute(invoiceId).push(context),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: invoiceState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text(error.toString())),
        data: (invoice) {
          if (invoice == null) {
            return const Center(child: Text('Invoice not found'));
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            children: [
              Text(
                invoice.clientName,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                invoice.service,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _InfoRow(
                label: 'Amount',
                value: AppFormatters.currency(invoice.amount),
              ),
              _InfoRow(
                label: 'Due Date',
                value: AppFormatters.shortDate(invoice.dueDate),
              ),
              _InfoRow(label: 'Status', value: invoice.status.label),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Send Reminder',
                icon: Icons.send_rounded,
                onPressed: () => ReminderFlowRoute(invoice.id).push(context),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: invoice.status == InvoiceStatus.paid
                    ? null
                    : () async {
                        await ref
                            .read(invoicesControllerProvider.notifier)
                            .updateInvoice(
                              invoice.copyWith(status: InvoiceStatus.paid),
                            );
                        ref.invalidate(invoiceDetailProvider(invoice.id));
                      },
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Mark as Paid'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value),
        ],
      ),
    );
  }
}
