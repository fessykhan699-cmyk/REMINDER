import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/invoices/domain/entities/invoice.dart';
import '../../features/invoices/domain/entities/line_item.dart';
import '../../features/invoices/presentation/controllers/invoice_prediction_engine.dart';
import '../../features/invoices/presentation/controllers/invoice_creation_learning_controller.dart';
import '../../features/invoices/presentation/controllers/invoices_controller.dart';
import '../../features/settings/presentation/controllers/app_preferences_controller.dart';
import 'invoice_numbering_service.dart';

final oneTapInvoiceServiceProvider = Provider<OneTapInvoiceService>((ref) {
  return OneTapInvoiceService(ref);
});

class OneTapInvoiceService {
  final Ref ref;

  OneTapInvoiceService(this.ref);

  Future<Invoice?> createInstantInvoice() async {
    try {
      final intelligence = ref.read(smartInvoicePredictionProvider);
      
      // Use the primary action decision to get the most reliable candidate
      final decision = intelligence.buildPrimaryActionDecision();
      
      // We only proceed if we are in 'instant' mode
      if (decision.mode != InvoiceAutomationMode.instant) {
        return null;
      }

      final draft = decision.draft;
      if (draft == null) return null;

      final client = draft.client;
      if (client == null) return null;
      
      final prefs = ref.read(appPreferencesControllerProvider).valueOrNull;
      if (prefs == null) return null;

      final invoiceNumber = ref.read(invoiceNumberingServiceProvider).getNextInvoiceNumber(prefs);

      final now = DateTime.now();
      final service = draft.service.isEmpty ? 'Consultation' : draft.service;
      final amount = draft.amount;
      
      final invoice = Invoice(
        id: '', // Set by repository
        clientId: client.id,
        clientName: client.name,
        invoiceNumber: invoiceNumber,
        service: service,
        amount: amount,
        status: InvoiceStatus.draft,
        createdAt: now,
        dueDate: draft.dueDate,
        items: [
          LineItem(
            id: now.millisecondsSinceEpoch.toString(),
            description: service,
            quantity: 1,
            unitPrice: amount,
          ),
        ],
        currencyCode: prefs.defaultCurrency,
      );

      final createdInvoice = await ref.read(invoicesControllerProvider.notifier).createInvoice(invoice);

      // Record successful outcome for the prediction engine
      try {
        await ref.read(invoiceCreationLearningProvider.notifier).recordPredictionOutcome(
          predictedClientId: client.id,
          predictedService: draft.service,
          predictedAmount: draft.amount,
          predictedDueDate: draft.dueDate,
          actualInvoice: createdInvoice,
        );
      } catch (e) {
        // Safe to ignore learning errors
      }

      return createdInvoice;
    } catch (e) {
      // One-tap invoice errors must never crash the app.
      return null;
    }
  }
}
