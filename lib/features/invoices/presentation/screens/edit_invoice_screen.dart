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
    if (_invoice != null) return;
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
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return null;
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
    if (!mounted || picked == null) return;
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

      await _saveInvoice(
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

      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Invoice saved')));
      shouldResetSavingState = false;
      navigator.pop();
    } on SubscriptionGateException catch (error) {
      if (!mounted) return;
      await promptUpgradeForDecision(context, error.decision);
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to save invoice')),
      );
    } finally {
      if (mounted && shouldResetSavingState) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveInvoice(Invoice updated) async {
    await ref.read(invoicesControllerProvider.notifier).updateInvoice(updated);
  }

  Future<void> _deleteInvoice() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Invoice'),
        content: const Text('Are you sure you want to delete this invoice?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref
          .read(invoicesControllerProvider.notifier)
          .deleteInvoice(widget.invoiceId);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to delete invoice')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(invoiceDetailProvider(widget.invoiceId));

    return Scaffold(
      resizeToAvoidBottomInset: true,
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 140,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 16),
                        AppInputField(
                          controller: _clientNameController,
                          label: 'Client Name',
                        ),
                        const SizedBox(height: 12),
                        AppInputField(
                          controller: _serviceController,
                          label: 'Service',
                        ),
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
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Discounted totals are a Pro feature.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
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
                          decoration: const InputDecoration(
                            labelText: 'Status',
                          ),
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
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _deleteInvoice,
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            label: const Text(
                              'Delete Invoice',
                              style: TextStyle(color: Colors.red),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: Colors.red,
                                width: 1.5,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        PrimaryButton(
                          label: 'Save Changes',
                          isLoading: _isSaving,
                          onPressed: _save,
                        ),
                        const SizedBox(height: 140),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
