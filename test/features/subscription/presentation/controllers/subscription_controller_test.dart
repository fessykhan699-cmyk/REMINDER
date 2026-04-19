@Tags(['native'])
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:reminder/features/subscription/data/datasources/subscription_local_datasource.dart';
import 'package:reminder/features/subscription/data/services/billing_service.dart';
import 'package:reminder/features/subscription/domain/entities/subscription_state.dart';
import 'package:reminder/features/subscription/domain/services/billing_service_interface.dart';
import 'package:reminder/features/subscription/presentation/controllers/subscription_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SubscriptionController', () {
    test('syncs active Play Billing ownership into local pro state', () async {
      final billingService = _FakeBillingService(syncedIsPro: true);
      final datasource = _FakeSubscriptionLocalDatasource(
        const SubscriptionState.free(),
      );
      final container = ProviderContainer(
        overrides: [
          billingServiceProvider.overrideWithValue(billingService),
          subscriptionLocalDatasourceProvider.overrideWithValue(datasource),
        ],
      );

      addTearDown(() async {
        await billingService.dispose();
        container.dispose();
      });

      final state = await container.read(subscriptionControllerProvider.future);

      expect(state.isPro, isTrue);
      expect((await datasource.loadState()).isPro, isTrue);
    });

    test('keeps the local plan when store sync is unavailable', () async {
      final billingService = _FakeBillingService(syncedIsPro: null);
      final datasource = _FakeSubscriptionLocalDatasource(
        const SubscriptionState.pro(),
      );
      final container = ProviderContainer(
        overrides: [
          billingServiceProvider.overrideWithValue(billingService),
          subscriptionLocalDatasourceProvider.overrideWithValue(datasource),
        ],
      );

      addTearDown(() async {
        await billingService.dispose();
        container.dispose();
      });

      final state = await container.read(subscriptionControllerProvider.future);

      expect(state.isPro, isTrue);
      expect((await datasource.loadState()).isPro, isTrue);
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

  @override
  Future<SubscriptionState> savePlanTier(InvoiceFlowPlan plan) async {
    _state = switch (plan) {
      InvoiceFlowPlan.free => const SubscriptionState.free(),
      InvoiceFlowPlan.pro => const SubscriptionState.pro(),
      InvoiceFlowPlan.business => const SubscriptionState.business(),
    };
    return _state;
  }
}

class _FakeBillingService implements BillingServiceInterface {
  _FakeBillingService({this.syncedIsPro})
    : _purchaseController = StreamController<List<PurchaseDetails>>.broadcast();

  final bool? syncedIsPro;
  final StreamController<List<PurchaseDetails>> _purchaseController;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream =>
      _purchaseController.stream;

  @override
  Future<bool?> syncOwnedProState(Set<String> productIds) async => syncedIsPro;

  @override
  Future<InvoiceFlowPlan?> syncOwnedPlanState(Set<String> productIds) async {
    if (syncedIsPro == null) {
      return null;
    }
    return syncedIsPro! ? InvoiceFlowPlan.pro : InvoiceFlowPlan.free;
  }

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<List<ProductDetails>> loadProducts(Set<String> productIds) async => [];

  @override
  Future<bool> purchase(ProductDetails product) async => true;

  @override
  Future<void> restorePurchases() async {}

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {}

  Future<void> dispose() {
    return _purchaseController.close();
  }
}
