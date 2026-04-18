import 'package:flutter_test/flutter_test.dart';
import 'package:reminder/features/invoices/data/models/invoice_model.dart';
import 'package:reminder/features/invoices/data/models/line_item_model.dart';
import 'package:reminder/data/models/payment_model.dart';
import 'package:reminder/features/invoices/domain/entities/invoice.dart';

void main() {
  InvoiceModel buildModel() {
    return InvoiceModel(
      id: 'inv-1',
      invoiceNumber: 'INV-001',
      clientId: 'client-1',
      clientName: 'Client One',
      service: 'Development',
      amount: 420.75,
      dueDate: DateTime(2026, 4, 20),
      status: InvoiceStatus.partiallyPaid,
      createdAt: DateTime(2026, 4, 10),
      currencyCode: 'AED',
      taxPercent: 5.0,
      paymentTermsDays: 14,
      discountAmount: 20,
      paymentLink: 'https://pay.example.com/inv-1',
      notes: 'Thanks',
      items: const <LineItemModel>[
        LineItemModel(
          id: 'li-1',
          description: 'Design',
          quantity: 2,
          unitPrice: 100.5,
        ),
      ],
      payments: <PaymentModel>[
        PaymentModel(
          id: 'pay-1',
          amount: 50.0,
          date: DateTime(2026, 4, 12),
          note: 'advance',
          paymentMethod: 'bank',
        ),
      ],
    );
  }

  test('fromJson(toJson(model)) round-trips all fields', () {
    final original = buildModel();
    final json = original.toJson();
    final parsed = InvoiceModel.fromJson(json);

    expect(parsed.id, original.id);
    expect(parsed.invoiceNumber, original.invoiceNumber);
    expect(parsed.clientId, original.clientId);
    expect(parsed.clientName, original.clientName);
    expect(parsed.service, original.service);
    expect(parsed.amount, original.amount);
    expect(parsed.dueDate, original.dueDate);
    expect(parsed.status, original.status);
    expect(parsed.createdAt, original.createdAt);
    expect(parsed.currencyCode, original.currencyCode);
    expect(parsed.taxPercent, original.taxPercent);
    expect(parsed.paymentTermsDays, original.paymentTermsDays);
    expect(parsed.discountAmount, original.discountAmount);
    expect(parsed.paymentLink, original.paymentLink);
    expect(parsed.notes, original.notes);
    expect(parsed.items, original.items);
    expect(parsed.payments, original.payments);
  });

  test('toJson uses expected persistence keys', () {
    final json = buildModel().toJson();

    expect(json.keys, containsAll(<String>[
      'id',
      'invoiceNumber',
      'clientId',
      'clientName',
      'service',
      'amount',
      'dueDate',
      'status',
      'createdAt',
      'currencyCode',
      'taxPercent',
      'paymentTermsDays',
      'discountAmount',
      'paymentLink',
      'notes',
      'items',
      'isRecurring',
      'recurringInterval',
      'recurringNextDate',
      'recurringParentId',
      'payments',
    ]));
  });

  test('fromJson handles missing optional fields safely', () {
    final json = <String, dynamic>{
      'id': 'inv-2',
      'clientId': 'client-2',
      'clientName': 'Client Two',
      'service': 'Support',
      'amount': 100.0,
      'dueDate': DateTime(2026, 5, 1).toIso8601String(),
      'status': 'draft',
      'createdAt': DateTime(2026, 4, 15).toIso8601String(),
    };

    final parsed = InvoiceModel.fromJson(json);
    expect(parsed.notes, isNull);
    expect(parsed.paymentLink, isNull);
    expect(parsed.items, isEmpty);
    expect(parsed.payments, isEmpty);
  });

  test('partiallyPaid status survives toJson/fromJson round-trip', () {
    final model = buildModel().copyWith(status: InvoiceStatus.partiallyPaid);
    final parsed = InvoiceModel.fromJson(model.toJson());
    expect(parsed.status, InvoiceStatus.partiallyPaid);
  });

  test('line item round-trip preserves quantity and unitPrice exactly', () {
    final model = buildModel();
    final parsed = InvoiceModel.fromJson(model.toJson());

    expect(parsed.items.single.quantity, model.items.single.quantity);
    expect(parsed.items.single.unitPrice, model.items.single.unitPrice);
  });
}
