import 'dart:io';

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
import '../../data/services/user_profile_image_service.dart';

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
  const InvoicePdfLineItem({
    required this.service,
    required this.amount,
    this.quantity = 1,
    this.unitPrice = 0,
  });

  final String service;
  final double amount;
  final double quantity;
  final double unitPrice;
}

class _InvoicePdfParty {
  const _InvoicePdfParty({
    required this.title,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
  });

  final String title;
  final String name;
  final String email;
  final String phone;
  final String address;
}

const String _logoAssetPath = 'assets/images/logo.png';

const double _spaceXs = 6;
const double _spaceSm = 10;
const double _spaceMd = 16;
const double _spaceLg = 24;
const double _spaceXl = 32;
const double _cardRadius = 10;

final PdfColor _pdfInk = PdfColor.fromHex('#1A1A1A');
final PdfColor _pdfMuted = PdfColor.fromHex('#6B7280');
final PdfColor _pdfBorder = PdfColor.fromHex('#E5E7EB');
final PdfColor _pdfSurface = PdfColor.fromHex('#F7F8FA');
final PdfColor _pdfAccent = PdfColor.fromHex('#C8A96A');
final PdfColor _pdfWatermark = PdfColor.fromHex('#F3F4F6');

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
    required bool isPro,
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
      isPro: isPro,
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
  bool isPro = false,
}) async {
  // Load custom assets from UserProfileImageService
  final customLogoPath = await UserProfileImageService.getLogoPath();
  final customSignaturePath = await UserProfileImageService.getSignaturePath();

  pw.MemoryImage? customLogo;
  if (customLogoPath != null) {
    try {
      final file = File(customLogoPath);
      if (await file.exists()) {
        customLogo = pw.MemoryImage(await file.readAsBytes());
      }
    } catch (_) {}
  }

  pw.MemoryImage? customSignature;
  if (customSignaturePath != null) {
    try {
      final file = File(customSignaturePath);
      if (await file.exists()) {
        customSignature = pw.MemoryImage(await file.readAsBytes());
      }
    } catch (_) {}
  }

  // Load default app logo as fallback
  pw.MemoryImage? defaultLogo;
  try {
    final assetBytes =
        (await rootBundle.load(_logoAssetPath)).buffer.asUint8List();
    defaultLogo = pw.MemoryImage(assetBytes);
  } catch (_) {}

  final lineItems = _resolveLineItems(invoice, items);
  final subtotalAmount = invoice.subtotalAmount;
  final discountAmount = invoice.appliedDiscountAmount;
  final taxAmount = invoice.taxAmount;
  final totalAmount = invoice.amount;
  final generatedAt = DateTime.now();
  final brandName = _resolveBrandName(senderProfile, isPro: isPro);
  final subtotalLabel = AppFormatters.currency(
    subtotalAmount,
    currencyCode: invoice.currencyCode,
  );
  final discountLabel = discountAmount > 0
      ? AppFormatters.currency(
          discountAmount,
          currencyCode: invoice.currencyCode,
        )
      : null;
  final taxLabel = AppFormatters.currency(
    taxAmount,
    currencyCode: invoice.currencyCode,
  );
  final totalLabel = AppFormatters.currency(
    totalAmount,
    currencyCode: invoice.currencyCode,
  );
  final fromParty = _InvoicePdfParty(
    title: 'BILL FROM',
    name: _displayValue(senderProfile?.displayBusinessName, 'Your Business'),
    email: _displayValue(senderProfile?.email, 'Not provided'),
    phone: _displayValue(senderProfile?.phone, 'Not provided'),
    address: senderProfile?.address.trim() ?? '',
  );
  final toParty = _InvoicePdfParty(
    title: 'BILL TO',
    name: _displayValue(client?.name, invoice.clientName),
    email: _displayValue(client?.email, 'Not provided'),
    phone: _displayValue(client?.phone, 'Not provided'),
    address: '',
  );
  final document = pw.Document();

  document.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        buildBackground: includeWatermark && !isPro
            ? (context) => _buildWatermark()
            : null,
      ),
      build: (context) => <pw.Widget>[
        _buildHeader(
          logoImage: defaultLogo,
          customLogo: customLogo,
          brandName: brandName,
        ),
        pw.SizedBox(height: _spaceLg),
        _buildDetailsRow(invoice),
        pw.SizedBox(height: _spaceLg),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: _infoBox(
                title: fromParty.title,
                name: fromParty.name,
                email: fromParty.email,
                phone: fromParty.phone,
                address: fromParty.address,
              ),
            ),
            pw.SizedBox(width: _spaceMd),
            pw.Expanded(
              child: _infoBox(
                title: toParty.title,
                name: toParty.name,
                email: toParty.email,
                phone: toParty.phone,
                address: toParty.address,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: _spaceLg),
        _buildItemsTable(
          lineItems,
          currencyCode: invoice.currencyCode,
          totalLabel: totalLabel,
        ),
        pw.SizedBox(height: _spaceLg),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: _buildTotalsBox(
            subtotalLabel: subtotalLabel,
            discountLabel: discountLabel,
            taxLabel: taxLabel,
            totalLabel: totalLabel,
            taxPercent: invoice.taxPercent,
            taxAmount: invoice.taxAmount,
          ),
        ),
        if (invoice.hasNotes) ...[
          pw.SizedBox(height: _spaceMd),
          _buildNotesSection(invoice.normalizedNotes!),
        ],
        if (invoice.hasPaymentLink) ...[
          pw.SizedBox(height: _spaceMd),
          _buildPaymentSection(invoice.normalizedPaymentLink!),
        ],
        if (customSignature != null) ...[
          pw.SizedBox(height: _spaceLg),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Container(
                  constraints: const pw.BoxConstraints(maxWidth: 150, maxHeight: 40),
                  child: pw.Image(customSignature, fit: pw.BoxFit.contain),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Authorized Signature',
                  style: pw.TextStyle(
                    color: _pdfMuted,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
        pw.SizedBox(height: _spaceXl),
        _buildFooter(brandName: brandName, generatedAt: generatedAt),
      ],
    ),
  );

  return document;
}

pw.Widget _buildHeader({
  required pw.MemoryImage? logoImage,
  required pw.MemoryImage? customLogo,
  required String brandName,
}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      if (customLogo != null) ...[
        pw.Container(
          constraints: const pw.BoxConstraints(maxWidth: 120, maxHeight: 60),
          child: pw.Image(customLogo, fit: pw.BoxFit.contain),
        ),
        pw.SizedBox(height: _spaceLg),
      ],
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (customLogo == null && logoImage != null) ...[
                  pw.Container(
                    width: 40,
                    height: 40,
                    child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                  ),
                  pw.SizedBox(width: _spaceSm),
                ],
                pw.Expanded(
                  child: pw.Text(
                    brandName,
                    style: pw.TextStyle(
                      color: _pdfInk,
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          pw.Text(
            'INVOICE',
            style: pw.TextStyle(
              color: _pdfInk,
              fontSize: 28,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
      pw.SizedBox(height: _spaceMd),
      pw.Container(height: 2, color: _pdfAccent),
      pw.SizedBox(height: _spaceLg),
    ],
  );
}

pw.Widget _buildDetailsRow(Invoice invoice) {
  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _pdfBorder, width: 0.5)),
    ),
    padding: const pw.EdgeInsets.symmetric(vertical: 14),
    child: pw.Row(
      children: [
        pw.Expanded(child: _buildDetailCell('Invoice #', invoice.invoiceNumber)),
        pw.Container(width: 1, height: 32, color: _pdfBorder),
        pw.Expanded(
          child: _buildDetailCell('Issue Date', _dateLabel(invoice.createdAt)),
        ),
        pw.Container(width: 1, height: 32, color: _pdfBorder),
        pw.Expanded(
          child: _buildDetailCell('Due Date', _dateLabel(invoice.dueDate)),
        ),
      ],
    ),
  );
}

pw.Widget _buildDetailCell(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 12),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            color: _pdfMuted,
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 0.4,
          ),
        ),
        pw.SizedBox(height: _spaceXs),
        pw.Text(
          value,
          style: pw.TextStyle(
            color: _pdfInk,
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

pw.Widget _buildFooter({
  required String brandName,
  required DateTime generatedAt,
}) {
  return pw.Column(
    children: [
      pw.Divider(color: _pdfBorder, height: 1),
      pw.SizedBox(height: _spaceMd),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Thank you for your business!',
            style: pw.TextStyle(
              color: _pdfMuted,
              fontSize: 10,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                brandName,
                style: pw.TextStyle(
                  color: _pdfInk,
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Generated ${_dateLabel(generatedAt)}',
                style: pw.TextStyle(color: _pdfMuted, fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

pw.Widget _sectionLabel(String label) {
  return pw.Text(
    label,
    style: pw.TextStyle(
      color: _pdfMuted,
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
      letterSpacing: 0.8,
    ),
  );
}

pw.Widget _infoBox({
  required String title,
  required String name,
  required String email,
  required String phone,
  required String address,
}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        title,
        style: pw.TextStyle(
          color: _pdfAccent,
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
      pw.SizedBox(height: _spaceSm),
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          color: _pdfSurface,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              name,
              style: pw.TextStyle(
                color: _pdfInk,
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: _spaceXs),
            pw.Text(email, style: pw.TextStyle(color: _pdfMuted, fontSize: 10)),
            pw.SizedBox(height: 4),
            pw.Text(phone, style: pw.TextStyle(color: _pdfMuted, fontSize: 10)),
            if (address.trim().isNotEmpty) ...[
              pw.SizedBox(height: 4),
              pw.Text(
                address,
                style: pw.TextStyle(color: _pdfMuted, fontSize: 10),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

pw.Widget _buildItemsTable(
  List<InvoicePdfLineItem> items, {
  required String currencyCode,
  required String totalLabel,
}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'Description',
        style: pw.TextStyle(
          color: _pdfInk,
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
      pw.SizedBox(height: _spaceSm),
      pw.Table(
        columnWidths: const <int, pw.TableColumnWidth>{
          0: pw.FlexColumnWidth(4),
          1: pw.FlexColumnWidth(1.5),
          2: pw.FlexColumnWidth(2),
          3: pw.FlexColumnWidth(2),
        },
        children: <pw.TableRow>[
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: _pdfSurface,
              border: pw.Border(
                bottom: pw.BorderSide(color: _pdfBorder, width: 0.5),
              ),
            ),
            children: [
              _buildTableHeaderCell('Description'),
              _buildTableHeaderCell('Quantity', alignRight: true),
              _buildTableHeaderCell('Unit Price', alignRight: true),
              _buildTableHeaderCell('Amount', alignRight: true),
            ],
          ),
          ...List<pw.TableRow>.generate(items.length, (index) {
            final item = items[index];
            return pw.TableRow(
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: _pdfBorder, width: 0.5),
                ),
              ),
              children: [
                _buildTableBodyCell(item.service),
                _buildTableBodyCell(
                  item.quantity.toStringAsFixed(item.quantity == item.quantity.toInt() ? 0 : 2),
                  alignRight: true,
                ),
                _buildTableBodyCell(
                  AppFormatters.currency(
                    item.unitPrice,
                    currencyCode: currencyCode,
                  ),
                  alignRight: true,
                ),
                _buildTableBodyCell(
                  AppFormatters.currency(
                    item.amount,
                    currencyCode: currencyCode,
                  ),
                  alignRight: true,
                  emphasize: true,
                ),
              ],
            );
          }),
          pw.TableRow(
            decoration: pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: _pdfBorder, width: 0.5),
              ),
            ),
            children: [
              _buildTableBodyCell('Total', emphasize: true),
              pw.SizedBox(),
              pw.SizedBox(),
              _buildTableBodyCell(
                totalLabel,
                alignRight: true,
                emphasize: true,
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

pw.Widget _buildTableHeaderCell(String label, {bool alignRight = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(10),
    child: pw.Text(
      label,
      textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
      style: pw.TextStyle(
        color: _pdfMuted,
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
      ),
    ),
  );
}

pw.Widget _buildTableBodyCell(
  String value, {
  bool alignRight = false,
  bool emphasize = false,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(10),
    child: pw.Text(
      value,
      textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
      style: pw.TextStyle(
        color: _pdfInk,
        fontSize: 11,
        fontWeight: emphasize ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
}

pw.Widget _buildTotalsBox({
  required String subtotalLabel,
  required String? discountLabel,
  required String taxLabel,
  required String totalLabel,
  required double taxPercent,
  required double taxAmount,
}) {
  return pw.Container(
    width: 220,
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _summaryLine('Subtotal', subtotalLabel),
        if (discountLabel != null) ...[
          pw.SizedBox(height: _spaceSm),
          _summaryLine('Discount', '-$discountLabel'),
        ],
        if (taxPercent > 0 || taxAmount > 0) ...[
          pw.SizedBox(height: _spaceSm),
          _summaryLine(
            'Tax (${taxPercent.toStringAsFixed(0)}%)',
            taxLabel,
          ),
        ],
        pw.SizedBox(height: _spaceSm),
        pw.Divider(color: _pdfBorder, height: 1),
        pw.SizedBox(height: _spaceSm),
        _summaryLine('TOTAL', totalLabel, emphasize: true),
      ],
    ),
  );
}

pw.Widget _buildNotesSection(String notes) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(14),
    decoration: pw.BoxDecoration(
      color: _pdfSurface,
      borderRadius: pw.BorderRadius.circular(_cardRadius),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionLabel('NOTES'),
        pw.SizedBox(height: _spaceSm),
        pw.Text(
          notes,
          style: pw.TextStyle(color: _pdfInk, fontSize: 10, lineSpacing: 3),
        ),
      ],
    ),
  );
}

pw.Widget _buildPaymentSection(String paymentLink) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(14),
    decoration: pw.BoxDecoration(
      color: _pdfSurface,
      borderRadius: pw.BorderRadius.circular(_cardRadius),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionLabel('PAYMENT LINK'),
        pw.SizedBox(height: _spaceSm),
        pw.UrlLink(
          destination: paymentLink,
          child: pw.Text(
            paymentLink,
            style: pw.TextStyle(
              color: _pdfAccent,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              decoration: pw.TextDecoration.underline,
            ),
          ),
        ),
      ],
    ),
  );
}


pw.Widget _buildWatermark() {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(32),
    child: pw.Watermark.text(
      AppConstants.aboutAppName.toUpperCase(),
      angle: -0.45,
      style: pw.TextStyle(
        color: _pdfWatermark,
        fontSize: 82,
        fontWeight: pw.FontWeight.bold,
        letterSpacing: 3,
      ),
    ),
  );
}

pw.Widget _summaryLine(String label, String value, {bool emphasize = false}) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(
        label,
        style: pw.TextStyle(
          color: emphasize ? _pdfAccent : _pdfInk,
          fontSize: emphasize ? 13 : 11,
          fontWeight: emphasize ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
      pw.Text(
        value,
        style: pw.TextStyle(
          color: emphasize ? _pdfAccent : _pdfInk,
          fontSize: emphasize ? 13 : 11,
          fontWeight: emphasize ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
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

  if (invoice.items.isNotEmpty) {
    return invoice.items
        .map(
          (item) => InvoicePdfLineItem(
            service: item.description,
            amount: item.amount,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
          ),
        )
        .toList();
  }

  return <InvoicePdfLineItem>[
    InvoicePdfLineItem(
      service: invoice.service.trim().isEmpty ? 'Service' : invoice.service,
      amount: invoice.subtotalAmount,
      quantity: 1,
      unitPrice: invoice.subtotalAmount,
    ),
  ];
}


String _resolveBrandName(
  InvoicePdfSenderProfile? senderProfile, {
  required bool isPro,
}) {
  if (!isPro) {
    return AppConstants.aboutAppName;
  }

  final businessName = senderProfile?.businessName.trim() ?? '';
  if (businessName.isNotEmpty) {
    return businessName;
  }

  final senderName = senderProfile?.displayBusinessName.trim() ?? '';
  return senderName.isEmpty ? AppConstants.aboutAppName : senderName;
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
