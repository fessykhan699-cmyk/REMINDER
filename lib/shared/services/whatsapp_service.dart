import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils/formatters.dart';
import '../../features/clients/domain/repositories/client_repository.dart';
import '../../features/clients/presentation/controllers/clients_controller.dart';
import '../../features/invoices/domain/entities/invoice.dart';
import 'invoice_export_service.dart';

final whatsAppServiceProvider = Provider<WhatsAppService>(
  (ref) => WhatsAppService(
    invoiceExportService: ref.watch(invoiceExportServiceProvider),
    clientRepository: ref.watch(clientRepositoryProvider),
  ),
);

class WhatsAppLaunchResult {
  const WhatsAppLaunchResult({required this.usedFallbackShareSheet});

  final bool usedFallbackShareSheet;
}

class WhatsAppService {
  const WhatsAppService({
    required InvoiceExportService invoiceExportService,
    required ClientRepository clientRepository,
  }) : _invoiceExportService = invoiceExportService,
       _clientRepository = clientRepository;

  final InvoiceExportService _invoiceExportService;
  final ClientRepository _clientRepository;

  Future<WhatsAppLaunchResult> sendInvoiceReminder({
    required Invoice invoice,
    String? phoneNumber,
    String? customMessage,
  }) async {
    final resolvedPhone =
        phoneNumber ??
        (await _clientRepository.getClientById(invoice.clientId))?.phone;
    final normalizedPhone = _digitsOnly(resolvedPhone);
    if (normalizedPhone.length < 8 || normalizedPhone.length > 15) {
      throw const WhatsAppServiceException(
        'Client phone number is missing or invalid.',
      );
    }

    final message = (customMessage?.trim().isNotEmpty ?? false)
        ? customMessage!.trim()
        : buildReminderMessage(invoice);

    final uri = Uri.parse(
      'https://wa.me/$normalizedPhone?text=${Uri.encodeComponent(message)}',
    );

    try {
      final openedWhatsApp = await launchUrl(
        uri,
        mode: LaunchMode.externalNonBrowserApplication,
      );
      if (openedWhatsApp) {
        return const WhatsAppLaunchResult(usedFallbackShareSheet: false);
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to launch WhatsApp for invoice ${invoice.id}: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    await _invoiceExportService.shareInvoicePdf(invoice);
    return const WhatsAppLaunchResult(usedFallbackShareSheet: true);
  }

  String buildReminderMessage(Invoice invoice) {
    final amount = AppFormatters.currency(
      invoice.amount,
      currencyCode: invoice.currencyCode,
    );
    final lines = <String>[
      'Hi ${invoice.clientName},',
      'This is a reminder for invoice ${invoice.id} of $amount.',
      'Due on ${AppFormatters.shortDate(invoice.dueDate)}.',
    ];

    if (invoice.hasPaymentLink) {
      lines
        ..add('')
        ..add('You can view or pay here: ${invoice.normalizedPaymentLink}');
    }

    return lines.join('\n');
  }

  String _digitsOnly(String? input) {
    return (input ?? '').replaceAll(RegExp(r'[^0-9]'), '');
  }
}

class WhatsAppServiceException implements Exception {
  const WhatsAppServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
