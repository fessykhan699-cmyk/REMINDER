@Tags(['native'])
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reminder/app.dart';
import 'package:reminder/core/utils/app_router.dart';
import 'package:reminder/features/subscription/domain/entities/subscription_state.dart';
import 'package:reminder/features/subscription/presentation/controllers/billing_controller.dart';
import 'package:reminder/features/subscription/presentation/controllers/subscription_controller.dart';

void main() {
  testWidgets('App boots into splash safely', (WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Text('Booted'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appRouterProvider.overrideWithValue(router),
          subscriptionControllerProvider.overrideWith(
            _TestSubscriptionController.new,
          ),
          billingControllerProvider.overrideWith(_TestBillingController.new),
        ],
        child: const InvoiceReminderApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Booted'), findsOneWidget);
  });
}

class _TestSubscriptionController extends SubscriptionController {
  @override
  Future<SubscriptionState> build() async => const SubscriptionState.free();
}

class _TestBillingController extends BillingController {
  @override
  Future<BillingState> build() async => const BillingState.initial();
}
