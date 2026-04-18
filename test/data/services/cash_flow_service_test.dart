import 'package:flutter_test/flutter_test.dart';
import 'package:reminder/domain/entities/payment.dart';
import 'package:reminder/data/services/cash_flow_service.dart';
import 'package:reminder/features/invoices/domain/entities/invoice.dart';

void main() {
  Invoice buildInvoice({
    required String id,
    required DateTime createdAt,
    required List<Payment> payments,
    InvoiceStatus status = InvoiceStatus.draft,
    double amount = 0,
  }) {
    return Invoice(
      id: id,
      invoiceNumber: 'INV-$id',
      clientId: 'client-$id',
      clientName: 'Client $id',
      service: 'Service',
      amount: amount,
      dueDate: createdAt.add(const Duration(days: 14)),
      createdAt: createdAt,
      status: status,
      payments: payments,
    );
  }

  test('returns six months of cash flow values', () {
    final service = CashFlowService();
    final result = service.getLast6MonthsCashFlow(const <Invoice>[]);

    expect(result.length, 6);
  });

  test('monthly total sums payments for current month only', () {
    final now = DateTime.now();
    final currentMonthDate = DateTime(now.year, now.month, 10);
    final previousMonthDate = DateTime(now.year, now.month - 1, 10);

    final invoices = <Invoice>[
      buildInvoice(
        id: '1',
        createdAt: currentMonthDate,
        payments: <Payment>[
          Payment(id: 'p1', amount: 100, date: currentMonthDate),
          Payment(id: 'p2', amount: 50, date: currentMonthDate),
        ],
      ),
      buildInvoice(
        id: '2',
        createdAt: previousMonthDate,
        payments: <Payment>[
          Payment(id: 'p3', amount: 999, date: previousMonthDate),
        ],
      ),
    ];

    final result = CashFlowService().getLast6MonthsCashFlow(invoices);
    final currentLabel = result.last.label;
    final currentMonthFlow = result.singleWhere((r) => r.label == currentLabel);

    expect(currentMonthFlow.totalPaid, 150.0);
  });

  test('payments in other months are excluded from current month total', () {
    final now = DateTime.now();
    final currentMonthDate = DateTime(now.year, now.month, 8);
    final twoMonthsAgoDate = DateTime(now.year, now.month - 2, 8);

    final invoices = <Invoice>[
      buildInvoice(
        id: '1',
        createdAt: currentMonthDate,
        payments: <Payment>[
          Payment(id: 'p1', amount: 75, date: currentMonthDate),
          Payment(id: 'p2', amount: 500, date: twoMonthsAgoDate),
        ],
      ),
    ];

    final result = CashFlowService().getLast6MonthsCashFlow(invoices);
    expect(result.last.totalPaid, 75.0);
  });

  test('empty invoice list produces zeros for all months', () {
    final result = CashFlowService().getLast6MonthsCashFlow(const <Invoice>[]);
    expect(result.every((entry) => entry.totalPaid == 0.0), isTrue);
  });

  test('partially paid invoice contributes paid portion only', () {
    final now = DateTime.now();
    final currentMonthDate = DateTime(now.year, now.month, 5);

    final partiallyPaidInvoice = buildInvoice(
      id: 'partial',
      createdAt: currentMonthDate,
      amount: 500,
      status: InvoiceStatus.partiallyPaid,
      payments: <Payment>[
        Payment(id: 'p1', amount: 120, date: currentMonthDate),
        Payment(id: 'p2', amount: 80, date: currentMonthDate),
      ],
    );

    final result = CashFlowService().getLast6MonthsCashFlow(
      <Invoice>[partiallyPaidInvoice],
    );

    expect(result.last.totalPaid, 200.0);
  });

  test('fully paid invoice contributes full paid amount for matching month', () {
    final now = DateTime.now();
    final currentMonthDate = DateTime(now.year, now.month, 18);
    final paidInvoice = buildInvoice(
      id: 'paid',
      createdAt: currentMonthDate,
      amount: 300,
      status: InvoiceStatus.paid,
      payments: <Payment>[
        Payment(id: 'p1', amount: 300, date: currentMonthDate),
      ],
    );

    final result = CashFlowService().getLast6MonthsCashFlow(<Invoice>[paidInvoice]);
    expect(result.last.totalPaid, 300.0);
  });
}
