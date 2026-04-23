import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../clients/presentation/controllers/clients_controller.dart';
import '../../../invoices/presentation/controllers/invoices_controller.dart';
import '../../data/datasources/subscription_local_datasource.dart';
import '../../data/services/billing_service.dart';
import '../../domain/services/billing_service_interface.dart';
import '../../domain/entities/subscription_state.dart';
import '../../../../data/providers/firestore_sync_provider.dart';
import '../../../../data/services/workspace/workspace_provider.dart';

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

/// Runtime debug bypass — survives hot restart, persists across sessions via Hive.
/// Toggled from the hidden Developer Options section in Settings (7-tap on header).
final debugModeProvider = StateProvider<bool>((ref) {
  final datasource = ref.read(subscriptionLocalDatasourceProvider);
  return datasource.loadDebugMode();
});

class SubscriptionController extends AsyncNotifier<SubscriptionState> {
  /// Set to true to bypass subscription gates during testing.
  /// Has zero effect in release builds — kDebugMode is false.
  /// MUST be set back to false before Play Store submission.
  static const bool _debugBypassSubscription = true;

  @override
  Future<SubscriptionState> build() async {
    if (kDebugMode && _debugBypassSubscription) {
      return const SubscriptionState.business();
    }

    if (ref.watch(debugModeProvider)) {
      return const SubscriptionState.business();
    }

    final datasource = ref.read(subscriptionLocalDatasourceProvider);
    final localState = await datasource.loadState();

    try {
      final syncedPlan = await ref
          .read(billingServiceProvider)
          .syncOwnedPlanState(BillingServiceInterface.allProductIds);
      // Only upgrade (free → pro). Never downgrade from sync — queryPastPurchases
      // can return an empty list when Store is offline, which is not a
      // confirmed cancellation. Downgrades happen via the purchase stream only.
      if (syncedPlan == null || syncedPlan == InvoiceFlowPlan.free) {
        return localState;
      }
      if (localState.plan == syncedPlan) {
        return localState;
      }
      return datasource.savePlanTier(syncedPlan);
    } catch (e, st) {
      debugPrint('[SubscriptionController] syncOwnedProState failed: $e\n$st');
      return localState;
    }
  }

  Future<void> setDebugMode(bool value) async {
    await ref.read(subscriptionLocalDatasourceProvider).saveDebugMode(value);
    ref.read(debugModeProvider.notifier).state = value;
  }

  Future<void> setPlan({required bool isPro}) async {
    final next = await ref
        .read(subscriptionLocalDatasourceProvider)
        .savePlan(isPro: isPro);
    state = AsyncValue.data(next);
  }

  Future<void> upgradeToPro() async {
    await setPlan(isPro: true);

    // Upload any existing local Hive data to Firestore now that user is Pro.
    final userId = ref.read(activeWorkspaceOwnerIdProvider);
    if (userId != null) {
      ref
          .read(firestoreSyncServiceProvider)
          .uploadLocalDataToCloud(userId)
          .catchError((Object e) {
            debugPrint(
              '[SubscriptionController] uploadLocalDataToCloud error: $e',
            );
            return null;
          });
    }
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
              'You already have 3 clients on Free. Upgrade to continue without limits and keep every client in one premium workspace.',
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
      case SubscriptionGateFeature.partialPayments:
        if (subscription.isPro) {
          return SubscriptionGateDecision.allowed(feature, isPro: true);
        }

        return SubscriptionGateDecision.blocked(
          feature: feature,
          reason: SubscriptionGateReason.premiumFeature,
          promptTitle: 'Track partial payments',
          promptMessage:
              'Upgrade to track partial payments, send payment receipts, and maintain clear records of what your clients still owe.',
        );
      case SubscriptionGateFeature.exportCsv:
        if (subscription.isPro) {
          return SubscriptionGateDecision.allowed(feature, isPro: true);
        }

        return SubscriptionGateDecision.blocked(
          feature: feature,
          reason: SubscriptionGateReason.premiumFeature,
          promptTitle: 'Unlock CSV Export',
          promptMessage:
              'Upgrade to export your entire invoice list as a CSV file, perfect for your records or sharing with your accountant.',
        );
      case SubscriptionGateFeature.teamMembers:
        if (subscription.isBusiness) {
          return SubscriptionGateDecision.allowed(feature, isPro: true);
        }

        return SubscriptionGateDecision.blocked(
          feature: feature,
          reason: SubscriptionGateReason.premiumFeature,
          promptTitle: 'Unlock Team Members',
          promptMessage:
              'Team collaboration is available on Business Plan. Upgrade to add up to 2 additional members.',
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
