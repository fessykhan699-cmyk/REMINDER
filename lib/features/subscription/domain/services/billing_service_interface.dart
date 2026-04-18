import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../entities/subscription_state.dart';

abstract class BillingServiceInterface {
  static const String androidProMonthlyId = 'invoiceflow_pro_monthly';
  static const String androidProYearlyId = 'invoiceflow_pro_yearly';
  static const String androidBusinessMonthlyId = 'invoiceflow_business_monthly';
  static const String androidBusinessYearlyId = 'invoiceflow_business_yearly';

  static const String iosProId = 'com.apexmobilelabs.reminder.pro';
  static const String iosBusinessId = 'com.apexmobilelabs.reminder.business';

  static Set<String> get allProductIds {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return {
        androidProMonthlyId,
        androidProYearlyId,
        androidBusinessMonthlyId,
        androidBusinessYearlyId,
      };
    } else {
      return {iosProId, iosBusinessId};
    }
  }

  static bool isProProduct(String productId) {
    return productId == androidProMonthlyId ||
        productId == androidProYearlyId ||
        productId == iosProId;
  }

  static bool isBusinessProduct(String productId) {
    return productId == androidBusinessMonthlyId ||
        productId == androidBusinessYearlyId ||
        productId == iosBusinessId;
  }

  static bool isPaidTierProduct(String productId) {
    return isProProduct(productId) || isBusinessProduct(productId);
  }

  Stream<List<PurchaseDetails>> get purchaseStream;

  Future<bool> isAvailable();
  Future<List<ProductDetails>> loadProducts(Set<String> productIds);
  Future<bool> purchase(ProductDetails product);
  Future<void> restorePurchases();
  Future<void> completePurchase(PurchaseDetails purchase);
  Future<bool?> syncOwnedProState(Set<String> proProductIds);
  Future<InvoiceFlowPlan?> syncOwnedPlanState(Set<String> productIds);
}
