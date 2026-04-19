import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/invoices/domain/entities/invoice.dart';

final invoiceStatusServiceProvider = Provider<InvoiceStatusService>(
  (ref) => const InvoiceStatusService(),
);

class InvoiceStatusService {
  const InvoiceStatusService();

  Invoice prepareForCreate(Invoice invoice, {DateTime? now}) {
    return _sanitize(invoice.copyWith(status: InvoiceStatus.draft), now: now);
  }

  Invoice prepareForUpdate(Invoice invoice, {DateTime? now}) {
    return _sanitize(invoice, now: now);
  }

  Invoice markSent(Invoice invoice, {DateTime? now}) {
    if (invoice.status.isPaid) {
      return prepareForUpdate(invoice, now: now);
    }

    return _sanitize(invoice.copyWith(status: InvoiceStatus.sent), now: now);
  }

  Invoice markViewed(Invoice invoice, {DateTime? now}) {
    if (invoice.status.isPaid) {
      return prepareForUpdate(invoice, now: now);
    }

    return _sanitize(invoice.copyWith(status: InvoiceStatus.viewed), now: now);
  }

  Invoice markPaid(Invoice invoice, {DateTime? now}) {
    return _sanitize(invoice.copyWith(status: InvoiceStatus.paid), now: now);
  }

  InvoiceStatus resolveStatus(Invoice invoice, {DateTime? now}) {
    final currentTime = now ?? DateTime.now();
    

    // Auto-resolve to Paid if fully paid
    if (invoice.isFullyPaid) {
      return InvoiceStatus.paid;
    }

    // Auto-resolve to Partially Paid if there are payments
    if (invoice.isPartiallyPaid) {
      return InvoiceStatus.partiallyPaid;
    }

    // Normal business logic for transitions
    if (invoice.dueDate.isBefore(currentTime)) {
      return InvoiceStatus.overdue;
    }

    // If it was paid or partially paid but no longer is, reset to a pending state.
    // We default to 'sent' as a safe fallback for previously processed invoices.
    if (invoice.status == InvoiceStatus.paid || 
        invoice.status == InvoiceStatus.partiallyPaid ||
        invoice.status == InvoiceStatus.overdue) {
      return InvoiceStatus.sent;
    }

    return invoice.status;
  }

  Invoice _sanitize(Invoice invoice, {DateTime? now}) {
    return invoice.copyWith(
      status: resolveStatus(invoice, now: now),
      paymentLink: invoice.normalizedPaymentLink,
    );
  }
}
