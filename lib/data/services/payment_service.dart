import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/invoices/domain/entities/invoice.dart';
import '../../domain/entities/payment.dart';
import '../../features/invoices/presentation/controllers/invoices_controller.dart';
import '../../features/subscription/presentation/controllers/subscription_controller.dart';

final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService(ref);
});

class PaymentService {
  PaymentService(this._ref);

  final Ref _ref;

  Future<Invoice?> addPayment({
    required Invoice invoice,
    required double amount,
    required DateTime date,
    String? note,
    String? paymentMethod,
  }) async {
    try {
      final subState = _ref.read(subscriptionControllerProvider).valueOrNull;
      if (subState == null || !subState.isPro) {
        return null;
      }

      if (amount <= 0 || amount > invoice.remainingBalance) {
        debugPrint('[PaymentService] Invalid payment amount: $amount');
        return null;
      }

      final newPayment = Payment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        amount: amount,
        date: date,
        note: note,
        paymentMethod: paymentMethod,
      );

      var updatedInvoice = invoice.copyWith(
        payments: [...invoice.payments, newPayment],
      );

      if (updatedInvoice.isFullyPaid) {
        updatedInvoice = updatedInvoice.copyWith(status: InvoiceStatus.paid);
      }

      final repository = _ref.read(invoiceRepositoryProvider);
      final saved = await repository.updateInvoice(updatedInvoice);
      
      return saved;
    } catch (e, st) {
      debugPrint('[PaymentService] addPayment failed: $e\n$st');
      return null;
    }
  }

  Future<Invoice?> removePayment({
    required Invoice invoice,
    required String paymentId,
  }) async {
    try {
      final updatedPayments = invoice.payments.where((p) => p.id != paymentId).toList();
      var updatedInvoice = invoice.copyWith(payments: updatedPayments);

      if (invoice.status == InvoiceStatus.paid && !updatedInvoice.isFullyPaid) {
        // Reset status
        final now = DateTime.now();
        if (updatedInvoice.dueDate.isBefore(now)) {
          updatedInvoice = updatedInvoice.copyWith(status: InvoiceStatus.overdue);
        } else {
          // If not overdue, set to 'sent' or whatever the previous state should be.
          // The Instructions say: "sent (or the existing pre-paid status)".
          // We'll use 'sent' as a safe default for a non-paid, non-overdue invoice that was once paid.
          updatedInvoice = updatedInvoice.copyWith(status: InvoiceStatus.sent);
        }
      }

      final repository = _ref.read(invoiceRepositoryProvider);
      final saved = await repository.updateInvoice(updatedInvoice);
      
      return saved;
    } catch (e, st) {
      debugPrint('[PaymentService] removePayment failed: $e\n$st');
      return null;
    }
  }

  double calculateTotalRevenue(List<Invoice> invoices) {
    double total = 0;
    for (final invoice in invoices) {
      for (final payment in invoice.payments) {
        total += payment.amount;
      }
    }
    return total;
  }

  double calculatePendingPayments(List<Invoice> invoices) {
    double total = 0;
    for (final invoice in invoices) {
      if (invoice.status != InvoiceStatus.paid) {
        total += invoice.remainingBalance;
      }
    }
    return total;
  }
}

final totalRevenueProvider = Provider<double>((ref) {
  final invoices = ref.watch(invoicesControllerProvider).valueOrNull ?? [];
  return ref.read(paymentServiceProvider).calculateTotalRevenue(invoices);
});

final pendingBalanceProvider = Provider<double>((ref) {
  final invoices = ref.watch(invoicesControllerProvider).valueOrNull ?? [];
  return ref.read(paymentServiceProvider).calculatePendingPayments(invoices);
});
