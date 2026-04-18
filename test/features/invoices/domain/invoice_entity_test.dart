import 'package:flutter_test/flutter_test.dart';
import 'package:reminder/domain/entities/payment.dart';
import 'package:reminder/features/invoices/domain/entities/invoice.dart';
import 'package:reminder/features/invoices/domain/entities/line_item.dart';

void main() {
  Invoice buildInvoice({
    double amount = 0,
    List<LineItem> items = const <LineItem>[],
    List<Payment> payments = const <Payment>[],
    InvoiceStatus status = InvoiceStatus.draft,
  }) {
    return Invoice(
      id: 'inv-1',
      invoiceNumber: 'INV-001',
      clientId: 'client-1',
      clientName: 'Client One',
      service: 'Design',
      amount: amount,
      dueDate: DateTime(2026, 4, 20),
      createdAt: DateTime(2026, 4, 1),
      status: status,
      items: items,
      payments: payments,
    );
  }

  test('calculatedTotal returns sum of line items when items exist', () {
    final invoice = buildInvoice(
      items: const <LineItem>[
        LineItem(id: '1', description: 'A', quantity: 2, unitPrice: 100),
        LineItem(id: '2', description: 'B', quantity: 3, unitPrice: 50),
      ],
    );

    expect(invoice.calculatedTotal, 350.0);
    expect(invoice.subtotalAmount, 350.0);
  });

  test('calculatedTotal returns 0.0 for empty items and zero amount', () {
    final invoice = buildInvoice(amount: 0);
    expect(invoice.calculatedTotal, 0.0);
  });

  test('remainingBalance returns amount when no payments exist', () {
    final invoice = buildInvoice(amount: 500);
    expect(invoice.remainingBalance, 500.0);
  });

  test('remainingBalance returns correct value for partial payments', () {
    final invoice = buildInvoice(
      amount: 500,
      payments: <Payment>[
        Payment(id: 'p1', amount: 120, date: DateTime(2026, 4, 2)),
        Payment(id: 'p2', amount: 80, date: DateTime(2026, 4, 3)),
      ],
    );

    expect(invoice.remainingBalance, 300.0);
    expect(invoice.isPartiallyPaid, isTrue);
  });

  test('remainingBalance returns 0.0 when fully paid', () {
    final invoice = buildInvoice(
      amount: 500,
      payments: <Payment>[
        Payment(id: 'p1', amount: 500, date: DateTime(2026, 4, 2)),
      ],
      status: InvoiceStatus.paid,
    );

    expect(invoice.remainingBalance, 0.0);
    expect(invoice.isFullyPaid, isTrue);
  });

  test('copyWith preserves fields when no arguments passed', () {
    final invoice = buildInvoice(
      amount: 120,
      items: const <LineItem>[
        LineItem(id: '1', description: 'A', quantity: 1, unitPrice: 120),
      ],
    );

    final copied = invoice.copyWith();
    expect(copied, equals(invoice));
  });

  test('copyWith overrides only specified fields', () {
    final invoice = buildInvoice(amount: 100, status: InvoiceStatus.draft);
    final updated = invoice.copyWith(
      service: 'Updated Service',
      amount: 250,
      status: InvoiceStatus.sent,
    );

    expect(updated.service, 'Updated Service');
    expect(updated.amount, 250);
    expect(updated.status, InvoiceStatus.sent);
    expect(updated.clientId, invoice.clientId);
    expect(updated.invoiceNumber, invoice.invoiceNumber);
  });

  test('partiallyPaid status is not treated as paid', () {
    final invoice = buildInvoice(status: InvoiceStatus.partiallyPaid);
    expect(invoice.isPaid, isFalse);
  });

  test('paid status can coexist with zero remaining balance', () {
    final invoice = buildInvoice(
      amount: 200,
      status: InvoiceStatus.paid,
      payments: <Payment>[
        Payment(id: 'p1', amount: 200, date: DateTime(2026, 4, 4)),
      ],
    );
    expect(invoice.status, InvoiceStatus.paid);
    expect(invoice.remainingBalance, 0.0);
  });

  test('invoices are equal only when all compared fields are equal', () {
    final first = buildInvoice(amount: 200);
    final second = buildInvoice(amount: 200);
    final different = buildInvoice(amount: 300);

    expect(first, equals(second));
    expect(first == different, isFalse);
  });
}
