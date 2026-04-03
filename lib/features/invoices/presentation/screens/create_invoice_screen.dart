import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../shared/components/app_input_field.dart';
import '../../../../shared/components/primary_button.dart';
import '../../domain/entities/invoice.dart';
import '../controllers/invoices_controller.dart';

class CreateInvoiceScreen extends ConsumerStatefulWidget {
  const CreateInvoiceScreen({super.key});

  @override
  ConsumerState<CreateInvoiceScreen> createState() =>
      _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends ConsumerState<CreateInvoiceScreen> {
  final _clientIdController = TextEditingController(text: 'client-1');
  final _clientNameController = TextEditingController();
  final _serviceController = TextEditingController();
  final _amountController = TextEditingController();

  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  bool _isSaving = false;

  @override
  void dispose() {
    _clientIdController.dispose();
    _clientNameController.dispose();
    _serviceController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      initialDate: _dueDate,
    );

    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    final clientId = _clientIdController.text.trim();
    final clientName = _clientNameController.text.trim();
    final service = _serviceController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());

    if (clientId.isEmpty ||
        clientName.isEmpty ||
        service.isEmpty ||
        amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide valid invoice details.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final invoice = Invoice(
        id: IdGenerator.nextId('inv'),
        clientId: clientId,
        clientName: clientName,
        service: service,
        amount: amount,
        dueDate: _dueDate,
        status: InvoiceStatus.pending,
        createdAt: DateTime.now(),
      );

      await ref
          .read(invoicesControllerProvider.notifier)
          .createInvoice(invoice);

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
    return Scaffold(
      appBar: AppBar(title: const Text('Create Invoice')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppInputField(controller: _clientIdController, label: 'Client ID'),
          const SizedBox(height: 12),
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
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          AppInputField(
            controller: TextEditingController(
              text: AppFormatters.shortDate(_dueDate),
            ),
            label: 'Due Date',
            readOnly: true,
            onTap: _pickDueDate,
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: 'Save Invoice',
            isLoading: _isSaving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
