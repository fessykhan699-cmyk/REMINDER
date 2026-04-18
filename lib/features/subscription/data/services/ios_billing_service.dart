import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../domain/services/billing_service_interface.dart';

class IOSBillingService implements BillingServiceInterface {
  IOSBillingService({InAppPurchase? inAppPurchase})
      : _inAppPurchase = inAppPurchase;

  final InAppPurchase? _inAppPurchase;
  InAppPurchase get _billingClient => _inAppPurchase ?? InAppPurchase.instance;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _billingClient.purchaseStream;

  @override
  Future<bool> isAvailable() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return false;
    return await _billingClient.isAvailable();
  }

  @override
  Future<List<ProductDetails>> loadProducts(Set<String> productIds) async {
    final response = await _billingClient.queryProductDetails(productIds);
    if (response.error != null) {
      debugPrint('[IOSBillingService] Error loading products: ${response.error}');
    }
    return response.productDetails;
  }

  @override
  Future<bool> purchase(ProductDetails product) async {
    final purchaseParam = PurchaseParam(productDetails: product);
    return await _billingClient.buyNonConsumable(purchaseParam: purchaseParam);
  }

  @override
  Future<void> restorePurchases() async {
    await _billingClient.restorePurchases();
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    await _billingClient.completePurchase(purchase);
  }

  @override
  Future<bool?> syncOwnedProState(Set<String> proProductIds) async {
    // Note: On iOS, we typically rely on restorePurchases() to populate the stream 
    // or use platform-specific additions for receipt validation.
    // For this implementation, we will return false and rely on the restore flow.
    return false;
  }
}
