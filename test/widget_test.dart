import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reminder/app.dart';

void main() {
  testWidgets('App boots into splash safely', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: InvoiceReminderApp()));
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Skip'), findsOneWidget);
  });
}
