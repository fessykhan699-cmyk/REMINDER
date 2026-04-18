import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/android_billing_service.dart';
import '../services/ios_billing_service.dart';
import '../../domain/services/billing_service_interface.dart';

final billingServiceProvider = Provider<BillingServiceInterface>((ref) {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return AndroidBillingService(inAppPurchase: InAppPurchase.instance);
  } else if (defaultTargetPlatform == TargetPlatform.iOS) {
    return IOSBillingService(inAppPurchase: InAppPurchase.instance);
  } else {
    throw UnsupportedError('Platform not supported for billing');
  }
});

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
