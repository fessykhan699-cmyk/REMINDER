import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/formatters.dart';
import '../../features/clients/domain/entities/client.dart';
import '../../features/clients/domain/repositories/client_repository.dart';
import '../../features/clients/presentation/controllers/clients_controller.dart';
import '../../features/invoices/domain/entities/invoice.dart';
import 'invoice_pdf_profile_hook.dart';
import 'pdf_file_storage.dart';

final invoicePdfExportServiceProvider = Provider<InvoicePdfExportService>(
  (ref) => InvoicePdfExportService(
    profileHook: ref.watch(invoicePdfProfileHookProvider),
    clientRepository: ref.watch(clientRepositoryProvider),
  ),
);

class InvoicePdfDocument {
  const InvoicePdfDocument({
    required this.bytes,
    required this.filename,
    this.savedFilePath,
  });

  final Uint8List bytes;
  final String filename;
  final String? savedFilePath;
}

class InvoicePdfLineItem {
  const InvoicePdfLineItem({required this.service, required this.amount});

  final String service;
  final double amount;
}

class _InvoicePdfParty {
  const _InvoicePdfParty({
    required this.title,
    required this.name,
    required this.email,
    required this.phone,
  });

  final String title;
  final String name;
  final String email;
  final String phone;
}

const String _logoAssetPath = 'assets/logo.png';

final PdfColor _pdfBlack = PdfColor.fromHex('#111111');
final PdfColor _pdfGold = PdfColor.fromHex('#C9A24A');
final PdfColor _pdfWhite = PdfColors.white;
final PdfColor _pdfInk = PdfColor.fromHex('#18181B');
final PdfColor _pdfMuted = PdfColor.fromHex('#6B7280');
final PdfColor _pdfBorder = PdfColor.fromHex('#E5E7EB');
final PdfColor _pdfHeaderSurface = PdfColor.fromHex('#F3F4F6');

class InvoicePdfExportService {
  InvoicePdfExportService({
    required InvoicePdfProfileHook profileHook,
    required ClientRepository clientRepository,
  }) : _profileHook = profileHook,
       _clientRepository = clientRepository;

  final InvoicePdfProfileHook _profileHook;
  final ClientRepository _clientRepository;

  Future<InvoicePdfDocument> generateInvoicePdfDocument(
    Invoice invoice, {
    required bool includeWatermark,
    bool saveLocally = false,
    String? filename,
  }) async {
    final senderProfile = await _profileHook.loadSenderProfile();
    final client = await _clientRepository.getClientById(invoice.clientId);
    final document = await buildInvoicePdf(
      invoice,
      senderProfile: senderProfile,
      client: client,
      includeWatermark: includeWatermark,
    );

    final bytes = await document.save();
    final resolvedFilename = filename ?? _filenameForInvoice(invoice);
    String? savedFilePath;
    if (saveLocally) {
      try {
        savedFilePath = await savePdfBytesToLocalFile(bytes, resolvedFilename);
      } catch (_) {
        savedFilePath = null;
      }
    }

    return InvoicePdfDocument(
      bytes: bytes,
      filename: resolvedFilename,
      savedFilePath: savedFilePath,
    );
  }

  Future<void> shareInvoicePdfDocument(InvoicePdfDocument document) async {
    await Printing.sharePdf(bytes: document.bytes, filename: document.filename);
  }

  String _filenameForInvoice(Invoice invoice) {
    final sanitizedId = invoice.id.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9_-]'),
      '_',
    );
    return 'invoice_$sanitizedId.pdf';
  }
}

Future<pw.Document> buildInvoicePdf(
  Invoice invoice, {
  InvoicePdfSenderProfile? senderProfile,
  Client? client,
  List<InvoicePdfLineItem>? items,
  bool includeWatermark = false,
}) async {
  final logoBytes = await rootBundle.load(_logoAssetPath);
  final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
  final lineItems = _resolveLineItems(invoice, items);
  final subtotalAmount = lineItems.fold<double>(
    0,
    (sum, item) => sum + item.amount,
  );
  final taxAmount = invoice.taxPercent > 0
      ? invoice.amount - subtotalAmount
      : 0.0;
  final totalAmount = subtotalAmount + taxAmount;
  final totalLabel = AppFormatters.currency(
    totalAmount,
    currencyCode: invoice.currencyCode,
  );
  final fromParty = _InvoicePdfParty(
    title: 'FROM',
    name: _displayValue(senderProfile?.displayBusinessName, 'Your Business'),
    email: _displayValue(senderProfile?.email, 'Not provided'),
    phone: _displayValue(senderProfile?.phone, 'Not provided'),
  );
  final toParty = _InvoicePdfParty(
    title: 'TO',
    name: _displayValue(client?.name, invoice.clientName),
    email: _displayValue(client?.email, 'Not provided'),
    phone: _displayValue(client?.phone, 'Not provided'),
  );
  final document = pw.Document();

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (_) => _buildHeader(logoImage),
      footer: (_) =>
          _buildFooter(totalLabel, includeWatermark: includeWatermark),
      build: (context) => <pw.Widget>[
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(40, 28, 40, 0),
          child: pw.Text(
            'INVOICE',
            style: pw.TextStyle(
              fontSize: 28,
              fontWeight: pw.FontWeight.bold,
              color: _pdfInk,
              letterSpacing: 1.8,
            ),
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 40),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _meta(label: 'Invoice ID', value: invoice.id),
              ),
              pw.SizedBox(width: 16),
              pw.Expanded(
                child: _meta(
                  label: 'Issue Date',
                  value: _dateLabel(invoice.createdAt),
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Expanded(
                child: _meta(
                  label: 'Due Date',
                  value: _dateLabel(invoice.dueDate),
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 24),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 40),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _infoBox(
                  title: fromParty.title,
                  name: fromParty.name,
                  email: fromParty.email,
                  phone: fromParty.phone,
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Expanded(
                child: _infoBox(
                  title: toParty.title,
                  name: toParty.name,
                  email: toParty.email,
                  phone: toParty.phone,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 24),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 40),
          child: _buildItemsTable(
            lineItems,
            currencyCode: invoice.currencyCode,
          ),
        ),
        pw.SizedBox(height: 20),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 40),
          child: pw.Align(
            alignment: pw.Alignment.centerRight,
            child: _buildTotalsBox(
              subtotalLabel: AppFormatters.currency(
                subtotalAmount,
                currencyCode: invoice.currencyCode,
              ),
              taxLabel: AppFormatters.currency(
                taxAmount,
                currencyCode: invoice.currencyCode,
              ),
              totalLabel: totalLabel,
              taxPercent: invoice.taxPercent,
            ),
          ),
        ),
        if (invoice.hasPaymentLink) ...[
          pw.SizedBox(height: 20),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 40),
            child: _buildPaymentSection(invoice.normalizedPaymentLink!),
          ),
        ],
        pw.SizedBox(height: 16),
      ],
    ),
  );

  return document;
}

pw.Widget _buildHeader(pw.MemoryImage logoImage) {
  return pw.Container(
    width: double.infinity,
    color: _pdfBlack,
    padding: const pw.EdgeInsets.fromLTRB(40, 24, 40, 22),
    child: pw.Column(
      children: [
        pw.Image(logoImage, width: 44, height: 44, fit: pw.BoxFit.contain),
        pw.SizedBox(height: 10),
        pw.Text(
          AppConstants.aboutAppName,
          style: pw.TextStyle(
            color: _pdfWhite,
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 0.6,
          ),
        ),
      ],
    ),
  );
}

pw.Widget _buildFooter(String totalLabel, {required bool includeWatermark}) {
  return pw.Container(
    width: double.infinity,
    color: _pdfBlack,
    padding: const pw.EdgeInsets.fromLTRB(40, 14, 40, 14),
    child: pw.Row(
      mainAxisAlignment: includeWatermark
          ? pw.MainAxisAlignment.spaceBetween
          : pw.MainAxisAlignment.end,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (includeWatermark)
          pw.Text(
            'Generated by ${AppConstants.aboutAppName}',
            style: pw.TextStyle(
              color: PdfColor.fromHex('#D4D4D8'),
              fontSize: 9,
            ),
          ),
        pw.Text(
          totalLabel,
          style: pw.TextStyle(
            color: _pdfGold,
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    ),
  );
}

pw.Widget _meta({required String label, required String value}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        label,
        style: pw.TextStyle(
          color: _pdfMuted,
          fontSize: 10,
          fontWeight: pw.FontWeight.normal,
          letterSpacing: 0.3,
        ),
      ),
      pw.SizedBox(height: 8),
      pw.Text(
        value,
        style: pw.TextStyle(
          color: _pdfInk,
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    ],
  );
}

pw.Widget _infoBox({
  required String title,
  required String name,
  required String email,
  required String phone,
}) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(16),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _pdfBorder),
      borderRadius: pw.BorderRadius.circular(14),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            color: _pdfMuted,
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 0.9,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          name,
          style: pw.TextStyle(
            color: _pdfInk,
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(email, style: pw.TextStyle(color: _pdfInk, fontSize: 11)),
        pw.SizedBox(height: 8),
        pw.Text(phone, style: pw.TextStyle(color: _pdfInk, fontSize: 11)),
      ],
    ),
  );
}

pw.Widget _buildItemsTable(
  List<InvoicePdfLineItem> items, {
  required String currencyCode,
}) {
  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _pdfBorder),
      borderRadius: pw.BorderRadius.circular(14),
    ),
    child: pw.Table(
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _pdfBorder),
        verticalInside: pw.BorderSide(color: _pdfBorder),
      ),
      columnWidths: const <int, pw.TableColumnWidth>{
        0: pw.FlexColumnWidth(2.8),
        1: pw.FlexColumnWidth(1.2),
      },
      children: [
        _row(service: 'Service', amount: 'Amount', header: true),
        for (final item in items)
          _row(
            service: item.service,
            amount: AppFormatters.currency(
              item.amount,
              currencyCode: currencyCode,
            ),
          ),
      ],
    ),
  );
}

pw.TableRow _row({
  required String service,
  required String amount,
  bool header = false,
}) {
  return pw.TableRow(
    decoration: header
        ? pw.BoxDecoration(color: _pdfHeaderSurface)
        : const pw.BoxDecoration(),
    children: [
      _cell(service, header: header),
      _cell(amount, header: header, alignRight: true),
    ],
  );
}

pw.Widget _cell(String value, {bool header = false, bool alignRight = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.fromLTRB(16, 12, 16, 12),
    child: pw.Align(
      alignment: alignRight
          ? pw.Alignment.centerRight
          : pw.Alignment.centerLeft,
      child: pw.Text(
        value,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          color: _pdfInk,
          fontSize: 11,
          fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    ),
  );
}

pw.Widget _buildTotalsBox({
  required String subtotalLabel,
  required String taxLabel,
  required String totalLabel,
  required double taxPercent,
}) {
  return pw.Container(
    width: 232,
    padding: const pw.EdgeInsets.all(16),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _pdfBorder),
      borderRadius: pw.BorderRadius.circular(14),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _summaryLine('Subtotal', subtotalLabel),
        pw.SizedBox(height: 8),
        _summaryLine(
          'Tax${taxPercent > 0 ? ' (${taxPercent.toStringAsFixed(0)}%)' : ''}',
          taxLabel,
        ),
        pw.SizedBox(height: 12),
        pw.Divider(color: _pdfBorder, height: 1),
        pw.SizedBox(height: 12),
        _summaryLine('Total', totalLabel, emphasize: true),
      ],
    ),
  );
}

pw.Widget _buildPaymentSection(String paymentLink) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(16),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _pdfBorder),
      borderRadius: pw.BorderRadius.circular(14),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'PAY NOW',
          style: pw.TextStyle(
            color: _pdfMuted,
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 0.9,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.UrlLink(
          destination: paymentLink,
          child: pw.Text(
            'Pay securely online: $paymentLink',
            style: pw.TextStyle(
              color: _pdfGold,
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              decoration: pw.TextDecoration.underline,
            ),
          ),
        ),
      ],
    ),
  );
}

pw.Widget _summaryLine(String label, String value, {bool emphasize = false}) {
  final textStyle = pw.TextStyle(
    color: emphasize ? _pdfGold : _pdfInk,
    fontSize: emphasize ? 14 : 11,
    fontWeight: emphasize ? pw.FontWeight.bold : pw.FontWeight.normal,
  );

  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(label, style: textStyle),
      pw.Text(value, style: textStyle),
    ],
  );
}

List<InvoicePdfLineItem> _resolveLineItems(
  Invoice invoice,
  List<InvoicePdfLineItem>? items,
) {
  if (items != null && items.isNotEmpty) {
    return items;
  }

  return <InvoicePdfLineItem>[
    InvoicePdfLineItem(
      service: invoice.service.trim().isEmpty ? 'Service' : invoice.service,
      amount: invoice.subtotalAmount,
    ),
  ];
}

String _displayValue(String? value, String fallback) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? fallback : trimmed;
}

String _dateLabel(DateTime value) {
  const monthLabels = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final month = monthLabels[value.month - 1];
  final day = value.day.toString().padLeft(2, '0');
  return '$month $day, ${value.year}';
}
