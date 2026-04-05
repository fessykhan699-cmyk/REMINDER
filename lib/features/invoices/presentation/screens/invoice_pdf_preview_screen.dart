import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/services/invoice_pdf_export_service.dart';
import '../../../subscription/domain/entities/subscription_state.dart';
import '../../../subscription/presentation/controllers/subscription_controller.dart';
import '../controllers/invoices_controller.dart';

class InvoicePdfPreviewScreen extends ConsumerStatefulWidget {
  const InvoicePdfPreviewScreen({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  ConsumerState<InvoicePdfPreviewScreen> createState() =>
      _InvoicePdfPreviewScreenState();
}

class _InvoicePdfPreviewScreenState
    extends ConsumerState<InvoicePdfPreviewScreen> {
  late Future<InvoicePdfDocument> _documentFuture;
  InvoicePdfDocument? _document;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _documentFuture = _loadDocument();
  }

  Future<InvoicePdfDocument> _loadDocument() async {
    final invoice = await ref
        .read(invoiceRepositoryProvider)
        .getInvoiceById(widget.invoiceId);
    if (invoice == null) {
      throw StateError('Invoice not found.');
    }

    final decision = await ref
        .read(subscriptionGatekeeperProvider)
        .evaluate(SubscriptionGateFeature.exportPdf);
    final document = await ref
        .read(invoicePdfExportServiceProvider)
        .generateInvoicePdfDocument(
          invoice,
          includeWatermark: decision.shouldWatermarkPdf,
          saveLocally: true,
        );

    if (mounted) {
      setState(() => _document = document);
    }

    return document;
  }

  Future<void> _shareDocument() async {
    final document = _document;
    if (document == null || _isSharing) {
      return;
    }

    final invoice = await ref
        .read(invoiceRepositoryProvider)
        .getInvoiceById(widget.invoiceId);
    if (invoice == null) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invoice not found.')));
      return;
    }

    setState(() => _isSharing = true);
    try {
      await ref
          .read(invoicePdfExportServiceProvider)
          .shareInvoicePdfDocument(document);
      await ref
          .read(invoicesControllerProvider.notifier)
          .markInvoiceSent(invoice);
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to share the PDF right now.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  void _retry() {
    setState(() {
      _document = null;
      _documentFuture = _loadDocument();
    });
  }

  @override
  Widget build(BuildContext context) {
    final subscription =
        ref.watch(subscriptionControllerProvider).valueOrNull ??
        const SubscriptionState.free();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice PDF'),
        actions: [
          IconButton(
            onPressed: _document == null || _isSharing ? null : _shareDocument,
            icon: _isSharing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.share_outlined),
            tooltip: 'Share PDF',
          ),
        ],
      ),
      body: FutureBuilder<InvoicePdfDocument>(
        future: _documentFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.picture_as_pdf_outlined,
                      size: 42,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Unable to load the invoice PDF.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _retry,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            );
          }

          final document = snapshot.data!;

          return Column(
            children: [
              Expanded(
                child: PdfPreview(
                  build: (format) => document.bytes,
                  pdfFileName: document.filename,
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  allowPrinting: false,
                  allowSharing: false,
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    border: const Border(
                      top: BorderSide(color: AppColors.glassBorder),
                    ),
                  ),
                  child: Text(
                    document.savedFilePath == null
                        ? subscription.isPro
                              ? 'Preview the PDF here and share it from the top-right action.'
                              : 'Preview the PDF here. Free plan PDFs include the Invoice Flow footer watermark.'
                        : subscription.isPro
                        ? 'Saved locally for offline access. Share it from the top-right action.'
                        : 'Saved locally for offline access. Free plan PDFs include the Invoice Flow footer watermark.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
