import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
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

      await ref
          .read(invoicesControllerProvider.notifier)
          .updateInvoice(
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

  Future<void> _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Invoice'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('invoices')
          .doc(widget.invoiceId)
          .delete();

      if (mounted) Navigator.pop(context, true);
    }
  }

  InputDecoration _inputDecoration({required String label, String? hint}) {
    final theme = Theme.of(context);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: theme.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      hintStyle: theme.textTheme.bodyMedium?.copyWith(
        color: theme.textTheme.bodySmall?.color,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: theme.colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: theme.colorScheme.error, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(invoiceDetailProvider(widget.invoiceId));
    final theme = Theme.of(context);

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
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Form Card ──
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: theme.colorScheme.outline.withValues(
                                  alpha: 0.08,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Invoice Details',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _clientNameController,
                                  decoration: _inputDecoration(
                                    label: 'Client Name',
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _serviceController,
                                  decoration: _inputDecoration(
                                    label: 'Service',
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _amountController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: _inputDecoration(label: 'Amount'),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _dueDateController,
                                  readOnly: true,
                                  onTap: _pickDueDate,
                                  decoration: _inputDecoration(
                                    label: 'Due Date',
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _paymentLinkController,
                                  keyboardType: TextInputType.url,
                                  decoration: _inputDecoration(
                                    label: 'Payment Link',
                                    hint: 'https://pay.example.com/invoice',
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _discountController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: _inputDecoration(
                                    label: 'Discount (Pro)',
                                    hint: '0.00',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Discounted totals are a Pro feature.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _notesController,
                                  minLines: 3,
                                  maxLines: 5,
                                  decoration: _inputDecoration(
                                    label: 'Notes',
                                    hint: 'Payment instructions or terms',
                                  ),
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<InvoiceStatus>(
                                  initialValue: _status,
                                  decoration: _inputDecoration(label: 'Status'),
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
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          // ── Actions ──
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton.icon(
                              onPressed: _handleDelete,
                              icon: Icon(
                                Icons.delete_outline,
                                color: theme.colorScheme.error,
                                size: 20,
                              ),
                              label: Text(
                                'Delete Invoice',
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: theme.colorScheme.error.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton(
                              onPressed: _isSaving ? null : _save,
                              style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 2,
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Save Changes',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
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
