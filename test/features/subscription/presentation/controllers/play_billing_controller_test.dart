import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:reminder/features/subscription/data/datasources/subscription_local_datasource.dart';
import 'package:reminder/features/subscription/data/services/play_billing_service.dart';
import 'package:reminder/features/subscription/domain/entities/subscription_state.dart';
import 'package:reminder/features/subscription/presentation/controllers/play_billing_controller.dart';
import 'package:reminder/features/subscription/presentation/controllers/subscription_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlayBillingController', () {
    test(
      'emits cancelled feedback when the purchase flow does not start',
      () async {
        final billingService = _FakePlayBillingService(
          catalog: BillingCatalogResult(
            storeAvailable: true,
            monthlyProduct: ProductDetails(
              id: PlayBillingService.proMonthlyProductId,
              title: 'Invoice Flow Pro',
              description: 'Unlimited clients and invoices',
              price: r'$4.99 / month',
              rawPrice: 4.99,
              currencyCode: 'USD',
            ),
          ),
          purchaseShouldStart: false,
        );
        final datasource = _FakeSubscriptionLocalDatasource(
          const SubscriptionState.free(),
        );
        final container = ProviderContainer(
          overrides: [
            playBillingServiceProvider.overrideWithValue(billingService),
            subscriptionLocalDatasourceProvider.overrideWithValue(datasource),
          ],
        );

        addTearDown(() async {
          await billingService.dispose();
          container.dispose();
        });

        final initial = await container.read(
          playBillingControllerProvider.future,
        );
        expect(initial.canPurchaseMonthly, isTrue);

        await container
            .read(playBillingControllerProvider.notifier)
            .purchaseMonthlyPro();

        final state = container.read(playBillingControllerProvider).valueOrNull;

        expect(state, isNotNull);
        expect(state!.feedback, isNotNull);
        expect(state.feedback!.type, PlayBillingFeedbackType.purchaseCancelled);
        expect(state.feedback!.message, 'Purchase cancelled');
        expect(state.isPurchasePending, isFalse);
        expect((await datasource.loadState()).isPro, isFalse);
      },
    );

    test('supports a yearly Pro offer when Google Play returns it', () async {
      final billingService = _FakePlayBillingService(
        catalog: BillingCatalogResult(
          storeAvailable: true,
          yearlyProduct: ProductDetails(
            id: PlayBillingService.proYearlyProductId,
            title: 'Invoice Flow Pro Yearly',
            description: 'Best value yearly plan',
            price: r'$39.99 / year',
            rawPrice: 39.99,
            currencyCode: 'USD',
          ),
        ),
      );
      final datasource = _FakeSubscriptionLocalDatasource(
        const SubscriptionState.free(),
      );
      final container = ProviderContainer(
        overrides: [
          playBillingServiceProvider.overrideWithValue(billingService),
          subscriptionLocalDatasourceProvider.overrideWithValue(datasource),
        ],
      );

      addTearDown(() async {
        await billingService.dispose();
        container.dispose();
      });

      final state = await container.read(playBillingControllerProvider.future);

      expect(state.canPurchaseMonthly, isFalse);
      expect(state.canPurchaseYearly, isTrue);
      expect(state.yearlyProduct?.id, PlayBillingService.proYearlyProductId);
    });
  });
}

class _FakeSubscriptionLocalDatasource extends SubscriptionLocalDatasource {
  _FakeSubscriptionLocalDatasource(this._state);

  SubscriptionState _state;

  @override
  Future<SubscriptionState> loadState() async => _state;

  @override
  Future<SubscriptionState> savePlan({required bool isPro}) async {
    _state = isPro
        ? const SubscriptionState.pro()
        : const SubscriptionState.free();
    return _state;
  }
}

class _FakePlayBillingService extends PlayBillingService {
  _FakePlayBillingService({
    this.catalog = const BillingCatalogResult.unavailable(),
    this.purchaseShouldStart = true,
  }) : _purchaseController =
           StreamController<List<PurchaseDetails>>.broadcast(),
       super();

  final BillingCatalogResult catalog;
  final bool purchaseShouldStart;
  final StreamController<List<PurchaseDetails>> _purchaseController;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream =>
      _purchaseController.stream;

  @override
  Future<BillingCatalogResult> loadCatalog() async => catalog;

  @override
  Future<bool> purchase(ProductDetails product) async => purchaseShouldStart;

  Future<void> dispose() {
    return _purchaseController.close();
  }
}
