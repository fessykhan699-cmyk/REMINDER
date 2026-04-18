import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

abstract class BillingServiceInterface {
  static const String androidProMonthlyId = 'invoiceflow_pro_monthly';
  static const String androidProYearlyId = 'invoiceflow_pro_yearly';
  
  static const String iosProId = 'com.apexmobilelabs.reminder.pro';

  static Set<String> get allProductIds {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return {androidProMonthlyId, androidProYearlyId};
    } else {
      return {iosProId};
    }
  }

  static bool isProProduct(String productId) {
    return productId == androidProMonthlyId || 
           productId == androidProYearlyId || 
           productId == iosProId;
  }

  Stream<List<PurchaseDetails>> get purchaseStream;
  
  Future<bool> isAvailable();
  Future<List<ProductDetails>> loadProducts(Set<String> productIds);
  Future<bool> purchase(ProductDetails product);
  Future<void> restorePurchases();
  Future<void> completePurchase(PurchaseDetails purchase);
  Future<bool?> syncOwnedProState(Set<String> proProductIds);
}
