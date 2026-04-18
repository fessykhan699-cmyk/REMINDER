import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminder/features/subscription/data/datasources/subscription_local_datasource.dart';
import 'package:reminder/features/subscription/domain/entities/subscription_state.dart';
import 'package:reminder/features/subscription/presentation/controllers/subscription_controller.dart';

void main() {
  ProviderContainer buildContainer({
    required SubscriptionState subscriptionState,
    required SubscriptionUsage usage,
  }) {
    return ProviderContainer(
      overrides: [
        subscriptionLocalDatasourceProvider.overrideWithValue(
          _FakeSubscriptionLocalDatasource(subscriptionState, usage),
        ),
        subscriptionControllerProvider.overrideWith(
          () => _FixedSubscriptionController(subscriptionState),
        ),
      ],
    );
  }

  test('free tier teamMembers gate is blocked', () async {
    final container = buildContainer(
      subscriptionState: const SubscriptionState.free(),
      usage: const SubscriptionUsage(clientCount: 0, monthlyInvoiceCount: 0),
    );
    addTearDown(container.dispose);

    final decision = await container
        .read(subscriptionGatekeeperProvider)
        .evaluate(SubscriptionGateFeature.teamMembers);

    expect(decision.isAllowed, isFalse);
  });

  test('free tier premium feature gate is blocked', () async {
    final container = buildContainer(
      subscriptionState: const SubscriptionState.free(),
      usage: const SubscriptionUsage(clientCount: 0, monthlyInvoiceCount: 0),
    );
    addTearDown(container.dispose);

    final decision = await container
        .read(subscriptionGatekeeperProvider)
        .evaluate(SubscriptionGateFeature.smartReminders);

    expect(decision.isAllowed, isFalse);
  });

  test('pro tier premium feature gate is allowed', () async {
    final container = buildContainer(
      subscriptionState: const SubscriptionState.pro(),
      usage: const SubscriptionUsage(clientCount: 3, monthlyInvoiceCount: 7),
    );
    addTearDown(container.dispose);

    final decision = await container
        .read(subscriptionGatekeeperProvider)
        .evaluate(SubscriptionGateFeature.smartReminders);

    expect(decision.isAllowed, isTrue);
  });

  test('pro tier teamMembers gate is blocked', () async {
    final container = buildContainer(
      subscriptionState: const SubscriptionState.pro(),
      usage: const SubscriptionUsage(clientCount: 0, monthlyInvoiceCount: 0),
    );
    addTearDown(container.dispose);

    final decision = await container
        .read(subscriptionGatekeeperProvider)
        .evaluate(SubscriptionGateFeature.teamMembers);

    expect(decision.isAllowed, isFalse);
  });

  test('business tier teamMembers gate is allowed', () async {
    final container = buildContainer(
      subscriptionState: const SubscriptionState.business(),
      usage: const SubscriptionUsage(clientCount: 0, monthlyInvoiceCount: 0),
    );
    addTearDown(container.dispose);

    final decision = await container
        .read(subscriptionGatekeeperProvider)
        .evaluate(SubscriptionGateFeature.teamMembers);

    expect(decision.isAllowed, isTrue);
  });

  test('business tier premium feature gate is allowed', () async {
    final container = buildContainer(
      subscriptionState: const SubscriptionState.business(),
      usage: const SubscriptionUsage(clientCount: 0, monthlyInvoiceCount: 0),
    );
    addTearDown(container.dispose);

    final decision = await container
        .read(subscriptionGatekeeperProvider)
        .evaluate(SubscriptionGateFeature.advancedTotals);

    expect(decision.isAllowed, isTrue);
  });

  test('free tier invoice limit constant is 5 per month', () {
    expect(SubscriptionState.freeMonthlyInvoiceLimit, 5);
  });

  test('free tier createInvoice blocks at monthly limit', () async {
    final container = buildContainer(
      subscriptionState: const SubscriptionState.free(),
      usage: const SubscriptionUsage(clientCount: 0, monthlyInvoiceCount: 5),
    );
    addTearDown(container.dispose);

    final decision = await container
        .read(subscriptionGatekeeperProvider)
        .evaluate(SubscriptionGateFeature.createInvoice);

    expect(decision.isAllowed, isFalse);
    expect(decision.reason, SubscriptionGateReason.limitReached);
  });

  test('free tier createInvoice allowed under monthly limit', () async {
    final container = buildContainer(
      subscriptionState: const SubscriptionState.free(),
      usage: const SubscriptionUsage(clientCount: 0, monthlyInvoiceCount: 4),
    );
    addTearDown(container.dispose);

    final decision = await container
        .read(subscriptionGatekeeperProvider)
        .evaluate(SubscriptionGateFeature.createInvoice);

    expect(decision.isAllowed, isTrue);
  });

  test('free tier addClient blocks at client limit', () async {
    final container = buildContainer(
      subscriptionState: const SubscriptionState.free(),
      usage: const SubscriptionUsage(clientCount: 3, monthlyInvoiceCount: 0),
    );
    addTearDown(container.dispose);

    final decision = await container
        .read(subscriptionGatekeeperProvider)
        .evaluate(SubscriptionGateFeature.addClient);

    expect(decision.isAllowed, isFalse);
    expect(decision.reason, SubscriptionGateReason.limitReached);
  });
}

class _FixedSubscriptionController extends SubscriptionController {
  _FixedSubscriptionController(this.stateValue);

  final SubscriptionState stateValue;

  @override
  Future<SubscriptionState> build() async => stateValue;
}

class _FakeSubscriptionLocalDatasource extends SubscriptionLocalDatasource {
  _FakeSubscriptionLocalDatasource(this._state, this._usage);

  final SubscriptionState _state;
  final SubscriptionUsage _usage;

  @override
  Future<SubscriptionState> loadState() async => _state;

  @override
  SubscriptionUsage loadUsage({DateTime? now}) => _usage;
}
