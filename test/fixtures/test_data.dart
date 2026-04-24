// ignore_for_file: avoid_redundant_argument_values
import 'package:reminder/features/clients/domain/entities/client.dart';
import 'package:reminder/features/expenses/domain/entities/expense.dart';
import 'package:reminder/features/invoices/domain/entities/invoice.dart';
import 'package:reminder/features/invoices/domain/entities/line_item.dart';
import 'package:reminder/domain/entities/payment.dart';

/// Test data fixtures for Invoice Flow production testing.
/// Covers 3 clients (USD/GBP/AED), 5 invoices (paid/overdue/partial/pending/draft),
/// 3 expenses, and 2 recurring invoice stubs (Invoice with isRecurring: true).
abstract final class TestData {
  // ─── Clients ────────────────────────────────────────────────────────────────

  static final Client clientUSD = Client(
    id: 'test-client-usd',
    name: 'Acme Corp',
    email: 'billing@acme.com',
    phone: '+12125550100',
    createdAt: DateTime(2026, 1, 10),
  );

  static final Client clientGBP = Client(
    id: 'test-client-gbp',
    name: "O'Brien & Sons",
    email: 'accounts@obrien.co.uk',
    phone: '+442071234567',
    createdAt: DateTime(2026, 2, 5),
  );

  static final Client clientAED = Client(
    id: 'test-client-aed',
    name: 'Gulf Ventures LLC',
    email: 'finance@gulfventures.ae',
    phone: '+971501234567',
    createdAt: DateTime(2026, 3, 1),
  );

  static List<Client> get allClients => [clientUSD, clientGBP, clientAED];

  // ─── Line Items ─────────────────────────────────────────────────────────────

  static const LineItem lineItemDesign = LineItem(
    id: 'li-design',
    description: 'UI/UX Design',
    quantity: 1,
    unitPrice: 500.0,
  );

  static const LineItem lineItemDev = LineItem(
    id: 'li-dev',
    description: 'Frontend Development',
    quantity: 2,
    unitPrice: 750.0,
  );

  static const LineItem lineItemConsulting = LineItem(
    id: 'li-consult',
    description: 'Strategy Consulting',
    quantity: 3,
    unitPrice: 200.0,
  );

  // ─── Invoices ───────────────────────────────────────────────────────────────

  /// 1. Paid — USD, 2 line items, 10% tax, $100 discount
  static final Invoice invoicePaid = Invoice(
    id: 'test-inv-paid',
    invoiceNumber: 'INV-T001',
    clientId: clientUSD.id,
    clientName: clientUSD.name,
    service: 'Design & Development',
    amount: 2000.0,
    dueDate: DateTime(2026, 3, 15),
    createdAt: DateTime(2026, 3, 1),
    status: InvoiceStatus.paid,
    currencyCode: 'USD',
    taxPercent: 10.0,
    discountAmount: 100.0,
    paymentTermsDays: 14,
    items: const [lineItemDesign, lineItemDev],
    payments: [
      Payment(
        id: 'pay-t001',
        amount: 2000.0,
        date: DateTime(2026, 3, 14),
        note: 'Full payment via bank transfer',
        paymentMethod: 'bank_transfer',
      ),
    ],
  );

  /// 2. Overdue — GBP, single line item, past due date
  static final Invoice invoiceOverdue = Invoice(
    id: 'test-inv-overdue',
    invoiceNumber: 'INV-T002',
    clientId: clientGBP.id,
    clientName: clientGBP.name,
    service: 'Consulting',
    amount: 600.0,
    dueDate: DateTime(2026, 1, 31),
    createdAt: DateTime(2026, 1, 15),
    status: InvoiceStatus.overdue,
    currencyCode: 'GBP',
    taxPercent: 0.0,
    discountAmount: 0.0,
    paymentTermsDays: 14,
    items: const [lineItemConsulting],
  );

  /// 3. Partially paid — AED, 3 line items, 5% VAT
  static final Invoice invoicePartiallyPaid = Invoice(
    id: 'test-inv-partial',
    invoiceNumber: 'INV-T003',
    clientId: clientAED.id,
    clientName: clientAED.name,
    service: 'Full-Stack Project',
    amount: 3675.0,
    dueDate: DateTime(2026, 5, 30),
    createdAt: DateTime(2026, 4, 15),
    status: InvoiceStatus.partiallyPaid,
    currencyCode: 'AED',
    taxPercent: 5.0,
    discountAmount: 0.0,
    paymentTermsDays: 30,
    items: const [lineItemDesign, lineItemDev, lineItemConsulting],
    payments: [
      Payment(
        id: 'pay-t003a',
        amount: 1000.0,
        date: DateTime(2026, 4, 20),
        note: 'Deposit',
        paymentMethod: 'cash',
      ),
    ],
  );

  /// 4. Pending (sent) — USD, due in 2 days (notification edge case)
  static final Invoice invoicePending = Invoice(
    id: 'test-inv-pending',
    invoiceNumber: 'INV-T004',
    clientId: clientUSD.id,
    clientName: clientUSD.name,
    service: 'Monthly Retainer',
    amount: 800.0,
    dueDate: DateTime.now().add(const Duration(days: 2)),
    createdAt: DateTime.now().subtract(const Duration(days: 12)),
    status: InvoiceStatus.sent,
    currencyCode: 'USD',
    taxPercent: 0.0,
    discountAmount: 0.0,
    paymentTermsDays: 14,
    items: const [
      LineItem(
        id: 'li-retainer',
        description: 'Monthly Retainer — April 2026',
        quantity: 1,
        unitPrice: 800.0,
      ),
    ],
  );

  /// 5. Draft — GBP, 20% tax, for edit/delete testing
  static final Invoice invoiceDraft = Invoice(
    id: 'test-inv-draft',
    invoiceNumber: 'INV-T005',
    clientId: clientGBP.id,
    clientName: clientGBP.name,
    service: 'Brand Identity',
    amount: 450.0,
    dueDate: DateTime.now().add(const Duration(days: 30)),
    createdAt: DateTime.now(),
    status: InvoiceStatus.draft,
    currencyCode: 'GBP',
    taxPercent: 20.0,
    discountAmount: 50.0,
    paymentTermsDays: 30,
    items: const [
      LineItem(
        id: 'li-brand',
        description: 'Brand Identity Package',
        quantity: 1,
        unitPrice: 416.67,
      ),
    ],
  );

  static List<Invoice> get allInvoices => [
        invoicePaid,
        invoiceOverdue,
        invoicePartiallyPaid,
        invoicePending,
        invoiceDraft,
      ];

  // ─── Recurring Invoice Stubs ─────────────────────────────────────────────────
  // Recurring invoices are represented as Invoice with isRecurring: true.

  static final Invoice recurringMonthly = Invoice(
    id: 'test-rec-monthly',
    invoiceNumber: 'INV-T006',
    clientId: clientUSD.id,
    clientName: clientUSD.name,
    service: 'Monthly Maintenance',
    amount: 500.0,
    dueDate: DateTime.now().add(const Duration(days: 30)),
    createdAt: DateTime.now(),
    status: InvoiceStatus.draft,
    currencyCode: 'USD',
    taxPercent: 0.0,
    discountAmount: 0.0,
    paymentTermsDays: 14,
    isRecurring: true,
    recurringInterval: RecurringInterval.monthly,
    recurringNextDate: DateTime.now().add(const Duration(days: 30)),
    items: const [
      LineItem(
        id: 'li-maint',
        description: 'Monthly Website Maintenance',
        quantity: 1,
        unitPrice: 500.0,
      ),
    ],
  );

  static final Invoice recurringWeekly = Invoice(
    id: 'test-rec-weekly',
    invoiceNumber: 'INV-T007',
    clientId: clientGBP.id,
    clientName: clientGBP.name,
    service: 'Weekly Consultancy',
    amount: 150.0,
    dueDate: DateTime.now().add(const Duration(days: 7)),
    createdAt: DateTime.now(),
    status: InvoiceStatus.draft,
    currencyCode: 'GBP',
    taxPercent: 0.0,
    discountAmount: 0.0,
    paymentTermsDays: 7,
    isRecurring: true,
    recurringInterval: RecurringInterval.weekly,
    recurringNextDate: DateTime.now().add(const Duration(days: 7)),
    items: const [
      LineItem(
        id: 'li-consult-w',
        description: 'Weekly Consultancy — 4 hrs',
        quantity: 4,
        unitPrice: 37.5,
      ),
    ],
  );

  static List<Invoice> get allRecurring => [recurringMonthly, recurringWeekly];

  // ─── Expenses ────────────────────────────────────────────────────────────────

  static final Expense expenseSoftware = Expense(
    id: 'test-exp-software',
    description: 'Figma Annual Subscription',
    amount: 144.0,
    date: DateTime(2026, 4, 1),
    category: ExpenseCategory.software,
    notes: 'Design tool renewal',
  );

  static final Expense expenseTravel = Expense(
    id: 'test-exp-travel',
    description: 'Client Site Visit — Dubai',
    amount: 320.0,
    date: DateTime(2026, 4, 10),
    category: ExpenseCategory.travel,
    notes: 'Flight + taxi receipts attached',
  );

  static final Expense expenseSupplies = Expense(
    id: 'test-exp-supplies',
    description: 'External Monitor & Desk Accessories',
    amount: 299.99,
    date: DateTime(2026, 4, 18),
    category: ExpenseCategory.supplies,
    notes: null,
  );

  static List<Expense> get allExpenses =>
      [expenseSoftware, expenseTravel, expenseSupplies];
}
