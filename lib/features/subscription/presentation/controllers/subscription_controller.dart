import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../clients/presentation/controllers/clients_controller.dart';
import '../../../invoices/presentation/controllers/invoices_controller.dart';
import '../../data/datasources/subscription_local_datasource.dart';
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
  Future<SubscriptionState> build() {
    return ref.read(subscriptionLocalDatasourceProvider).loadState();
  }

  Future<void> upgradeToPro() async {
    final next = await ref
        .read(subscriptionLocalDatasourceProvider)
        .savePlan(isPro: true);
    state = AsyncValue.data(next);
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
          promptTitle: 'Free plan limit reached',
          promptMessage:
              'Free includes up to 5 invoices per month. Upgrade to Invoice Flow Pro for unlimited invoices, smart reminders, and watermark-free PDFs.',
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
          promptTitle: 'Free plan limit reached',
          promptMessage:
              'Free includes up to 5 clients. Upgrade to Invoice Flow Pro for unlimited clients, unlimited invoices, and premium reminder tools.',
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
              'Smart reminders are part of Invoice Flow Pro. Upgrade for proactive reminder prompts, unlimited clients, and unlimited invoices.',
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
              'WhatsApp sharing is part of Invoice Flow Pro. Upgrade to send reminders on WhatsApp and remove the PDF watermark.',
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
