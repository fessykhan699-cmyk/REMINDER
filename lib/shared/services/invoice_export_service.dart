import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';

import '../../features/invoices/domain/entities/invoice.dart';
import '../../features/subscription/domain/entities/subscription_state.dart';
import '../../features/subscription/presentation/controllers/subscription_controller.dart';
import 'invoice_pdf_export_service.dart';

final invoiceExportServiceProvider = Provider<InvoiceExportService>(
  (ref) => InvoiceExportService(
    pdfExportService: ref.watch(invoicePdfExportServiceProvider),
    subscriptionGatekeeper: ref.watch(subscriptionGatekeeperProvider),
  ),
);

class InvoiceExportService {
  InvoiceExportService({
    required InvoicePdfExportService pdfExportService,
    required SubscriptionGatekeeper subscriptionGatekeeper,
  }) : _pdfExportService = pdfExportService,
       _subscriptionGatekeeper = subscriptionGatekeeper;

  final InvoicePdfExportService _pdfExportService;
  final SubscriptionGatekeeper _subscriptionGatekeeper;

  Future<File> saveInvoicePdf(Invoice invoice) async {
    try {
      final generatedPdf = await _generatePdf(invoice);
      final file = await _saveToPublicStorage(generatedPdf);
      return file;
    } catch (error) {
      throw InvoiceExportException.save(error);
    }
  }

  Future<void> shareInvoicePdf(Invoice invoice) async {
    try {
      final generatedPdf = await _generatePdf(invoice);
      await Printing.sharePdf(
        bytes: generatedPdf.bytes,
        filename: generatedPdf.filename,
      );
    } catch (error) {
      throw InvoiceExportException.share(error);
    }
  }

  Future<InvoicePdfDocument> _generatePdf(Invoice invoice) async {
    final decision = await _subscriptionGatekeeper.evaluate(
      SubscriptionGateFeature.exportPdf,
    );

    return _pdfExportService.generateInvoicePdfDocument(
      invoice,
      includeWatermark: decision.shouldWatermarkPdf,
      isPro: decision.isPro,
      saveLocally: false,
      filename: _filenameForInvoice(invoice),
    );
  }

  Future<File> _saveToPublicStorage(InvoicePdfDocument generatedPdf) async {
    final filename = 'invoice_${_sanitizeFilename(generatedPdf.filename)}';
    final bytes = generatedPdf.bytes;

    if (Platform.isAndroid) {
      final status = await _requestStoragePermission();
      if (!status) {
        throw const InvoiceExportException._(
          'Storage permission denied. Cannot save to Downloads.',
        );
      }
    }

    final Directory downloadsDirectory;
    if (Platform.isAndroid) {
      downloadsDirectory = Directory(
        '/storage/emulated/0/Download/InvoiceFlow',
      );
    } else {
      downloadsDirectory = Directory(
        '${(await getApplicationDocumentsDirectory()).path}/InvoiceFlow',
      );
    }

    if (!await downloadsDirectory.exists()) {
      await downloadsDirectory.create(recursive: true);
    }

    final file = File('${downloadsDirectory.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<bool> _requestStoragePermission() async {
    if (await Permission.storage.isGranted) {
      return true;
    }

    final status = await Permission.storage.request();
    return status.isGranted;
  }

  String _filenameForInvoice(Invoice invoice) {
    final sanitizedId = invoice.id.trim().replaceAll(
      RegExp(r'[^A-Za-z0-9_-]'),
      '_',
    );
    final normalizedId = sanitizedId.isEmpty ? 'invoice' : sanitizedId;
    final upperId = normalizedId.toUpperCase();
    return upperId.startsWith('INV-')
        ? '$normalizedId.pdf'
        : 'INV-$normalizedId.pdf';
  }

  String _sanitizeFilename(String filename) {
    return filename.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }
}

class InvoiceExportException implements Exception {
  const InvoiceExportException._(this.message, [this.cause]);

  factory InvoiceExportException.save(Object cause) {
    return InvoiceExportException._('Failed to save invoice PDF.', cause);
  }

  factory InvoiceExportException.share(Object cause) {
    return InvoiceExportException._('Failed to share invoice PDF.', cause);
  }

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
