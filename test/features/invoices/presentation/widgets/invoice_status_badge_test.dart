import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reminder/features/invoices/domain/entities/invoice.dart';
import 'package:reminder/features/invoices/presentation/widgets/invoice_status_badge.dart';

void main() {
  group('InvoiceStatusBadge', () {
    testWidgets('shows PENDING text for draft status', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InvoiceStatusBadge(status: InvoiceStatus.draft),
          ),
        ),
      );

      expect(find.text('PENDING'), findsOneWidget);
    });

    testWidgets('shows PAID text for paid status', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InvoiceStatusBadge(status: InvoiceStatus.paid),
          ),
        ),
      );

      expect(find.text('PAID'), findsOneWidget);
    });

    testWidgets('shows OVERDUE text for overdue status', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InvoiceStatusBadge(status: InvoiceStatus.overdue),
          ),
        ),
      );

      expect(find.text('OVERDUE'), findsOneWidget);
    });

    testWidgets('shows PARTIALLY PAID text for partiallyPaid status', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InvoiceStatusBadge(status: InvoiceStatus.partiallyPaid),
          ),
        ),
      );

      expect(find.text('PARTIALLY PAID'), findsOneWidget);
    });

    testWidgets('does not throw for any valid InvoiceStatus value', (
      tester,
    ) async {
      for (final status in InvoiceStatus.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InvoiceStatusBadge(status: status),
            ),
          ),
        );

        expect(find.text(status.label.toUpperCase()), findsOneWidget);
      }
    });
  });
}
