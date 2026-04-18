enum InvoiceFlowPlan { free, pro, business }

enum SubscriptionGateFeature {
  createInvoice,
  addClient,
  exportPdf,
  smartReminders,
  whatsappSharing,
  premiumBranding,
  advancedTotals,
  partialPayments,
  exportCsv,
  teamMembers,
}

enum SubscriptionGateReason { limitReached, premiumFeature }

class SubscriptionState {
  const SubscriptionState({required this.isPro, this.isBusiness = false});

  const SubscriptionState.free() : isPro = false, isBusiness = false;

  const SubscriptionState.pro() : isPro = true, isBusiness = false;

  const SubscriptionState.business() : isPro = true, isBusiness = true;

  static const int freeClientLimit = 3;
  static const int freeMonthlyInvoiceLimit = 5;

  final bool isPro;
  final bool isBusiness;

  InvoiceFlowPlan get plan => isBusiness
      ? InvoiceFlowPlan.business
      : (isPro ? InvoiceFlowPlan.pro : InvoiceFlowPlan.free);

  String get planLabel => switch (plan) {
    InvoiceFlowPlan.free => 'Free',
    InvoiceFlowPlan.pro => 'Pro',
    InvoiceFlowPlan.business => 'Business',
  };

  bool get shouldWatermarkPdf => !isPro;
}

class SubscriptionUsage {
  const SubscriptionUsage({
    required this.clientCount,
    required this.monthlyInvoiceCount,
  });

  final int clientCount;
  final int monthlyInvoiceCount;

  bool get hasReachedClientLimit =>
      clientCount >= SubscriptionState.freeClientLimit;

  bool get hasReachedMonthlyInvoiceLimit =>
      monthlyInvoiceCount >= SubscriptionState.freeMonthlyInvoiceLimit;

  int get remainingClientSlots {
    final remaining = SubscriptionState.freeClientLimit - clientCount;
    return remaining < 0 ? 0 : remaining;
  }

  int get remainingMonthlyInvoiceSlots {
    final remaining =
        SubscriptionState.freeMonthlyInvoiceLimit - monthlyInvoiceCount;
    return remaining < 0 ? 0 : remaining;
  }

  String get clientUsageLabel =>
      '$clientCount/${SubscriptionState.freeClientLimit} clients';

  String get invoiceUsageLabel =>
      '$monthlyInvoiceCount/${SubscriptionState.freeMonthlyInvoiceLimit} invoices this month';
}

class SubscriptionGateDecision {
  const SubscriptionGateDecision({
    required this.feature,
    required this.isAllowed,
    required this.isPro,
    required this.promptTitle,
    required this.promptMessage,
    this.reason,
    this.shouldWatermarkPdf = false,
  });

  final SubscriptionGateFeature feature;
  final bool isAllowed;
  final bool isPro;
  final String promptTitle;
  final String promptMessage;
  final SubscriptionGateReason? reason;
  final bool shouldWatermarkPdf;

  factory SubscriptionGateDecision.allowed(
    SubscriptionGateFeature feature, {
    required bool isPro,
    bool shouldWatermarkPdf = false,
  }) {
    return SubscriptionGateDecision(
      feature: feature,
      isAllowed: true,
      isPro: isPro,
      promptTitle: '',
      promptMessage: '',
      shouldWatermarkPdf: shouldWatermarkPdf,
    );
  }

  factory SubscriptionGateDecision.blocked({
    required SubscriptionGateFeature feature,
    required SubscriptionGateReason reason,
    required String promptTitle,
    required String promptMessage,
  }) {
    return SubscriptionGateDecision(
      feature: feature,
      isAllowed: false,
      isPro: false,
      promptTitle: promptTitle,
      promptMessage: promptMessage,
      reason: reason,
    );
  }
}

class SubscriptionGateException implements Exception {
  const SubscriptionGateException(this.decision);

  final SubscriptionGateDecision decision;

  @override
  String toString() => decision.promptMessage;
}
