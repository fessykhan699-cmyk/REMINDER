import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/storage/hive_storage.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/services/invoice_status_service.dart';
import '../../../subscription/domain/entities/subscription_state.dart';
import '../../../subscription/presentation/controllers/subscription_controller.dart';
import '../../../subscription/presentation/widgets/upgrade_prompt_sheet.dart';
import '../../data/models/invoice_model.dart';
import '../../data/models/line_item_model.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/line_item.dart';
import '../controllers/invoices_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../controllers/invoice_templates_controller.dart';
import '../widgets/template_picker_sheet.dart';
import '../../domain/entities/invoice_template.dart';

class EditInvoiceScreen extends ConsumerStatefulWidget {
  const EditInvoiceScreen({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  ConsumerState<EditInvoiceScreen> createState() => _EditInvoiceScreenState();
}

class _EditInvoiceScreenState extends ConsumerState<EditInvoiceScreen> {
  static const InvoiceStatusService _statusService = InvoiceStatusService();

  final _clientNameController = TextEditingController();
  final _serviceController = TextEditingController();
  final _amountController = TextEditingController();
  final _dueDateController = TextEditingController();
  final _notesController = TextEditingController();
  final _paymentLinkController = TextEditingController();

  DateTime? _dueDate;
  InvoiceStatus _status = InvoiceStatus.draft;
  final List<LineItem> _lineItems = [];
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _didHydrate = false;
  bool _isRecurring = false;
  RecurringInterval _recurringInterval = RecurringInterval.none;
  bool _saveAsTemplate = false;
  double _taxPercent = 0.0;


  @override
  void initState() {
    super.initState();
    // Hydrate form fields AFTER the first frame to avoid mutating controllers during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didHydrate) return;
      final invoice = ref
          .read(invoicesControllerProvider)
          .value
          ?.where((i) => i.id == widget.invoiceId)
          .firstOrNull;
      if (invoice != null) {
        _hydrate(InvoiceModel.fromEntity(invoice));
        _didHydrate = true;
      }
    });
  }

  @override
  void dispose() {
    _clientNameController.dispose();
    _serviceController.dispose();
    _amountController.dispose();
    _dueDateController.dispose();
    _notesController.dispose();
    _paymentLinkController.dispose();
    super.dispose();
  }

  void _hydrate(InvoiceModel invoice) {
    _dueDate = invoice.dueDate;
    _status = invoice.status;
    _clientNameController.text = invoice.clientName;
    _serviceController.text = invoice.service;
    _amountController.text = _formatAmountInput(
      invoice.items.isEmpty ? invoice.subtotalAmount : invoice.amount,
    );
    _dueDateController.text = AppFormatters.shortDate(invoice.dueDate);
    _notesController.text = invoice.notes ?? '';
    _paymentLinkController.text = invoice.paymentLink ?? '';
    _isRecurring = invoice.isRecurring;
    _recurringInterval = invoice.recurringInterval;
    _taxPercent = invoice.taxPercent;
    _lineItems.clear();
    _lineItems.addAll(invoice.items);
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
    DateTime? picked;

    if (Platform.isIOS) {
      DateTime iosSelected = initial;
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (BuildContext ctx) => SizedBox(
          height: 260,
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.date,
            initialDateTime: iosSelected,
            minimumDate: DateTime.now().subtract(const Duration(days: 365)),
            maximumDate: DateTime.now().add(const Duration(days: 3650)),
            onDateTimeChanged: (date) => iosSelected = date,
          ),
        ),
      );
      picked = iosSelected;
    } else {
      picked = await showDatePicker(
        context: context,
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 3650)),
        initialDate: initial,
      );
    }

    if (!mounted || picked == null) return;
    setState(() => _dueDate = picked);
    _dueDateController.text = AppFormatters.shortDate(picked);
  }

  Future<void> _save(InvoiceModel invoice) async {
    final dueDate = _dueDate;
    final amount = double.tryParse(_amountController.text.trim());
    final paymentLink = _normalizedPaymentLink();
    final serviceStr = _serviceController.text.trim();

    if (dueDate == null || amount == null) {
      return;
    }

    final wasClassicMode = _lineItems.isEmpty;

    if (_paymentLinkController.text.trim().isNotEmpty && paymentLink == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid payment link')),
      );
      return;
    }

    DateTime? recurringNextDate = invoice.recurringNextDate;
    if (_isRecurring) {
      if (!invoice.isRecurring ||
          _recurringInterval != invoice.recurringInterval ||
          dueDate != invoice.dueDate ||
          recurringNextDate == null) {
        recurringNextDate = _recurringInterval.calculateNextDate(dueDate);
      }
    } else {
      recurringNextDate = null;
    }

    final effectiveAmount = wasClassicMode && _taxPercent > 0
        ? amount * (1 + _taxPercent / 100)
        : amount;

    final updated = invoice.copyWith(
      clientName: _clientNameController.text.trim(),
      service: serviceStr,
      amount: effectiveAmount,
      dueDate: dueDate,
      status: _status,
      discountAmount: 0.0,
      paymentLink: paymentLink,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      items: _lineItems.map((e) => LineItemModel.fromEntity(e)).toList(),
      isRecurring: _isRecurring,
      recurringInterval: _recurringInterval,
      recurringNextDate: recurringNextDate,
    );
    final resolvedEntity = _statusService.prepareForUpdate(updated);
    final resolved = InvoiceModel.fromEntity(resolvedEntity);

    setState(() => _isSaving = true);
    var shouldResetSavingState = true;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      // Call controller update — this updates controller state so the list screen rebuilds
      await ref
          .read(invoicesControllerProvider.notifier)
          .updateInvoice(resolved);

      // Invalidate detail provider so detail screen shows fresh data
      ref.invalidate(invoiceDetailProvider(widget.invoiceId));

      if (_saveAsTemplate) {
        try {
          await ref.read(invoiceTemplatesControllerProvider.notifier).addTemplate(
                name: serviceStr,
                service: serviceStr,
                amount: amount,
                notes: _notesController.text.trim(),
                paymentLink: paymentLink,
                items: _lineItems.isNotEmpty ? _lineItems : null,
              );
        } catch (e) {
          debugPrint('Failed to save template: $e');
        }
      }

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
    if (_isDeleting) {
      return;
    }

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

    if (confirm != true || !mounted) return;

    setState(() => _isDeleting = true);

    // Always delete — errors must NOT block navigation
    try {
      await ref
          .read(invoicesControllerProvider.notifier)
          .deleteInvoice(widget.invoiceId);
    } catch (_) {}

    // FORCE EXIT — always, regardless of errors
    // Use context.pop(true) (GoRouter) so the push<bool> future in the
    // caller resolves with true — Navigator.of(context).pop() pops the
    // widget but does NOT complete GoRouter's push future with the result.
    if (mounted) {
      context.pop(true);
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

  Widget _buildBody(InvoiceModel invoice, BuildContext context) {
    final theme = Theme.of(context);
    final isPro =
        ref.watch(subscriptionControllerProvider).valueOrNull?.isPro ?? false;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                            decoration: _inputDecoration(label: 'Client Name'),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _serviceController,
                            decoration: _inputDecoration(label: 'Service'),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _inputDecoration(label: 'Amount'),
                          ),
                          if (_lineItems.isEmpty && _taxPercent > 0)
                            ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _amountController,
                              builder: (context2, amountValue, child2) {
                                final parsedAmt = double.tryParse(amountValue.text.trim()) ?? 0.0;
                                if (parsedAmt <= 0) return const SizedBox.shrink();
                                final taxAmt = parsedAmt * _taxPercent / 100;
                                final total = parsedAmt + taxAmt;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Tax (${_taxPercent.toStringAsFixed(0)}%): ${AppFormatters.currency(taxAmt, currencyCode: invoice.currencyCode)}',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                      Text(
                                        'Total: ${AppFormatters.currency(total, currencyCode: invoice.currencyCode)}',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _dueDateController,
                            readOnly: true,
                            onTap: _pickDueDate,
                            decoration: _inputDecoration(label: 'Due Date'),
                          ),
                          const SizedBox(height: 24),
                          _buildLineItemsSection(theme, invoice.currencyCode),
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
                          const SizedBox(height: 16),
                          _buildRecurringSection(theme, isPro),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Checkbox.adaptive(
                                value: _saveAsTemplate,
                                onChanged: (value) {
                                  setState(() => _saveAsTemplate = value ?? false);
                                },
                                activeColor: AppColors.accent,
                              ),
                              const Text('Save as template for future use'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _isDeleting ? null : () => _handleDelete(),
                        icon: _isDeleting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.red,
                                ),
                              )
                            : Icon(
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
                        onPressed: _isSaving ? null : () => _save(invoice),
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
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<InvoiceModel>>(
      valueListenable: HiveStorage.invoicesBox.listenable(),
      builder: (context, box, _) {
        // Hive key IS the invoice.id, so get directly
        final invoice = box.get(widget.invoiceId);

        if (invoice == null) {
          // Only auto-pop if WE didn't initiate the delete.
          // When _handleDelete is running (_isDeleting = true), it owns the pop
          // via pop(true). Scheduling a second pop here fires an extra
          // Navigator.pop() (without a return value) that disrupts the
          // result=true chain — Detail never gets to pop(true), List never
          // calls setState, and the deleted item stays visible.
          if (!_isDeleting) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.pop();
            });
          }
          return const SizedBox.shrink();
        }

        return Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            title: const Text('Edit Invoice'),
            actions: [
              IconButton(
                icon: const Icon(Icons.copy_rounded),
                onPressed: _showTemplatePicker,
                tooltip: 'Templates',
              ),
            ],
          ),
          body: _buildBody(invoice, context),
        );
      },
    );
  }

  void _showTemplatePicker() async {
    final template = await showModalBottomSheet<InvoiceTemplate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const TemplatePickerSheet(),
    );

    if (template != null) {
      setState(() {
        _serviceController.text = template.service;
        _amountController.text = template.amount.toStringAsFixed(2);
        _notesController.text = template.notes ?? '';
        _paymentLinkController.text = template.paymentLink ?? '';
        if (template.items.isNotEmpty) {
          _lineItems.clear();
          _lineItems.addAll(template.items);
        }
      });
    }
  }

  Future<void> _showAddLineItemDialog() async {
    final result = await showDialog<LineItem>(
      context: context,
      builder: (context) => const _LineItemDialog(),
    );

    if (result != null) {
      setState(() {
        _lineItems.add(result);
        _syncFirstItemToControllers();
      });
    }
  }

  Future<void> _showEditLineItemDialog(int index) async {
    final result = await showDialog<LineItem>(
      context: context,
      builder: (context) => _LineItemDialog(item: _lineItems[index]),
    );

    if (result != null) {
      setState(() {
        _lineItems[index] = result;
        _syncFirstItemToControllers();
      });
    }
  }

  void _syncFirstItemToControllers() {
    if (_lineItems.isNotEmpty) {
      final first = _lineItems.first;
      if (_serviceController.text.trim().isEmpty || _lineItems.length == 1) {
        _serviceController.text = first.description;
      }

      double subtotal = 0;
      for (final item in _lineItems) {
        subtotal += item.unitPrice * item.quantity;
      }
      
      final total = subtotal * (1 + _taxPercent / 100);
      _amountController.text = _formatAmountInput(total);
    }
  }

  String _formatAmountInput(double value) {
    if (value == value.toInt()) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }

  Widget _buildLineItemsSection(ThemeData theme, String currencyCode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Line Items',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: _showAddLineItemDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Item'),
            ),
          ],
        ),
        if (_lineItems.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'No items added yet. Classic fields above will be used.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _lineItems.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = _lineItems[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.description),
                subtitle: Text(
                  '${item.quantity.toStringAsFixed(0)} x ${AppFormatters.currency(item.unitPrice, currencyCode: currencyCode)}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppFormatters.currency(item.amount, currencyCode: currencyCode),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => _showEditLineItemDialog(index),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _lineItems.removeAt(index);
                          _syncFirstItemToControllers();
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildRecurringSection(ThemeData theme, bool isPro) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'Recurring Invoice',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!isPro) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'PRO',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Switch.adaptive(
              value: _isRecurring,
              onChanged: (value) {
                if (!isPro && value) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Recurring invoices require a Pro subscription.'),
                    ),
                  );
                  return;
                }
                setState(() {
                  _isRecurring = value;
                  if (value && _recurringInterval == RecurringInterval.none) {
                    _recurringInterval = RecurringInterval.monthly;
                  }
                });
              },
              activeTrackColor: AppColors.accent.withAlpha(128),
              activeThumbColor: AppColors.accent,
            ),
          ],
        ),
        if (_isRecurring && isPro) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<RecurringInterval>(
            initialValue: _recurringInterval == RecurringInterval.none
                ? RecurringInterval.monthly
                : _recurringInterval,
            decoration: _inputDecoration(label: 'Repeat Every'),
            items: RecurringInterval.values
                .where((e) => e != RecurringInterval.none)
                .map(
                  (interval) => DropdownMenuItem(
                    value: interval,
                    child: Text(interval.label),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) {
                setState(() => _recurringInterval = value);
              }
            },
          ),
          const SizedBox(height: 8),
          Text(
            'New draft invoices will be automatically created on this schedule.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }
}

class _LineItemDialog extends StatefulWidget {
  const _LineItemDialog({this.item});

  final LineItem? item;

  @override
  State<_LineItemDialog> createState() => _LineItemDialogState();
}

class _LineItemDialogState extends State<_LineItemDialog> {
  late final _descriptionController = TextEditingController(text: widget.item?.description ?? '');
  late final _quantityController = TextEditingController(text: (widget.item?.quantity ?? 1).toString());
  late final _unitPriceController = TextEditingController(text: widget.item?.unitPrice.toStringAsFixed(2) ?? '');
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _descriptionController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? 'Add Item' : 'Edit Item'),
      backgroundColor: AppColors.backgroundSecondary,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description', hintText: 'Development services'),
              validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _quantityController,
                    decoration: const InputDecoration(labelText: 'Quantity'),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                       final d = double.tryParse(v ?? '');
                       if (d == null || d <= 0) return 'Invalid';
                       return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _unitPriceController,
                    decoration: const InputDecoration(labelText: 'Unit Price'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                       final d = double.tryParse(v ?? '');
                       if (d == null || d < 0) return 'Invalid';
                       return null;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              final item = LineItem(
                id: widget.item?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                description: _descriptionController.text.trim(),
                quantity: double.tryParse(_quantityController.text) ?? 1,
                unitPrice: double.tryParse(_unitPriceController.text) ?? 0,
              );
              Navigator.pop(context, item);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
