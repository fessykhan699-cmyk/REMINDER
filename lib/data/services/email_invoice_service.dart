import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import './analytics_service.dart';

import '../../core/storage/hive_storage.dart';
import '../../features/invoices/domain/entities/invoice.dart';
import '../../shared/services/invoice_pdf_export_service.dart';

final emailInvoiceServiceProvider = Provider<EmailInvoiceService>((ref) {
  return EmailInvoiceService(
    pdfService: ref.watch(invoicePdfExportServiceProvider),
  );
});

class EmailInvoiceService {
  final InvoicePdfExportService _pdfService;

  EmailInvoiceService({
    required InvoicePdfExportService pdfService,
  }) : _pdfService = pdfService;

  Future<bool> sendInvoiceEmail({
    required Invoice invoice,
    required String email,
    required bool isPro,
  }) async {
    try {
      final subject = "Invoice from ${invoice.clientName} - #${invoice.id}";
      final body = "Hi ${invoice.clientName},\n\nPlease find the attached invoice (#${invoice.id}) for your reference.\n\nThank you!";
      
      final mailtoUrl = "mailto:$email?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}";
      final mailtoUri = Uri.parse(mailtoUrl);

      // Try mailto first for simple compose
      bool mailtoSuccess = false;
      try {
        if (await canLaunchUrl(mailtoUri)) {
          mailtoSuccess = await launchUrl(mailtoUri);
          if (mailtoSuccess) {
            AnalyticsService.instance.logInvoiceShared('email');
          }
        }
      } catch (e) {
        debugPrint('EmailInvoiceService mailto error: $e');
      }

      // Generate PDF for the share fallback (attachment)
      final document = await _pdfService.generateInvoicePdfDocument(
        invoice,
        includeWatermark: !isPro,
        isPro: isPro,
        saveLocally: true,
      );

      if (document.savedFilePath != null) {
        // Fallback or secondary action: share the file via native share sheet
        // This is the only reliable way to send an attachment on mobile.
        await Share.shareXFiles(
          [XFile(document.savedFilePath!)],
          text: body,
          subject: subject,
        );
        
        // Log to Hive
        await _logEmailSent(invoice.id, email);
        
        AnalyticsService.instance.logInvoiceShared('email');
        
        return true;
      }
      
      return mailtoSuccess;
    } catch (e) {
      debugPrint('EmailInvoiceService.sendInvoiceEmail error: $e');
      return false;
    }
  }

  Future<void> _logEmailSent(String invoiceId, String email) async {
    try {
      final box = Hive.box(HiveStorage.settingsBoxName);
      final entryKey = 'email_invoice_${invoiceId}_${DateTime.now().millisecondsSinceEpoch}';
      await box.put(entryKey, {
        'timestamp': DateTime.now().toIso8601String(),
        'email': email,
        'type': 'pdf_email',
      });
    } catch (e) {
      debugPrint('EmailInvoiceService logging error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getEmailHistory(String invoiceId) async {
    try {
      final box = Hive.box(HiveStorage.settingsBoxName);
      final prefix = 'email_invoice_$invoiceId';
      final history = <Map<String, dynamic>>[];

      for (final key in box.keys) {
        if (key is String && key.startsWith(prefix)) {
          final entry = box.get(key);
          if (entry is Map) {
            history.add(Map<String, dynamic>.from(entry));
          }
        }
      }

      history.sort((a, b) => (b['timestamp'] as String).compareTo(a['timestamp'] as String));
      return history;
    } catch (e) {
      debugPrint('EmailInvoiceService.getEmailHistory error: $e');
      return [];
    }
  }
}
