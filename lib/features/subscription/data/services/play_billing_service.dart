import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

final playBillingServiceProvider = Provider<PlayBillingService>(
  (ref) => PlayBillingService(),
);

class BillingCatalogResult {
  const BillingCatalogResult({
    required this.storeAvailable,
    this.monthlyProduct,
    this.yearlyProduct,
    this.monthlyProductNotFound = false,
    this.yearlyProductNotFound = false,
    this.errorMessage,
  });

  const BillingCatalogResult.unavailable()
    : storeAvailable = false,
      monthlyProduct = null,
      yearlyProduct = null,
      monthlyProductNotFound = false,
      yearlyProductNotFound = false,
      errorMessage = null;

  final bool storeAvailable;
  final ProductDetails? monthlyProduct;
  final ProductDetails? yearlyProduct;
  final bool monthlyProductNotFound;
  final bool yearlyProductNotFound;
  final String? errorMessage;

  bool get productNotFound => monthlyProductNotFound && yearlyProductNotFound;
}

class PlayBillingService {
  PlayBillingService({InAppPurchase? inAppPurchase})
    : _inAppPurchase = inAppPurchase;

  static const String proMonthlyProductId = 'invoiceflow_pro_monthly';
  static const String proYearlyProductId = 'invoiceflow_pro_yearly';
  static const Set<String> _productIds = <String>{
    proMonthlyProductId,
    proYearlyProductId,
  };

  final InAppPurchase? _inAppPurchase;

  InAppPurchase get _billingClient => _inAppPurchase ?? InAppPurchase.instance;

  bool get _supportsGooglePlayBilling =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool isProProduct(String productId) {
    return productId == proMonthlyProductId || productId == proYearlyProductId;
  }

  Stream<List<PurchaseDetails>> get purchaseStream =>
      _billingClient.purchaseStream;

  Future<bool> isAvailable() async {
    if (!_supportsGooglePlayBilling) {
      return false;
    }

    return _billingClient.isAvailable();
  }

  Future<BillingCatalogResult> loadCatalog() async {
    final available = await isAvailable();
    if (!available) {
      return const BillingCatalogResult.unavailable();
    }

    final response = await _billingClient.queryProductDetails(_productIds);

    ProductDetails? monthlyProduct;
    ProductDetails? yearlyProduct;
    for (final candidate in response.productDetails) {
      if (candidate.id == proMonthlyProductId) {
        monthlyProduct = candidate;
        continue;
      }

      if (candidate.id == proYearlyProductId) {
        yearlyProduct = candidate;
      }
    }

    return BillingCatalogResult(
      storeAvailable: true,
      monthlyProduct: monthlyProduct,
      yearlyProduct: yearlyProduct,
      monthlyProductNotFound: response.notFoundIDs.contains(
        proMonthlyProductId,
      ),
      yearlyProductNotFound: response.notFoundIDs.contains(proYearlyProductId),
      errorMessage: response.error?.message,
    );
  }

  Future<bool?> syncOwnedProState() async {
    final available = await isAvailable();
    if (!available) {
      return null;
    }

    final addition = _billingClient
        .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    final response = await addition.queryPastPurchases();
    final error = response.error;
    if (error != null) {
      throw StateError(error.message);
    }

    for (final purchase in response.pastPurchases) {
      if (!isProProduct(purchase.productID)) {
        continue;
      }

      if (purchase.status == PurchaseStatus.error ||
          purchase.status == PurchaseStatus.canceled) {
        continue;
      }

      return true;
    }

    return false;
  }

  Future<bool> purchase(ProductDetails product) {
    final purchaseParam = PurchaseParam(productDetails: product);
    return _billingClient.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> restorePurchases() {
    return _billingClient.restorePurchases();
  }

  Future<void> completePurchase(PurchaseDetails purchase) {
    return _billingClient.completePurchase(purchase);
  }
}
