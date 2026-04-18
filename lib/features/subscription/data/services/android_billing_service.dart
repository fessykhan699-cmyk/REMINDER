import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import '../../domain/entities/subscription_state.dart';
import '../../domain/services/billing_service_interface.dart';

class AndroidBillingService implements BillingServiceInterface {
  AndroidBillingService({InAppPurchase? inAppPurchase})
    : _inAppPurchase = inAppPurchase;

  final InAppPurchase? _inAppPurchase;
  InAppPurchase get _billingClient => _inAppPurchase ?? InAppPurchase.instance;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream =>
      _billingClient.purchaseStream;

  @override
  Future<bool> isAvailable() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    return await _billingClient.isAvailable();
  }

  @override
  Future<List<ProductDetails>> loadProducts(Set<String> productIds) async {
    final response = await _billingClient.queryProductDetails(productIds);
    if (response.error != null) {
      debugPrint(
        '[AndroidBillingService] Error loading products: ${response.error}',
      );
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
    if (defaultTargetPlatform != TargetPlatform.android) return null;

    final available = await isAvailable();
    if (!available) return null;

    try {
      final addition = _billingClient
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final response = await addition.queryPastPurchases();

      if (response.error != null) {
        throw StateError(response.error!.message);
      }

      for (final purchase in response.pastPurchases) {
        if (proProductIds.contains(purchase.productID)) {
          if (purchase.status == PurchaseStatus.purchased ||
              purchase.status == PurchaseStatus.restored) {
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      debugPrint('[AndroidBillingService] syncOwnedProState error: $e');
      return null;
    }
  }

  @override
  Future<InvoiceFlowPlan?> syncOwnedPlanState(Set<String> productIds) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }

    final available = await isAvailable();
    if (!available) {
      return null;
    }

    try {
      final addition = _billingClient
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final response = await addition.queryPastPurchases();

      if (response.error != null) {
        throw StateError(response.error!.message);
      }

      var hasPro = false;
      for (final purchase in response.pastPurchases) {
        if (!productIds.contains(purchase.productID)) {
          continue;
        }
        final isOwned =
            purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored;
        if (!isOwned) {
          continue;
        }

        if (BillingServiceInterface.isBusinessProduct(purchase.productID)) {
          return InvoiceFlowPlan.business;
        }
        if (BillingServiceInterface.isProProduct(purchase.productID)) {
          hasPro = true;
        }
      }

      return hasPro ? InvoiceFlowPlan.pro : InvoiceFlowPlan.free;
    } catch (e) {
      debugPrint('[AndroidBillingService] syncOwnedPlanState error: $e');
      return null;
    }
  }
}
