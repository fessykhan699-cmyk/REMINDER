import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../clients/presentation/controllers/clients_controller.dart';
import '../../../invoices/presentation/controllers/invoices_controller.dart';
import '../../data/datasources/subscription_local_datasource.dart';
import '../../data/services/play_billing_service.dart';
import '../../domain/entities/subscription_state.dart';

final subscriptionLocalDatasourceProvider =
    Provider<SubscriptionLocalDatasource>(
      (ref) => const SubscriptionLocalDatasource(),
    );

final subscriptionControllerProvider =
    AsyncNotifierProvider<SubscriptionController, SubscriptionState>(
      SubscriptionController.new,
    );

final subscriptionUsageProvider = Provider<SubscriptionUsage>((ref) {
  ref.watch(clientsControllerProvider);
  ref.watch(invoicesControllerProvider);
  return ref.read(subscriptionLocalDatasourceProvider).loadUsage();
});

final subscriptionGatekeeperProvider = Provider<SubscriptionGatekeeper>(
  (ref) => SubscriptionGatekeeper(ref),
);

class SubscriptionController extends AsyncNotifier<SubscriptionState> {
  @override
  Future<SubscriptionState> build() async {
    final datasource = ref.read(subscriptionLocalDatasourceProvider);
    final localState = await datasource.loadState();

    try {
      final syncedIsPro = await ref
          .read(playBillingServiceProvider)
          .syncOwnedProState();
      // Only upgrade (free → pro). Never downgrade from sync — queryPastPurchases
      // can return an empty list when Play Store is offline, which is not a
      // confirmed cancellation. Downgrades happen via the purchase stream only.
      if (syncedIsPro != true) {
        return localState;
      }
      if (localState.isPro) {
        return localState;
      }
      return datasource.savePlan(isPro: true);
    } catch (e, st) {
      debugPrint('[SubscriptionController] syncOwnedProState failed: $e\n$st');
      return localState;
    }
  }

  Future<void> setPlan({required bool isPro}) async {
    final next = await ref
        .read(subscriptionLocalDatasourceProvider)
        .savePlan(isPro: isPro);
    state = AsyncValue.data(next);
  }

  Future<void> upgradeToPro() async {
    await setPlan(isPro: true);
  }
}

class SubscriptionGatekeeper {
  const SubscriptionGatekeeper(this._ref);

  final Ref _ref;

  Future<SubscriptionGateDecision> evaluate(
    SubscriptionGateFeature feature,
  ) async {
    final subscription = await _ref.read(subscriptionControllerProvider.future);
    final usage = _ref.read(subscriptionLocalDatasourceProvider).loadUsage();

    switch (feature) {
      case SubscriptionGateFeature.createInvoice:
        if (subscription.isPro || !usage.hasReachedMonthlyInvoiceLimit) {
          return SubscriptionGateDecision.allowed(
            feature,
            isPro: subscription.isPro,
          );
        }

        return SubscriptionGateDecision.blocked(
          feature: feature,
          reason: SubscriptionGateReason.limitReached,
          promptTitle: 'You\'ve reached your free limit',
          promptMessage:
              'You\'ve used all 5 free invoices this month. Upgrade to continue without limits and unlock full access instantly.',
        );
      case SubscriptionGateFeature.addClient:
        if (subscription.isPro || !usage.hasReachedClientLimit) {
          return SubscriptionGateDecision.allowed(
            feature,
            isPro: subscription.isPro,
          );
        }

        return SubscriptionGateDecision.blocked(
          feature: feature,
          reason: SubscriptionGateReason.limitReached,
          promptTitle: 'You\'ve reached your free limit',
          promptMessage:
              'You already have 5 clients on Free. Upgrade to continue without limits and keep every client in one premium workspace.',
        );
      case SubscriptionGateFeature.exportPdf:
        return SubscriptionGateDecision.allowed(
          feature,
          isPro: subscription.isPro,
          shouldWatermarkPdf: subscription.shouldWatermarkPdf,
        );
      case SubscriptionGateFeature.smartReminders:
        if (subscription.isPro) {
          return SubscriptionGateDecision.allowed(feature, isPro: true);
        }

        return SubscriptionGateDecision.blocked(
          feature: feature,
          reason: SubscriptionGateReason.premiumFeature,
          promptTitle: 'Unlock Smart Reminders',
          promptMessage:
              'Upgrade to continue without limits and unlock smart reminder prompts, premium branding, and a more professional billing flow.',
        );
      case SubscriptionGateFeature.whatsappSharing:
        if (subscription.isPro) {
          return SubscriptionGateDecision.allowed(feature, isPro: true);
        }

        return SubscriptionGateDecision.blocked(
          feature: feature,
          reason: SubscriptionGateReason.premiumFeature,
          promptTitle: 'Unlock WhatsApp Sharing',
          promptMessage:
              'Unlock full access instantly with WhatsApp sharing, watermark-free PDFs, and a more polished client experience.',
        );
      case SubscriptionGateFeature.premiumBranding:
        if (subscription.isPro) {
          return SubscriptionGateDecision.allowed(feature, isPro: true);
        }

        return SubscriptionGateDecision.blocked(
          feature: feature,
          reason: SubscriptionGateReason.premiumFeature,
          promptTitle: 'Remove branding and add your logo',
          promptMessage:
              'Upgrade to continue without limits, remove the watermark, and present every invoice with your own professional branding.',
        );
      case SubscriptionGateFeature.advancedTotals:
        if (subscription.isPro) {
          return SubscriptionGateDecision.allowed(feature, isPro: true);
        }

        return SubscriptionGateDecision.blocked(
          feature: feature,
          reason: SubscriptionGateReason.premiumFeature,
          promptTitle: 'Unlock advanced invoice features',
          promptMessage:
              'Upgrade to unlock advanced invoice features like discounts, premium totals, signatures, and polished branded exports.',
        );
    }
  }

  Future<void> ensureAllowed(SubscriptionGateFeature feature) async {
    final decision = await evaluate(feature);
    if (!decision.isAllowed) {
      throw SubscriptionGateException(decision);
    }
  }
}
