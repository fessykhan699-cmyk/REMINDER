import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import '../../../../data/services/analytics_service.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/components/app_scaffold.dart';
import '../../../../shared/components/glass_card.dart';
import '../../../../shared/components/premium_primary_button.dart';
import '../../../../shared/services/invoice_export_service.dart';
import '../../../../shared/services/whatsapp_service.dart';
import '../../../../data/services/whatsapp_reminder_service.dart';
import '../../../../data/services/email_invoice_service.dart';
import '../../../clients/presentation/controllers/clients_controller.dart';
import '../../../subscription/domain/entities/subscription_state.dart';
import '../../../subscription/presentation/controllers/subscription_controller.dart';
import '../../../subscription/presentation/widgets/upgrade_prompt_sheet.dart';

import '../../../../data/services/payment_service.dart';
import '../../domain/entities/invoice.dart';
import '../controllers/invoices_controller.dart';
import '../widgets/invoice_status_badge.dart';
import 'invoice_pdf_preview_screen.dart';

class InvoiceDetailScreen extends ConsumerStatefulWidget {
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  ConsumerState<InvoiceDetailScreen> createState() =>
      _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends ConsumerState<InvoiceDetailScreen> {
  bool _isOpeningPdfPreview = false;
  bool _isSharingPdf = false;
  bool _isSendingWhatsApp = false;
  bool _isSendingEmail = false;
  bool _isMarkingPaid = false;
  bool _isAddingPayment = false;

  bool get _isPdfBusy =>
      _isOpeningPdfPreview ||
      _isSharingPdf ||
      _isSendingWhatsApp ||
      _isSendingEmail ||
      _isAddingPayment;

  void _showSnackBar(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _promptWatermarkUpgrade() async {
    final decision = await ref
        .read(subscriptionGatekeeperProvider)
        .evaluate(SubscriptionGateFeature.premiumBranding);
    if (!mounted || decision.isAllowed) {
      return;
    }

    await promptUpgradeForDecision(context, decision);
  }

  Future<void> _shareInvoicePdf(Invoice invoice) async {
    if (_isPdfBusy) {
      return;
    }

    setState(() => _isSharingPdf = true);

    try {
      AnalyticsService.instance.logInvoiceShared('share_sheet');
      await ref.read(invoiceExportServiceProvider).shareInvoicePdf(invoice);
      await ref
          .read(invoicesControllerProvider.notifier)
          .markInvoiceSent(invoice);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showSnackBar('Failed to share invoice');
    } finally {
      if (mounted) {
        setState(() => _isSharingPdf = false);
      }
    }
  }

  Future<void> _sendViaWhatsApp(Invoice invoice) async {
    if (_isPdfBusy) {
      return;
    }

    setState(() => _isSendingWhatsApp = true);

    try {
      AnalyticsService.instance.logInvoiceShared('whatsapp');
      final result = await ref
          .read(whatsAppServiceProvider)
          .sendInvoiceReminder(invoice: invoice);
      await ref
          .read(invoicesControllerProvider.notifier)
          .markInvoiceSent(invoice);

      if (!mounted || !result.usedFallbackShareSheet) {
        return;
      }

      _showSnackBar('WhatsApp unavailable. Opened the share sheet instead.');
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showSnackBar('Unable to open WhatsApp right now');
    } finally {
      if (mounted) {
        setState(() => _isSendingWhatsApp = false);
      }
    }
  }

  Future<void> _markInvoicePaid(Invoice invoice) async {
    if (_isMarkingPaid) {
      return;
    }

    setState(() => _isMarkingPaid = true);

    try {
      await ref
          .read(invoicesControllerProvider.notifier)
          .markInvoicePaid(invoice);
      if (!mounted) {
        return;
      }

      _showSnackBar('Invoice marked as paid');
      ref.invalidate(invoiceDetailProvider(invoice.id));
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showSnackBar('Unable to update invoice status');
    } finally {
      if (mounted) {
        setState(() => _isMarkingPaid = false);
      }
    }
  }

  Future<void> _showAddPaymentSheet(Invoice invoice) async {
    final decision = await ref
        .read(subscriptionGatekeeperProvider)
        .evaluate(SubscriptionGateFeature.partialPayments);

    if (!mounted) return;

    if (!decision.isAllowed) {
      await promptUpgradeForDecision(context, decision);
      return;
    }

    final amountController = TextEditingController(
      text: invoice.remainingBalance.toStringAsFixed(2),
    );
    final noteController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String? selectedMethod = 'bank_transfer';

    const paymentMethods = [
      {'id': 'bank_transfer', 'label': 'Bank Transfer', 'icon': Icons.account_balance_outlined},
      {'id': 'cash', 'label': 'Cash', 'icon': Icons.payments_outlined},
      {'id': 'cheque', 'label': 'Cheque', 'icon': Icons.wallet_outlined},
      {'id': 'card', 'label': 'Card', 'icon': Icons.credit_card_outlined},
      {'id': 'crypto', 'label': 'Crypto', 'icon': Icons.currency_bitcoin_outlined},
      {'id': 'other', 'label': 'Other', 'icon': Icons.more_horiz_outlined},
    ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: AppColors.accent.withValues(alpha: 0.2), width: 1),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            spacingMD,
            spacingSM,
            spacingMD,
            spacingLG,
          ),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: spacingMD),
                      decoration: BoxDecoration(
                        color: AppColors.textMuted.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.add_card_rounded, color: AppColors.accent, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'Record Payment',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: spacingLG),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      prefixText: '${invoice.currencyCode} ',
                      prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent),
                    ),
                  ),
                  const SizedBox(height: spacingMD),
                  InkWell(
                    onTap: () async {
                      DateTime? picked;
                      if (Platform.isIOS) {
                        DateTime iosSelected = selectedDate;
                        await showCupertinoModalPopup<void>(
                          context: context,
                          builder: (BuildContext ctx) => SizedBox(
                            height: 260,
                            child: CupertinoDatePicker(
                              mode: CupertinoDatePickerMode.date,
                              initialDateTime: iosSelected,
                              minimumDate: DateTime(2000),
                              maximumDate: DateTime(2100),
                              onDateTimeChanged: (date) =>
                                  iosSelected = date,
                            ),
                          ),
                        );
                        picked = iosSelected;
                      } else {
                        picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                      }
                      if (picked != null) {
                        setSheetState(() => selectedDate = picked!);
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(spacingMD),
                      decoration: BoxDecoration(
                        color: AppColors.glassFill,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 20, color: AppColors.accent),
                          const SizedBox(width: 12),
                          const Expanded(child: Text('Payment Date')),
                          Text(
                            AppFormatters.shortDate(selectedDate),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: spacingMD),
                  if (Platform.isIOS)
                    InkWell(
                      onTap: () async {
                        await showCupertinoModalPopup<void>(
                          context: context,
                          builder: (_) => CupertinoActionSheet(
                            title: const Text('Payment Method'),
                            actions: paymentMethods
                                .map(
                                  (m) => CupertinoActionSheetAction(
                                    onPressed: () {
                                      setSheetState(
                                        () => selectedMethod =
                                            m['id'] as String,
                                      );
                                      Navigator.pop(context);
                                    },
                                    child: Text(m['label'] as String),
                                  ),
                                )
                                .toList(),
                            cancelButton: CupertinoActionSheetAction(
                              onPressed: () => Navigator.pop(context),
                              isDefaultAction: true,
                              child: const Text('Cancel'),
                            ),
                          ),
                        );
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Payment Method',
                        ),
                        child: Text(
                          paymentMethods.firstWhere(
                            (m) => m['id'] == selectedMethod,
                            orElse: () => paymentMethods.first,
                          )['label'] as String,
                        ),
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: selectedMethod,
                      decoration: const InputDecoration(
                        labelText: 'Payment Method',
                      ),
                      dropdownColor: AppColors.backgroundSecondary,
                      items: paymentMethods.map((m) {
                        return DropdownMenuItem(
                          value: m['id'] as String,
                          child: Row(
                            children: [
                              Icon(m['icon'] as IconData,
                                  size: 18,
                                  color: AppColors.textSecondary),
                              const SizedBox(width: 12),
                              Text(m['label'] as String),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setSheetState(() => selectedMethod = val),
                    ),
                  const SizedBox(height: spacingMD),
                  TextField(
                    controller: noteController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Note (Optional)',
                      hintText: 'e.g. Reference #12345',
                    ),
                  ),
                  const SizedBox(height: spacingLG),
                  PremiumPrimaryButton(
                    label: 'Record Payment',
                    onPressed: () async {
                      final amount = double.tryParse(amountController.text) ?? 0;
                      if (amount <= 0) {
                        _showSnackBar('Please enter a valid amount');
                        return;
                      }
                      Navigator.pop(context);
                      await _addPayment(
                        invoice,
                        amount,
                        selectedDate,
                        noteController.text,
                        selectedMethod,
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addPayment(
    Invoice invoice,
    double amount,
    DateTime date,
    String note,
    String? paymentMethod,
  ) async {
    setState(() => _isAddingPayment = true);

    try {
      final updated = await ref.read(paymentServiceProvider).addPayment(
        invoice: invoice,
        amount: amount,
        date: date,
        note: note.trim().isEmpty ? null : note.trim(),
        paymentMethod: paymentMethod,
      );

      if (!mounted) return;

      if (updated != null) {
        _showSnackBar('Payment recorded successfully');
        ref.invalidate(invoiceDetailProvider(invoice.id));
      } else {
        _showSnackBar('Failed to record payment');
      }
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('An error occurred while adding payment');
    } finally {
      if (mounted) {
        setState(() => _isAddingPayment = false);
      }
    }
  }

  Future<void> _removePayment(Invoice invoice, String paymentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Payment?'),
        content: const Text('This payment will be deleted permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isAddingPayment = true);

    try {
      final updated = await ref.read(paymentServiceProvider).removePayment(
        invoice: invoice,
        paymentId: paymentId,
      );

      if (!mounted) return;

      if (updated != null) {
        _showSnackBar('Payment removed');
        ref.invalidate(invoiceDetailProvider(invoice.id));
      } else {
        _showSnackBar('Failed to remove payment');
      }
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('An error occurred');
    } finally {
      if (mounted) {
        setState(() => _isAddingPayment = false);
      }
    }
  }

  Future<void> _sendEmailInvoice(Invoice invoice) async {
    // Phase 4 — Subscription Gate
    final subscription =
        ref.read(subscriptionControllerProvider).valueOrNull ??
        const SubscriptionState.free();
    if (!subscription.isPro) {
      const UpgradeToProRoute().push(context);
      return;
    }

    if (_isPdfBusy) return;

    // if client has no email: show a snackbar
    final client = await ref.read(clientDetailProvider(invoice.clientId).future);
    final email = client?.email ?? '';
    if (email.trim().isEmpty) {
      _showSnackBar('Add an email address to this client first');
      return;
    }

    setState(() => _isSendingEmail = true);

    try {
      AnalyticsService.instance.logInvoiceShared('email');
      final success = await ref.read(emailInvoiceServiceProvider).sendInvoiceEmail(
        invoice: invoice,
        email: email,
        isPro: subscription.isPro,
      );

      await ref
          .read(invoicesControllerProvider.notifier)
          .markInvoiceSent(invoice);

      if (!mounted) return;
      if (success) {
        _showSnackBar('Email sequence initiated');
      } else {
        _showSnackBar('Could not start email sequence');
      }
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Unable to open email client');
    } finally {
      if (mounted) {
        setState(() => _isSendingEmail = false);
      }
    }
  }

  Future<void> _showWhatsAppReminderSheet(Invoice invoice) async {
    // Phase 5 — Subscription Gate
    final subscription =
        ref.read(subscriptionControllerProvider).valueOrNull ??
        const SubscriptionState.free();
    if (!subscription.isPro) {
      const UpgradeToProRoute().push(context);
      return;
    }

    // if client has no phone number: show a snackbar
    final client = await ref.read(clientDetailProvider(invoice.clientId).future);
    final phone = client?.phone ?? '';
    if (phone.trim().isEmpty) {
      _showSnackBar('Add a WhatsApp number to this client first');
      return;
    }

    if (!mounted) return;

    final service = ref.read(whatsAppReminderServiceProvider);
    final amountStr = AppFormatters.currency(
      invoice.amount,
      currencyCode: invoice.currencyCode,
    );
    final dueDateStr = AppFormatters.shortDate(invoice.dueDate);
    final clientName = invoice.clientName;

    final friendly = service.getFriendlyMessage(
      clientName,
      amountStr,
      dueDateStr,
    );
    final firm = service.getFirmMessage(clientName, amountStr, dueDateStr);
    final finalNotice = service.getFinalMessage(clientName, amountStr, dueDateStr);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.all(spacingMD),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Send WhatsApp Reminder',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: spacingMD),
                _ReminderOption(
                  title: 'Friendly Reminder',
                  preview: friendly,
                  onTap: () => _handleSend(invoice.id, phone, friendly, 'friendly'),
                ),
                const SizedBox(height: spacingSM),
                _ReminderOption(
                  title: 'Firm Reminder',
                  preview: firm,
                  onTap: () => _handleSend(invoice.id, phone, firm, 'firm'),
                ),
                const SizedBox(height: spacingSM),
                _ReminderOption(
                  title: 'Final Notice',
                  preview: finalNotice,
                  onTap: () => _handleSend(invoice.id, phone, finalNotice, 'final'),
                ),
                const SizedBox(height: spacingLG),
              ],
            ),
          ),
    );
  }

  Future<void> _handleSend(
    String invoiceId,
    String phone,
    String message,
    String template,
  ) async {
    Navigator.pop(context);
    final success = await ref.read(whatsAppReminderServiceProvider).sendReminder(
      invoiceId: invoiceId,
      phone: phone,
      message: message,
      template: template,
    );

    if (!mounted) return;
    if (success) {
      _showSnackBar('WhatsApp opened successfully');
    } else {
      _showSnackBar('Could not open WhatsApp');
    }
  }

  Future<void> _openPdfPreview(Invoice invoice) async {
    if (_isPdfBusy) {
      return;
    }

    setState(() => _isOpeningPdfPreview = true);

    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => InvoicePdfPreviewScreen(invoiceId: invoice.id),
        ),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            subscriptionIsPro(ref)
                ? 'PDF ready to preview and share.'
                : 'PDF preview opened. Free plan PDFs include a faint Invoice Flow watermark behind the invoice content.',
          ),
          action: subscriptionIsPro(ref)
              ? null
              : SnackBarAction(
                  label: 'Upgrade',
                  onPressed: () {
                    const UpgradeToProRoute().push(context);
                  },
                ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to export the invoice PDF right now.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isOpeningPdfPreview = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoiceState = ref.watch(invoiceDetailProvider(widget.invoiceId));
    final currentInvoice = invoiceState.valueOrNull;
    final subscription =
        ref.watch(subscriptionControllerProvider).valueOrNull ??
        const SubscriptionState.free();

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Invoice Detail'),
        actions: [
          IconButton(
            onPressed: currentInvoice == null || _isPdfBusy
                ? null
                : () => _shareInvoicePdf(currentInvoice),
            tooltip: 'Share PDF',
            icon: _isSharingPdf
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.share_outlined),
          ),
          IconButton(
            onPressed: () async {
              final result = await EditInvoiceRoute(
                widget.invoiceId,
              ).push<bool>(context);
              if (!context.mounted) return;
              if (result == true) {
                // Pop with true so list screen receives the delete signal
                context.pop(true);
              } else {
                ref.invalidate(invoiceDetailProvider(widget.invoiceId));
              }
            },
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

          return SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                spacingMD,
                spacingMD,
                spacingMD,
                MediaQuery.of(context).padding.bottom + 100,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──
                  Text(
                    invoice.clientName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    invoice.items.length > 1
                        ? '${invoice.items.length} Items'
                        : invoice.items.isNotEmpty
                            ? invoice.items.first.description
                            : invoice.service,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (invoice.recurringParentId != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.auto_awesome_outlined,
                            size: 14,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Auto-generated recurring draft',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: spacingMD),

                  // ── Details card ──
                  GlassCard(
                    padding: const EdgeInsets.all(spacingMD),
                    child: Column(
                      children: [
                        _InfoRow(
                          label: 'Status',
                          value: InvoiceStatusBadge(
                            status: invoice.status,
                          ),
                        ),
                        const SizedBox(height: spacingSM),
                        _InfoRow(
                          label: 'Amount',
                          value: Text(
                            AppFormatters.currency(
                              invoice.amount,
                              currencyCode: invoice.currencyCode,
                            ),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: spacingSM),
                        _InfoRow(
                          label: 'Due Date',
                          value: Text(
                            AppFormatters.shortDate(invoice.dueDate),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        if (invoice.hasPaymentLink) ...[
                          const SizedBox(height: spacingSM),
                          _InfoRow(
                            label: 'Payment',
                            value: Text(
                              'Link attached',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                        if (invoice.isRecurring) ...[
                          const SizedBox(height: spacingSM),
                          _InfoRow(
                            label: 'Recurring',
                            value: Text(
                              invoice.recurringInterval.label,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          if (invoice.recurringNextDate != null) ...[
                            const SizedBox(height: spacingSM),
                            _InfoRow(
                              label: 'Next Invoice',
                              value: Text(
                                AppFormatters.shortDate(
                                  invoice.recurringNextDate!,
                                ),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ],
                        if (invoice.status == InvoiceStatus.paid && invoice.payments.length == 1) ...[
                          const SizedBox(height: spacingSM),
                          _InfoRow(
                            label: 'Paid On',
                            value: Text(
                              AppFormatters.shortDate(invoice.payments.first.date),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          if (invoice.payments.first.paymentMethod != null) ...[
                            const SizedBox(height: spacingSM),
                            _InfoRow(
                              label: 'Method',
                              value: Text(
                                invoice.payments.first.paymentMethod!
                                    .replaceAll('_', ' ')
                                    .split(' ')
                                    .map((word) =>
                                        word[0].toUpperCase() + word.substring(1))
                                    .join(' '),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: spacingMD),


                  if (invoice.items.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        'Items',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: spacingSM),
                    GlassCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          ...invoice.items.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final item = entry.value;
                            return Column(
                              children: [
                                if (idx > 0)
                                  Divider(
                                    height: 1,
                                    indent: spacingMD,
                                    endIndent: spacingMD,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outlineVariant
                                        .withValues(alpha: 0.5),
                                  ),
                                ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: spacingMD,
                                    vertical: 4,
                                  ),
                                  title: Text(
                                    item.description,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Text(
                                    '${item.quantity.toStringAsFixed(item.quantity == item.quantity.toInt() ? 0 : 2)} × ${AppFormatters.currency(item.unitPrice, currencyCode: invoice.currencyCode)}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                  trailing: Text(
                                    AppFormatters.currency(item.amount,
                                        currencyCode: invoice.currencyCode),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: spacingMD),
                  ],

                  // ── Payments section ──
                  if (invoice.status != InvoiceStatus.draft) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Payments',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.accent,
                                ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Remaining Balance',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      fontSize: 10,
                                      color: AppColors.textMuted,
                                    ),
                              ),
                              Text(
                                AppFormatters.currency(
                                  invoice.remainingBalance,
                                  currencyCode: invoice.currencyCode,
                                ),
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: invoice.remainingBalance > 0
                                          ? AppColors.danger
                                          : AppColors.success,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: spacingSM),
                    if (subscription.isPro)
                      GlassCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            if (invoice.payments.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: spacingMD,
                                  vertical: spacingLG,
                                ),
                                child: Column(
                                  children: [
                                    Icon(Icons.payments_outlined,
                                        size: 40, color: AppColors.textMuted.withValues(alpha: 0.3)),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No payments recorded yet.',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            fontStyle: FontStyle.italic,
                                          ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ...invoice.payments.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final payment = entry.value;
                                
                                // Map payment method to icon
                                IconData methodIcon = Icons.payment_outlined;
                                final method = payment.paymentMethod?.toLowerCase() ?? '';
                                if (method.contains('bank')) methodIcon = Icons.account_balance_outlined;
                                if (method.contains('cash')) methodIcon = Icons.payments_outlined;
                                if (method.contains('cheque')) methodIcon = Icons.wallet_outlined;
                                if (method.contains('card')) methodIcon = Icons.credit_card_outlined;
                                if (method.contains('crypto')) methodIcon = Icons.currency_bitcoin_outlined;

                                return Column(
                                  children: [
                                    if (idx > 0)
                                      Divider(
                                        height: 1,
                                        indent: spacingMD,
                                        endIndent: spacingMD,
                                        color: AppColors.glassBorder,
                                      ),
                                    ListTile(
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: spacingMD,
                                        vertical: 4,
                                      ),
                                      leading: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.accent.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(methodIcon, size: 20, color: AppColors.accent),
                                      ),
                                      title: Text(
                                        AppFormatters.currency(payment.amount,
                                            currencyCode: invoice.currencyCode),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${AppFormatters.shortDate(payment.date)}'
                                        '${payment.paymentMethod != null ? ' • ${payment.paymentMethod!.replaceAll('_', ' ').split(' ').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ')}' : ''}'
                                        '${payment.note != null && payment.note!.isNotEmpty ? '\n${payment.note}' : ''}',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          height: 1.2,
                                        ),
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 20),
                                        onPressed: () => _removePayment(invoice, payment.id),
                                        color: AppColors.danger.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                          ],
                        ),
                      )
                    else
                      GlassCard(
                        padding: const EdgeInsets.all(spacingMD),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.lock_outline,
                                    size: 18, color: AppColors.accent.withValues(alpha: 0.7)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Partial Payment Tracking',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Track multiple partial payments, record payment methods, and see balance history.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            PremiumPrimaryButton(
                              label: 'Upgrade to Pro',
                              onPressed: () async {
                                const UpgradeToProRoute().push(context);
                              },
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: spacingLG),
                  ],

                  // ── Actions card ──
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _ActionRow(
                          icon: Icons.chat_bubble_outline_rounded,
                          label: _isSendingWhatsApp
                              ? 'Opening WhatsApp...'
                              : 'Send via WhatsApp',
                          isLoading: _isSendingWhatsApp,
                          onTap: _isPdfBusy
                              ? null
                              : () => _sendViaWhatsApp(invoice),
                        ),
                        _ActionRow(
                          icon: RemixIcons.share_line,
                          label: _isSharingPdf ? 'Sharing PDF...' : 'Share PDF',
                          isLoading: _isSharingPdf,
                          onTap: _isPdfBusy
                              ? null
                              : () => _shareInvoicePdf(invoice),
                          showTopBorder: true,
                        ),
                        _ActionRow(
                          icon: RemixIcons.file_pdf_line,
                          label: _isOpeningPdfPreview
                              ? 'Opening PDF...'
                              : 'Open PDF',
                          isLoading: _isOpeningPdfPreview,
                          onTap: _isPdfBusy
                              ? null
                              : () => _openPdfPreview(invoice),
                          showTopBorder: true,
                        ),
                        _ActionRow(
                          icon: RemixIcons.checkbox_circle_line,
                          label: _isMarkingPaid
                              ? 'Marking Paid...'
                              : 'Mark as Paid',
                          isLoading: _isMarkingPaid,
                          onTap: invoice.status == InvoiceStatus.paid ||
                                  _isMarkingPaid
                              ? null
                              : () => _markInvoicePaid(invoice),
                          accent: invoice.status != InvoiceStatus.paid,
                          showTopBorder: true,
                        ),
                        _ActionRow(
                          icon: RemixIcons.bank_card_line,
                          label: _isAddingPayment
                              ? 'Adding Payment...'
                              : 'Add Partial Payment',
                          isLoading: _isAddingPayment,
                          onTap: invoice.status == InvoiceStatus.paid ||
                                  _isAddingPayment
                              ? null
                              : () => _showAddPaymentSheet(invoice),
                          showTopBorder: true,
                        ),
                        _ActionRow(
                          icon: RemixIcons.message_3_line,
                          label: 'Send WhatsApp Reminder',
                          onTap: () => _showWhatsAppReminderSheet(invoice),
                          showTopBorder: true,
                        ),
                        _ActionRow(
                          icon: RemixIcons.mail_line,
                          label: _isSendingEmail ? 'Opening Email...' : 'Email Invoice',
                          isLoading: _isSendingEmail,
                          onTap: _isPdfBusy
                              ? null
                              : () => _sendEmailInvoice(invoice),
                          showTopBorder: true,
                        ),
                      ],
                    ),
                  ),

                  // ── Watermark note for free users ──
                  if (!subscription.isPro) ...[
                    const SizedBox(height: spacingMD),
                    GlassCard(
                      padding: const EdgeInsets.all(spacingMD),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Free plan PDFs include a faint Invoice Flow watermark.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: spacingSM),
                          PremiumPrimaryButton(
                            label: 'Remove Watermark',
                            onPressed: () async {
                              await _promptWatermarkUpgrade();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  }


bool subscriptionIsPro(WidgetRef ref) {
  final subscription = ref.read(subscriptionControllerProvider).valueOrNull;
  return subscription?.isPro ?? false;
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          value,
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    this.onTap,
    this.isLoading = false,
    this.accent = false,
    this.showTopBorder = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool accent;
  final bool showTopBorder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = onTap == null
        ? theme.disabledColor
        : accent
            ? AppColors.accent
            : AppColors.textPrimary;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: showTopBorder
            ? Border(
                top: BorderSide(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  width: 0.5,
                ),
              )
            : const Border(),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: spacingMD,
            vertical: 14,
          ),
          child: Row(
            children: [
              isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: color,
                      ),
                    )
                  : Icon(icon, size: 20, color: color),
              const SizedBox(width: spacingMD),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(color: color),
                ),
              ),
              Icon(
                RemixIcons.arrow_right_s_line,
                size: 14,
                color: onTap == null
                    ? theme.disabledColor
                    : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReminderOption extends StatelessWidget {
  const _ReminderOption({
    required this.title,
    required this.preview,
    required this.onTap,
  });

  final String title;
  final String preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: spacingMD, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(spacingLG),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.04),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.12)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.accent,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      preview,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                RemixIcons.arrow_right_s_line,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
