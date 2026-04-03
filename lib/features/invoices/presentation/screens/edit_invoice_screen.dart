import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../shared/components/app_input_field.dart';
import '../../../../shared/components/primary_button.dart';
import '../../domain/entities/invoice.dart';
import '../controllers/invoices_controller.dart';

class EditInvoiceScreen extends ConsumerStatefulWidget {
  const EditInvoiceScreen({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  ConsumerState<EditInvoiceScreen> createState() => _EditInvoiceScreenState();
}

class _EditInvoiceScreenState extends ConsumerState<EditInvoiceScreen> {
  final _clientNameController = TextEditingController();
  final _serviceController = TextEditingController();
  final _amountController = TextEditingController();

  Invoice? _invoice;
  DateTime? _dueDate;
  InvoiceStatus _status = InvoiceStatus.pending;
  bool _isSaving = false;

  @override
  void dispose() {
    _clientNameController.dispose();
    _serviceController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _hydrate(Invoice invoice) {
    if (_invoice != null) {
      return;
    }
    _invoice = invoice;
    _dueDate = invoice.dueDate;
    _status = invoice.status;
    _clientNameController.text = invoice.clientName;
    _serviceController.text = invoice.service;
    _amountController.text = invoice.amount.toStringAsFixed(2);
  }

  Future<void> _pickDueDate() async {
    final initial = _dueDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      initialDate: initial,
    );

    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _save() async {
    final source = _invoice;
    final dueDate = _dueDate;
    final amount = double.tryParse(_amountController.text.trim());

    if (source == null || dueDate == null || amount == null) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updated = source.copyWith(
        clientName: _clientNameController.text.trim(),
        service: _serviceController.text.trim(),
        amount: amount,
        dueDate: dueDate,
        status: _status,
      );

      await ref
          .read(invoicesControllerProvider.notifier)
          .updateInvoice(updated);

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(invoiceDetailProvider(widget.invoiceId));

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Invoice')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text(error.toString())),
        data: (invoice) {
          if (invoice == null) {
            return const Center(child: Text('Invoice not found'));
          }

          _hydrate(invoice);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              AppInputField(
                controller: _clientNameController,
                label: 'Client Name',
              ),
              const SizedBox(height: 12),
              AppInputField(controller: _serviceController, label: 'Service'),
              const SizedBox(height: 12),
              AppInputField(
                controller: _amountController,
                label: 'Amount',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),
              AppInputField(
                controller: TextEditingController(
                  text: AppFormatters.shortDate(_dueDate ?? invoice.dueDate),
                ),
                label: 'Due Date',
                readOnly: true,
                onTap: _pickDueDate,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<InvoiceStatus>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: InvoiceStatus.values
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(status.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _status = value);
                  }
                },
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                label: 'Save Changes',
                isLoading: _isSaving,
                onPressed: _save,
              ),
            ],
          );
        },
      ),
    );
  }
}
