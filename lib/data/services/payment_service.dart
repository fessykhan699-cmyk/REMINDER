import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/invoices/domain/entities/invoice.dart';
import '../../domain/entities/payment.dart';
import '../../features/invoices/presentation/controllers/invoices_controller.dart';
import '../../features/subscription/presentation/controllers/subscription_controller.dart';
import '../../shared/services/invoice_status_service.dart';

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

      if (amount <= 0) {
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

      final statusService = _ref.read(invoiceStatusServiceProvider);
      var updatedInvoice = invoice.copyWith(
        payments: [...invoice.payments, newPayment],
      );
      updatedInvoice = updatedInvoice.copyWith(
        status: statusService.resolveStatus(updatedInvoice),
      );

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
      final statusService = _ref.read(invoiceStatusServiceProvider);
      var updatedInvoice = invoice.copyWith(
        payments: updatedPayments,
      );
      updatedInvoice = updatedInvoice.copyWith(
        status: statusService.resolveStatus(updatedInvoice),
      );

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

  Map<String, double> getPaidTotalsByCurrency(List<Invoice> invoices) {
    try {
      final result = <String, double>{};
      for (final invoice in invoices) {
        if (invoice.status == InvoiceStatus.paid) {
          final code = invoice.currencyCode;
          result[code] = (result[code] ?? 0) + invoice.amount;
        }
      }
      return result;
    } catch (e, st) {
      debugPrint('[PaymentService] getPaidTotalsByCurrency failed: $e\n$st');
      return {};
    }
  }

  Map<String, double> getPendingTotalsByCurrency(List<Invoice> invoices) {
    try {
      final result = <String, double>{};
      for (final invoice in invoices) {
        if (invoice.status != InvoiceStatus.paid) {
          final pending = invoice.remainingBalance;
          if (pending > 0) {
            final code = invoice.currencyCode;
            result[code] = (result[code] ?? 0) + pending;
          }
        }
      }
      return result;
    } catch (e, st) {
      debugPrint('[PaymentService] getPendingTotalsByCurrency failed: $e\n$st');
      return {};
    }
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

final paidTotalsByCurrencyProvider = Provider<Map<String, double>>((ref) {
  final invoices = ref.watch(invoicesControllerProvider).valueOrNull ?? [];
  return ref.read(paymentServiceProvider).getPaidTotalsByCurrency(invoices);
});

final pendingTotalsByCurrencyProvider = Provider<Map<String, double>>((ref) {
  final invoices = ref.watch(invoicesControllerProvider).valueOrNull ?? [];
  return ref.read(paymentServiceProvider).getPendingTotalsByCurrency(invoices);
});
