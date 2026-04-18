import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/services/analytics_service.dart';

import '../../features/invoices/domain/entities/invoice.dart';
import '../../features/clients/domain/entities/client.dart';

final csvExportServiceProvider = Provider<CsvExportService>((ref) {
  return const CsvExportService();
});

class CsvExportService {
  const CsvExportService();

  Future<void> exportInvoicesToCsv({
    required List<Invoice> invoices,
    required List<Client> clients,
  }) async {
    try {
      final Map<String, Client> clientMap = {for (var c in clients) c.id: c};
      
      final List<List<dynamic>> rows = [];
      
      // Header
      rows.add([
        'Invoice #',
        'Date Created',
        'Client Name',
        'Client Email',
        'Status',
        'Subtotal',
        'Tax %',
        'Tax Amount',
        'Discount',
        'Total Amount',
        'Paid Amount',
        'Balance',
        'Due Date',
        'Notes',
      ]);
      
      final dateFormat = DateFormat('yyyy-MM-dd');
      
      for (final invoice in invoices) {
        final client = clientMap[invoice.clientId];
        rows.add([
          invoice.invoiceNumber,
          dateFormat.format(invoice.createdAt),
          invoice.clientName,
          client?.email ?? '',
          invoice.status.label,
          invoice.subtotalAmount.toStringAsFixed(2),
          invoice.taxPercent.toStringAsFixed(2),
          invoice.taxAmount.toStringAsFixed(2),
          invoice.discountAmount.toStringAsFixed(2),
          invoice.amount.toStringAsFixed(2),
          invoice.totalPaid.toStringAsFixed(2),
          invoice.remainingBalance.toStringAsFixed(2),
          dateFormat.format(invoice.dueDate),
          invoice.notes ?? '',
        ]);
      }
      
      final String csvData = const ListToCsvConverter().convert(rows);
      
      final directory = await getTemporaryDirectory();
      final String path = '${directory.path}/invoices_export_${DateTime.now().millisecondsSinceEpoch}.csv';
      final File file = File(path);
      await file.writeAsString(csvData);
      
      final dateStr = dateFormat.format(DateTime.now());
      await Share.shareXFiles(
        [XFile(path)],
        subject: 'Invoices Export $dateStr',
        text: 'Attached is the exported list of invoices from InvoiceFlow.',
      );
      
      AnalyticsService.instance.logCsvExported();
    } catch (e) {
      debugPrint('CsvExportService.exportInvoicesToCsv error: $e');
      rethrow;
    }
  }
}
