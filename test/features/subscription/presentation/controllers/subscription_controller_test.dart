import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:reminder/features/subscription/data/datasources/subscription_local_datasource.dart';
import 'package:reminder/features/subscription/data/services/play_billing_service.dart';
import 'package:reminder/features/subscription/domain/entities/subscription_state.dart';
import 'package:reminder/features/subscription/presentation/controllers/subscription_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SubscriptionController', () {
    test('syncs active Play Billing ownership into local pro state', () async {
      final billingService = _FakePlayBillingService(syncedIsPro: true);
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

      final state = await container.read(subscriptionControllerProvider.future);

      expect(state.isPro, isTrue);
      expect((await datasource.loadState()).isPro, isTrue);
    });

    test('keeps the local plan when store sync is unavailable', () async {
      final billingService = _FakePlayBillingService(syncedIsPro: null);
      final datasource = _FakeSubscriptionLocalDatasource(
        const SubscriptionState.pro(),
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
}

class _FakePlayBillingService extends PlayBillingService {
  _FakePlayBillingService({this.syncedIsPro})
    : _purchaseController = StreamController<List<PurchaseDetails>>.broadcast(),
      super();

  final bool? syncedIsPro;
  final StreamController<List<PurchaseDetails>> _purchaseController;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream =>
      _purchaseController.stream;

  @override
  Future<BillingCatalogResult> loadCatalog() async {
    return const BillingCatalogResult.unavailable();
  }

  @override
  Future<bool?> syncOwnedProState() async => syncedIsPro;

  Future<void> dispose() {
    return _purchaseController.close();
  }
}
