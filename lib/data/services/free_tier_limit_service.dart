import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/subscription/domain/entities/subscription_state.dart';
import '../../features/subscription/presentation/controllers/subscription_controller.dart';

final freeTierLimitServiceProvider = Provider<FreeTierLimitService>((ref) {
  return FreeTierLimitService(ref);
});

class FreeTierLimitService {
  FreeTierLimitService(this._ref);

  final Ref _ref;

  /// Returns true if the user is allowed to create a new invoice.
  /// If an error occurs, it returns true (fail-open).
  Future<bool> canCreateInvoice() async {
    try {
      final subscription = await _ref.read(subscriptionControllerProvider.future);
      if (subscription.isPro) return true;

      final usage = _ref.read(subscriptionUsageProvider);
      return !usage.hasReachedMonthlyInvoiceLimit;
    } catch (e) {
      debugPrint('[FreeTierLimitService] canCreateInvoice error (fail-open): $e');
      return true;
    }
  }

  /// Returns true if the user is allowed to add a new client.
  /// If an error occurs, it returns true (fail-open).
  Future<bool> canAddClient() async {
    try {
      final subscription = await _ref.read(subscriptionControllerProvider.future);
      if (subscription.isPro) return true;

      final usage = _ref.read(subscriptionUsageProvider);
      return !usage.hasReachedClientLimit;
    } catch (e) {
      debugPrint('[FreeTierLimitService] canAddClient error (fail-open): $e');
      return true;
    }
  }

  /// Returns true if the user has access to a premium feature.
  /// If an error occurs, it returns true (fail-open).
  Future<bool> isFeatureAllowed(SubscriptionGateFeature feature) async {
    try {
      final subscription = await _ref.read(subscriptionControllerProvider.future);
      if (subscription.isPro) return true;

      // Some features are strictly Pro-only
      switch (feature) {
        case SubscriptionGateFeature.smartReminders:
        case SubscriptionGateFeature.whatsappSharing:
        case SubscriptionGateFeature.premiumBranding:
        case SubscriptionGateFeature.advancedTotals:
        case SubscriptionGateFeature.partialPayments:
        case SubscriptionGateFeature.exportCsv:
          return false;
        case SubscriptionGateFeature.createInvoice:
          return await canCreateInvoice();
        case SubscriptionGateFeature.addClient:
          return await canAddClient();
        case SubscriptionGateFeature.exportPdf:
          return true; // PDF export is allowed on free (with watermark, handled elsewhere)
      }
    } catch (e) {
      debugPrint('[FreeTierLimitService] isFeatureAllowed error (fail-open): $e');
      return true;
    }
  }
}
