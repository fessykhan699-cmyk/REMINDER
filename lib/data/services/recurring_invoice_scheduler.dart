import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/invoices/domain/entities/invoice.dart';
import '../../features/invoices/domain/repositories/invoice_repository.dart';
import '../../features/invoices/presentation/controllers/invoices_controller.dart';
import '../../features/subscription/presentation/controllers/subscription_controller.dart';
import '../../data/services/invoice_numbering_service.dart';
import '../../features/settings/presentation/controllers/app_preferences_controller.dart';
import '../../data/services/analytics_service.dart';

final recurringInvoiceSchedulerProvider = Provider<RecurringInvoiceScheduler>((ref) {
  return RecurringInvoiceScheduler(ref);
});

class RecurringInvoiceScheduler {
  RecurringInvoiceScheduler(this._ref);

  final Ref _ref;

  Future<void> checkAndGenerateRecurringInvoices() async {
    try {
      // Step 1 — Subscription gate
      final subState = _ref.read(subscriptionControllerProvider).valueOrNull;
      if (subState == null || !subState.isPro) return;

      final repository = _ref.read(invoiceRepositoryProvider);
      // Fetching first page for now, in a real app might need a specific query for recurring
      final invoices = await repository.getInvoices(page: 1, pageSize: 100); 

      final recurringInvoices = invoices.where((i) => i.isRecurring).toList();
      if (recurringInvoices.isEmpty) return;

      final now = DateTime.now();
      final numberingService = _ref.read(invoiceNumberingServiceProvider);
      final prefs = _ref.read(appPreferencesControllerProvider).valueOrNull;
      
      if (prefs == null) return;

      bool generatedAny = false;

      for (final parent in recurringInvoices) {
        if (parent.recurringNextDate != null && 
            (parent.recurringNextDate!.isBefore(now) || 
             DateUtils.isSameDay(parent.recurringNextDate!, now))) {
          
          await _generateDraft(parent, numberingService, prefs, repository);
          generatedAny = true;
        }
      }

      if (generatedAny) {
        // Invalidate the controller to show new drafts
        _ref.invalidate(invoicesControllerProvider);
      }
    } catch (e) {
      debugPrint('RecurringInvoiceScheduler error: $e');
    }
  }

  Future<void> _generateDraft(
    Invoice parent, 
    InvoiceNumberingService numberingService,
    dynamic prefs,
    InvoiceRepository repository
  ) async {
    final nextDate = parent.recurringInterval.calculateNextDate(parent.recurringNextDate ?? DateTime.now());
    
    // Update parent next date
    final updatedParent = parent.copyWith(
      recurringNextDate: nextDate,
    );
    await repository.updateInvoice(updatedParent);

    // Create new draft
    final newInvoiceId = 'rec_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1000)}';
    final newInvoiceNumber = numberingService.getNextInvoiceNumber(prefs);
    
    final newInvoice = parent.copyWith(
      id: newInvoiceId,
      invoiceNumber: newInvoiceNumber,
      status: InvoiceStatus.draft,
      createdAt: DateTime.now(),
      dueDate: DateTime.now().add(Duration(days: parent.paymentTermsDays)),
      isRecurring: false, // The new copy isn't recurring itself
      recurringNextDate: null,
      recurringParentId: parent.id,
    );

    await repository.createInvoice(newInvoice);
    await numberingService.incrementNextInvoiceNumber();
    
    // Log to Analytics
    AnalyticsService.instance.logRecurringInvoiceCreated(
      parentInvoiceId: parent.id,
      newInvoiceId: newInvoice.id,
    );
    
    debugPrint('Generated recurring draft ${newInvoice.invoiceNumber} from parent ${parent.invoiceNumber}');
  }
}
