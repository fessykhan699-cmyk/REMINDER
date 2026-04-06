import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../shared/components/app_input_field.dart';
import '../../../../shared/components/primary_button.dart';
import '../../../subscription/domain/entities/subscription_state.dart';
import '../../../subscription/presentation/controllers/subscription_controller.dart';
import '../../../subscription/presentation/widgets/upgrade_prompt_sheet.dart';
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
  final _dueDateController = TextEditingController();
  final _discountController = TextEditingController();
  final _notesController = TextEditingController();
  final _paymentLinkController = TextEditingController();

  Invoice? _invoice;
  DateTime? _dueDate;
  InvoiceStatus _status = InvoiceStatus.draft;
  bool _isSaving = false;

  @override
  void dispose() {
    _clientNameController.dispose();
    _serviceController.dispose();
    _amountController.dispose();
    _dueDateController.dispose();
    _discountController.dispose();
    _notesController.dispose();
    _paymentLinkController.dispose();
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
    _dueDateController.text = AppFormatters.shortDate(invoice.dueDate);
    _discountController.text = invoice.discountAmount == 0
        ? ''
        : invoice.discountAmount.toStringAsFixed(2);
    _notesController.text = invoice.notes ?? '';
    _paymentLinkController.text = invoice.paymentLink ?? '';
  }

  String? _normalizedPaymentLink() {
    final trimmed = _paymentLinkController.text.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return null;
    }

    return trimmed;
  }

  Future<void> _pickDueDate() async {
    final initial = _dueDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      initialDate: initial,
    );

    if (!mounted || picked == null) {
      return;
    }

    setState(() => _dueDate = picked);
    _dueDateController.text = AppFormatters.shortDate(picked);
  }

  Future<void> _save() async {
    final source = _invoice;
    final dueDate = _dueDate;
    final amount = double.tryParse(_amountController.text.trim());
    final discountText = _discountController.text.trim();
    final discountAmount = discountText.isEmpty
        ? 0.0
        : double.tryParse(discountText);
    final paymentLink = _normalizedPaymentLink();

    if (source == null ||
        dueDate == null ||
        amount == null ||
        discountAmount == null) {
      return;
    }

    if (discountAmount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Discount must be zero or greater')),
      );
      return;
    }

    if (_paymentLinkController.text.trim().isNotEmpty && paymentLink == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid payment link')),
      );
      return;
    }

    setState(() => _isSaving = true);
    var shouldResetSavingState = true;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      if (discountAmount > 0) {
        await ref
            .read(subscriptionGatekeeperProvider)
            .ensureAllowed(SubscriptionGateFeature.advancedTotals);
      }

      final result = await _saveInvoice(
        source.copyWith(
          clientName: _clientNameController.text.trim(),
          service: _serviceController.text.trim(),
          amount: amount,
          dueDate: dueDate,
          status: _status,
          discountAmount: discountAmount,
          paymentLink: paymentLink,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        ),
      );

      if (!mounted) {
        return;
      }

      if (result == true) {
        messenger.showSnackBar(const SnackBar(content: Text('Invoice saved')));
        shouldResetSavingState = false;
        navigator.pop();
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Unable to save invoice')),
        );
      }
    } on SubscriptionGateException catch (error) {
      if (!mounted) {
        return;
      }

      await promptUpgradeForDecision(context, error.decision);
    } catch (_) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to save invoice')),
      );
    } finally {
      if (mounted && shouldResetSavingState) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<bool> _saveInvoice(Invoice updated) async {
    await ref.read(invoicesControllerProvider.notifier).updateInvoice(updated);
    return true;
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

          return SafeArea(
            child: ListView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).padding.bottom + 80,
              ),
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
                  controller: _dueDateController,
                  label: 'Due Date',
                  readOnly: true,
                  onTap: _pickDueDate,
                ),
                const SizedBox(height: 12),
                AppInputField(
                  controller: _paymentLinkController,
                  label: 'Payment Link',
                  hint: 'https://pay.example.com/invoice',
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                AppInputField(
                  controller: _discountController,
                  label: 'Discount (Pro)',
                  hint: '0.00',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Discounted totals are a Pro feature.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                AppInputField(
                  controller: _notesController,
                  label: 'Notes',
                  hint: 'Payment instructions or terms',
                  maxLines: 4,
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
            ),
          );
        },
      ),
    );
  }
}
