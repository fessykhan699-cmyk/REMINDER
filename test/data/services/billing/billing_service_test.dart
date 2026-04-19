@Tags(['native'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:reminder/features/subscription/domain/entities/subscription_state.dart';
import 'package:reminder/features/subscription/domain/services/billing_service_interface.dart';

void main() {
  test('mock pro service isPro returns true', () {
    final service = _MockBillingService(plan: InvoiceFlowPlan.pro);
    expect(service.isPro(), isTrue);
  });

  test('mock free service isPro returns false', () {
    final service = _MockBillingService(plan: InvoiceFlowPlan.free);
    expect(service.isPro(), isFalse);
  });

  test('mock business service isBusiness returns true', () {
    final service = _MockBillingService(plan: InvoiceFlowPlan.business);
    expect(service.isBusiness(), isTrue);
  });

  test('mock pro service isBusiness returns false', () {
    final service = _MockBillingService(plan: InvoiceFlowPlan.pro);
    expect(service.isBusiness(), isFalse);
  });

  test('proStatusStream emits at least one value', () async {
    final service = _MockBillingService(plan: InvoiceFlowPlan.pro);
    await expectLater(service.proStatusStream, emits(isA<bool>()));
  });
}

class _MockBillingService implements BillingServiceInterface {
  _MockBillingService({required this.plan});

  final InvoiceFlowPlan plan;

  bool isPro() => plan == InvoiceFlowPlan.pro || plan == InvoiceFlowPlan.business;

  bool isBusiness() => plan == InvoiceFlowPlan.business;

  Stream<bool> get proStatusStream => Stream<bool>.value(isPro());

  @override
  Stream<List<PurchaseDetails>> get purchaseStream =>
      const Stream<List<PurchaseDetails>>.empty();

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {}

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<List<ProductDetails>> loadProducts(Set<String> productIds) async {
    return <ProductDetails>[];
  }

  @override
  Future<bool> purchase(ProductDetails product) async => true;

  @override
  Future<void> restorePurchases() async {}

  @override
  Future<InvoiceFlowPlan?> syncOwnedPlanState(Set<String> productIds) async {
    return plan;
  }

  @override
  Future<bool?> syncOwnedProState(Set<String> proProductIds) async {
    return isPro();
  }
}
