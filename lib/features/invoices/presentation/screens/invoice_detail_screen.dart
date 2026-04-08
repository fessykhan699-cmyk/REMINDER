import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/components/primary_button.dart';
import '../../../../shared/services/invoice_export_service.dart';
import '../../../../shared/services/whatsapp_service.dart';
import '../../../subscription/domain/entities/subscription_state.dart';
import '../../../subscription/presentation/controllers/subscription_controller.dart';
import '../../../subscription/presentation/widgets/upgrade_prompt_sheet.dart';
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
  bool _isMarkingPaid = false;

  bool get _isPdfBusy =>
      _isOpeningPdfPreview || _isSharingPdf || _isSendingWhatsApp;

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
      debugPrint("Detail screen: marking invoice paid for ID: ${invoice.id}");
      await ref
          .read(invoicesControllerProvider.notifier)
          .markInvoicePaid(invoice);
      if (!mounted) {
        return;
      }

      _showSnackBar('Invoice marked as paid');
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

    return Scaffold(
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
              debugPrint("🟢 DETAIL → OPEN EDIT: ID = '${widget.invoiceId}'");
              final result = await EditInvoiceRoute(
                widget.invoiceId,
              ).push<bool>(context);
              debugPrint(
                "🟢 DETAIL ← EDIT returned: result=$result, mounted=$context.mounted",
              );
              if (!context.mounted) return;
              if (result == true) {
                debugPrint(
                  "🟢 DETAIL: Popping self with true → list screen will rebuild",
                );
                // Pop with true so list screen receives the delete signal
                context.pop(true);
              } else {
                debugPrint(
                  "🟢 DETAIL: Invalidating detail provider (result was not true)",
                );
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
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).padding.bottom + 80,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: InvoiceStatusBadge(status: invoice.status),
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(
                    label: 'Amount',
                    value: AppFormatters.currency(
                      invoice.amount,
                      currencyCode: invoice.currencyCode,
                    ),
                  ),
                  _InfoRow(
                    label: 'Due Date',
                    value: AppFormatters.shortDate(invoice.dueDate),
                  ),
                  _InfoRow(label: 'Status', value: invoice.status.label),
                  if (invoice.hasPaymentLink)
                    _InfoRow(label: 'Payment', value: 'Link attached'),
                  const SizedBox(height: 20),
                  PrimaryButton(
                    label: _isSendingWhatsApp
                        ? 'Opening WhatsApp...'
                        : 'Send via WhatsApp',
                    icon: Icons.chat_bubble_outline_rounded,
                    isLoading: _isSendingWhatsApp,
                    onPressed: _isPdfBusy
                        ? null
                        : () => _sendViaWhatsApp(invoice),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _isPdfBusy
                        ? null
                        : () => _shareInvoicePdf(invoice),
                    icon: _isSharingPdf
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.share_outlined),
                    label: Text(_isSharingPdf ? 'Sharing PDF...' : 'Share PDF'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () =>
                        ReminderFlowRoute(invoice.id).push(context),
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: const Text('Advanced Reminder Flow'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _isPdfBusy
                        ? null
                        : () => _openPdfPreview(invoice),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(
                      _isOpeningPdfPreview ? 'Opening PDF...' : 'Open PDF',
                    ),
                  ),
                  if (!subscription.isPro) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Free plan PDFs include a faint Invoice Flow watermark behind the invoice content.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _promptWatermarkUpgrade,
                        child: const Text('Upgrade to remove watermark'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed:
                        invoice.status == InvoiceStatus.paid || _isMarkingPaid
                        ? null
                        : () => _markInvoicePaid(invoice),
                    icon: _isMarkingPaid
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(
                      _isMarkingPaid ? 'Marking Paid...' : 'Mark as Paid',
                    ),
                  ),
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
