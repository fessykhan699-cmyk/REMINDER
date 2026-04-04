import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/adaptive/adaptive_system_controller.dart';
import '../../../clients/domain/entities/client.dart';
import '../../../clients/presentation/controllers/clients_controller.dart';
import '../../../settings/domain/entities/app_preferences.dart';
import '../../../settings/presentation/controllers/app_preferences_controller.dart';
import '../../domain/entities/invoice.dart';
import 'invoice_creation_learning_controller.dart';
import 'invoices_controller.dart';

const double _quickCreateConfidenceThreshold = 0.80;
const double _suggestionConfidenceThreshold = 0.50;

final invoiceCreateLaunchModeProvider = StateProvider<InvoiceCreateLaunchMode>(
  (ref) => InvoiceCreateLaunchMode.assisted,
);

enum InvoiceCreateLaunchMode { assisted, manual }

enum InvoiceAutomationMode { instant, prefilledForm, manualForm }

enum InvoiceConfidenceTier { high, medium, low }

final smartInvoicePredictionProvider = Provider<SmartInvoicePrediction>((ref) {
  final invoices =
      ref.watch(invoicesControllerProvider).valueOrNull ?? const <Invoice>[];
  final clients =
      ref.watch(clientsControllerProvider).valueOrNull ?? const <Client>[];
  final learning = ref.watch(invoiceCreationLearningProvider);
  final adaptiveState = ref.watch(adaptiveSystemProvider);
  final preferences = ref.watch(appPreferencesControllerProvider).valueOrNull;
  final defaultDueDays = preferences?.paymentTerms.days ?? 30;

  if (!(preferences?.smartPredictionEnabled ?? true)) {
    return SmartInvoicePrediction.disabled(
      clients: clients,
      defaultDueDays: defaultDueDays,
    );
  }

  return SmartInvoicePrediction.fromData(
    invoices: invoices,
    clients: clients,
    learning: learning,
    adaptiveState: adaptiveState,
    now: DateTime.now(),
    defaultDueDays: defaultDueDays,
  );
});

class SmartInvoicePrediction {
  const SmartInvoicePrediction({
    required this.suggestedClient,
    required this.suggestedClientReason,
    required this.suggestedClientConfidence,
    required this.leadingClient,
    required this.leadingClientReason,
    required this.leadingClientConfidence,
    required this.preferredDueDays,
    required this.preferredDueDaysConfidence,
    required this.defaultDueDays,
    required this.quickAmount,
    required this.quickAmountReason,
    required this.quickAmountConfidence,
    required this.firstAvailableClient,
    required this.hasInvoiceHistory,
    required this.predictionWeights,
    required this.recentAccuracyAverage,
    required this.confidenceAdjustment,
    required this.oneTapTemporarilyDisabled,
    required Map<String, SmartClientSuggestion> suggestionsByClient,
    required Map<String, double> clientConfidenceById,
  }) : _suggestionsByClient = suggestionsByClient,
       _clientConfidenceById = clientConfidenceById;

  final Client? suggestedClient;
  final String? suggestedClientReason;
  final double suggestedClientConfidence;
  final Client? leadingClient;
  final String? leadingClientReason;
  final double leadingClientConfidence;
  final int? preferredDueDays;
  final double preferredDueDaysConfidence;
  final int defaultDueDays;
  final double? quickAmount;
  final String? quickAmountReason;
  final double quickAmountConfidence;
  final Client? firstAvailableClient;
  final bool hasInvoiceHistory;
  final PredictionModelWeights predictionWeights;
  final double recentAccuracyAverage;
  final double confidenceAdjustment;
  final bool oneTapTemporarilyDisabled;
  final Map<String, SmartClientSuggestion> _suggestionsByClient;
  final Map<String, double> _clientConfidenceById;

  bool get hasClients => firstAvailableClient != null;

  SmartClientSuggestion? suggestionFor(String clientId) {
    return _suggestionsByClient[clientId];
  }

  double clientConfidenceFor(String clientId) {
    return _clientConfidenceById[clientId] ?? 0.0;
  }

  SmartAutomationDecision buildPrimaryActionDecision({DateTime? now}) {
    final decisionTime = now ?? DateTime.now();
    final candidateClient = leadingClient;
    final suggestion = candidateClient == null
        ? null
        : _suggestionsByClient[candidateClient.id];
    final draft = candidateClient == null
        ? null
        : buildDraftForClient(
            candidateClient,
            now: decisionTime,
            minimumConfidence: 0.0,
          );

    final clientConfidence = draft?.clientConfidence ?? leadingClientConfidence;
    final serviceConfidence = draft == null || draft.usedFallbackService
        ? 0.0
        : draft.serviceConfidence;
    final amountConfidence = draft == null || draft.usedFallbackAmount
        ? 0.0
        : draft.amountConfidence;
    final dueDateConfidence = draft == null || draft.usedFallbackDueDays
        ? 0.0
        : draft.dueDaysConfidence;
    final recencyConfidence = suggestion?.recencyConfidence ?? 0.0;
    final confidenceScore =
        draft?.overallConfidence ??
        _composeConfidence(
          weights: predictionWeights,
          clientConfidence: clientConfidence,
          serviceConfidence: serviceConfidence,
          amountConfidence: amountConfidence,
          dueDateConfidence: dueDateConfidence,
          recencyConfidence: recencyConfidence,
          adjustment: confidenceAdjustment,
        );
    final instantThreshold = recentAccuracyAverage >= 0.80
        ? 0.78
        : _quickCreateConfidenceThreshold;
    final assistedThreshold = recentAccuracyAverage < 0.50
        ? 0.45
        : _suggestionConfidenceThreshold;

    final hasConflictingPatterns =
        !hasClients ||
        !hasInvoiceHistory ||
        draft == null ||
        candidateClient == null ||
        clientConfidence < 0.60 ||
        (!draft.usedFallbackService && serviceConfidence < 0.60) ||
        (!draft.usedFallbackAmount && amountConfidence < 0.60) ||
        (!draft.usedFallbackDueDays && dueDateConfidence < 0.55);

    final mode = !hasClients || !hasInvoiceHistory || candidateClient == null
        ? InvoiceAutomationMode.manualForm
        : oneTapTemporarilyDisabled
        ? InvoiceAutomationMode.prefilledForm
        : confidenceScore >= instantThreshold &&
              !hasConflictingPatterns &&
              !draft.usedFallbackClient &&
              !draft.usedFallbackService &&
              !draft.usedFallbackAmount &&
              !draft.usedFallbackDueDays
        ? InvoiceAutomationMode.instant
        : confidenceScore >= assistedThreshold
        ? InvoiceAutomationMode.prefilledForm
        : InvoiceAutomationMode.manualForm;

    final tier = confidenceScore >= instantThreshold
        ? InvoiceConfidenceTier.high
        : confidenceScore >= assistedThreshold
        ? InvoiceConfidenceTier.medium
        : InvoiceConfidenceTier.low;

    final reason = !hasClients
        ? 'No clients available'
        : !hasInvoiceHistory
        ? 'No invoice history yet'
        : candidateClient == null
        ? 'No reliable client candidate'
        : oneTapTemporarilyDisabled
        ? 'Temporarily using confirmation flow after recent misses'
        : hasConflictingPatterns && mode != InvoiceAutomationMode.prefilledForm
        ? 'Conflicting invoice patterns'
        : mode == InvoiceAutomationMode.instant
        ? 'Reliable automation'
        : mode == InvoiceAutomationMode.prefilledForm
        ? 'Needs confirmation'
        : 'Manual for safety';

    return SmartAutomationDecision(
      mode: mode,
      tier: tier,
      confidenceScore: confidenceScore,
      clientConfidence: clientConfidence,
      serviceConfidence: serviceConfidence,
      amountConfidence: amountConfidence,
      dueDateConfidence: dueDateConfidence,
      recencyConfidence: recencyConfidence,
      hasClients: hasClients,
      hasInvoiceHistory: hasInvoiceHistory,
      hasConflictingPatterns: hasConflictingPatterns,
      recentAccuracyAverage: recentAccuracyAverage,
      oneTapTemporarilyDisabled: oneTapTemporarilyDisabled,
      draft: draft,
      reason: reason,
    );
  }

  SmartInvoiceDraft buildQuickCreateDraft({DateTime? now}) {
    return buildDraftForClient(
      null,
      now: now,
      minimumConfidence: recentAccuracyAverage >= 0.80
          ? 0.78
          : _quickCreateConfidenceThreshold,
    );
  }

  SmartInvoiceDraft buildDraftForClient(
    Client? client, {
    DateTime? now,
    double minimumConfidence = _suggestionConfidenceThreshold,
  }) {
    final invoiceDate = now ?? DateTime.now();
    final suggestedClient = this.suggestedClient;
    final resolvedClient =
        client ??
        ((suggestedClient != null &&
                suggestedClientConfidence >= minimumConfidence)
            ? suggestedClient
            : firstAvailableClient);
    final suggestion = resolvedClient == null
        ? null
        : _suggestionsByClient[resolvedClient.id];
    final clientConfidence = resolvedClient == null
        ? 0.0
        : (resolvedClient.id == suggestedClient?.id
              ? suggestedClientConfidence
              : clientConfidenceFor(resolvedClient.id));

    final usePredictedService =
        suggestion?.service != null &&
        (suggestion?.serviceConfidence ?? 0.0) >= minimumConfidence;
    final usePredictedAmount =
        suggestion?.amount != null &&
        (suggestion?.amountConfidence ?? 0.0) >= minimumConfidence;
    final useGlobalAmount =
        !usePredictedAmount &&
        quickAmount != null &&
        quickAmountConfidence >= minimumConfidence;
    final usePredictedDueDays =
        suggestion?.suggestedDueDays != null &&
        (suggestion?.dueDaysConfidence ?? 0.0) >= minimumConfidence;
    final useGlobalDueDays =
        !usePredictedDueDays &&
        preferredDueDays != null &&
        preferredDueDaysConfidence >= minimumConfidence;
    final recencyConfidence = suggestion?.recencyConfidence ?? 0.0;

    final dueDays = usePredictedDueDays
        ? suggestion!.suggestedDueDays!
        : (useGlobalDueDays ? preferredDueDays! : defaultDueDays);
    final service = usePredictedService
        ? suggestion!.service!
        : 'General Service';
    final amount = usePredictedAmount
        ? suggestion!.amount!
        : (useGlobalAmount ? quickAmount! : 0.0);
    final dueDate = DateTime(
      invoiceDate.year,
      invoiceDate.month,
      invoiceDate.day,
    ).add(Duration(days: dueDays));

    return SmartInvoiceDraft(
      clientId: resolvedClient?.id ?? 'client-quick-general',
      clientName: resolvedClient?.name ?? 'General Client',
      service: service,
      amount: amount,
      dueDate: dueDate,
      dueDays: dueDays,
      client: resolvedClient,
      clientConfidence: clientConfidence,
      serviceConfidence: suggestion?.serviceConfidence ?? 0.0,
      amountConfidence: usePredictedAmount
          ? (suggestion?.amountConfidence ?? 0.0)
          : quickAmountConfidence,
      dueDaysConfidence: usePredictedDueDays
          ? (suggestion?.dueDaysConfidence ?? 0.0)
          : preferredDueDaysConfidence,
      recencyConfidence: recencyConfidence,
      overallConfidence: _composeConfidence(
        weights: predictionWeights,
        clientConfidence: clientConfidence,
        serviceConfidence: suggestion?.serviceConfidence ?? 0.0,
        amountConfidence: usePredictedAmount
            ? (suggestion?.amountConfidence ?? 0.0)
            : quickAmountConfidence,
        dueDateConfidence: usePredictedDueDays
            ? (suggestion?.dueDaysConfidence ?? 0.0)
            : preferredDueDaysConfidence,
        recencyConfidence: recencyConfidence,
        adjustment: confidenceAdjustment,
      ),
      usedFallbackClient:
          client == null &&
          (suggestedClient == null ||
              suggestedClientConfidence < minimumConfidence),
      usedFallbackService: !usePredictedService,
      usedFallbackAmount: !(usePredictedAmount || useGlobalAmount),
      usedFallbackDueDays: !(usePredictedDueDays || useGlobalDueDays),
      feedbackService: suggestion?.service,
      feedbackAmount: suggestion?.amount,
      feedbackDueDays: suggestion?.suggestedDueDays,
    );
  }

  factory SmartInvoicePrediction.fromData({
    required List<Invoice> invoices,
    required List<Client> clients,
    required InvoiceCreationLearningState learning,
    required AdaptiveSystemState adaptiveState,
    required DateTime now,
    int defaultDueDays = 30,
  }) {
    final context = _PredictionContext(now);
    final firstAvailableClient = clients.isEmpty ? null : clients.first;
    final clientStats = <String, _ClientAccumulator>{};
    final globalAmounts = <double>[];
    final globalDueDayCounts = <int, int>{};
    final globalDueDayLastUsedAt = <int, DateTime>{};
    Invoice? latestInvoice;

    for (final invoice in invoices) {
      final accumulator = clientStats.putIfAbsent(
        invoice.clientId,
        () => _ClientAccumulator(invoice.clientId),
      );
      accumulator.add(invoice, context);
      globalAmounts.add(invoice.amount);

      final dueDays = _positiveDueDays(invoice.createdAt, invoice.dueDate);
      if (dueDays != null) {
        globalDueDayCounts[dueDays] = (globalDueDayCounts[dueDays] ?? 0) + 1;
        final previousLastUsedAt = globalDueDayLastUsedAt[dueDays];
        if (previousLastUsedAt == null ||
            invoice.createdAt.isAfter(previousLastUsedAt)) {
          globalDueDayLastUsedAt[dueDays] = invoice.createdAt;
        }
      }

      if (latestInvoice == null ||
          invoice.createdAt.isAfter(latestInvoice.createdAt)) {
        latestInvoice = invoice;
      }
    }

    var maxClientUsageCount = 0;
    var maxUnpaidCount = 0;
    var maxOverdueCount = 0;
    for (final client in clients) {
      final stats = clientStats[client.id];
      final memory = learning.clientMemories[client.id];
      maxClientUsageCount = math.max(
        maxClientUsageCount,
        math.max(stats?.invoiceCount ?? 0, memory?.usageCount ?? 0),
      );
      maxUnpaidCount = math.max(maxUnpaidCount, stats?.unpaidCount ?? 0);
      maxOverdueCount = math.max(maxOverdueCount, stats?.overdueCount ?? 0);
    }

    final clientCandidates = <_RankedClient>[];
    for (final client in clients) {
      final stats = clientStats[client.id];
      final memory = learning.clientMemories[client.id];
      clientCandidates.add(
        _scoreClient(
          client: client,
          stats: stats,
          memory: memory,
          learning: learning,
          adaptiveState: adaptiveState,
          context: context,
          maxClientUsageCount: maxClientUsageCount,
          maxUnpaidCount: maxUnpaidCount,
          maxOverdueCount: maxOverdueCount,
        ),
      );
    }
    clientCandidates.sort((a, b) => b.score.compareTo(a.score));

    final clientConfidenceById = <String, double>{};
    for (var index = 0; index < clientCandidates.length; index++) {
      final current = clientCandidates[index];
      final next = index + 1 < clientCandidates.length
          ? clientCandidates[index + 1]
          : null;
      clientConfidenceById[current.client.id] = _confidenceFromScores(
        current.score,
        next?.score,
        current.sampleCount,
        current.feedbackScore,
      );
    }

    final topClient = clientCandidates.isEmpty ? null : clientCandidates.first;
    final topClientConfidence = topClient == null
        ? 0.0
        : (clientConfidenceById[topClient.client.id] ?? 0.0);
    final suggestedClient =
        topClient != null &&
            topClientConfidence >= _suggestionConfidenceThreshold
        ? topClient.client
        : null;

    final globalDueSuggestion = _resolveDueDaysSuggestion(
      counts: globalDueDayCounts.isNotEmpty
          ? globalDueDayCounts
          : _parseIntCounts(learning.dueDaysUsageCounts),
      lastUsedByValue: globalDueDayLastUsedAt,
      fallbackValue: latestInvoice == null
          ? defaultDueDays
          : (_positiveDueDays(latestInvoice.createdAt, latestInvoice.dueDate) ??
                defaultDueDays),
      feedback: null,
      defaultValue: defaultDueDays,
    );
    final globalAmountSuggestion = _resolveAmountSuggestion(
      amounts: globalAmounts,
      fallbackAmount: latestInvoice?.amount,
      feedback: null,
    );

    final suggestionsByClient = <String, SmartClientSuggestion>{};
    for (final client in clients) {
      final stats = clientStats[client.id];
      final memory = learning.clientMemories[client.id];
      suggestionsByClient[client.id] = _buildClientSuggestion(
        client: client,
        stats: stats,
        memory: memory,
        learning: learning,
        adaptiveState: adaptiveState,
        context: context,
        clientConfidence: clientConfidenceById[client.id] ?? 0.0,
        fallbackDueSuggestion: globalDueSuggestion,
      );
    }

    return SmartInvoicePrediction(
      suggestedClient: suggestedClient,
      suggestedClientReason: topClient?.reason,
      suggestedClientConfidence: topClientConfidence,
      leadingClient: topClient?.client,
      leadingClientReason: topClient?.reason,
      leadingClientConfidence: topClientConfidence,
      preferredDueDays: globalDueSuggestion.value,
      preferredDueDaysConfidence: globalDueSuggestion.confidence,
      defaultDueDays: globalDueSuggestion.value ?? defaultDueDays,
      quickAmount: globalAmountSuggestion.value,
      quickAmountReason: globalAmountSuggestion.reason,
      quickAmountConfidence: globalAmountSuggestion.confidence,
      firstAvailableClient: firstAvailableClient,
      hasInvoiceHistory: invoices.isNotEmpty,
      predictionWeights: learning.predictionWeights,
      recentAccuracyAverage: learning.recentAccuracyAverage,
      confidenceAdjustment: learning.confidenceAdjustment,
      oneTapTemporarilyDisabled: learning.isOneTapTemporarilyDisabled,
      suggestionsByClient: suggestionsByClient,
      clientConfidenceById: clientConfidenceById,
    );
  }

  factory SmartInvoicePrediction.disabled({
    required List<Client> clients,
    int defaultDueDays = 30,
  }) {
    return SmartInvoicePrediction(
      suggestedClient: null,
      suggestedClientReason: null,
      suggestedClientConfidence: 0.0,
      leadingClient: null,
      leadingClientReason: null,
      leadingClientConfidence: 0.0,
      preferredDueDays: null,
      preferredDueDaysConfidence: 0.0,
      defaultDueDays: defaultDueDays,
      quickAmount: null,
      quickAmountReason: null,
      quickAmountConfidence: 0.0,
      firstAvailableClient: clients.isEmpty ? null : clients.first,
      hasInvoiceHistory: false,
      predictionWeights: const PredictionModelWeights.initial(),
      recentAccuracyAverage: 0.0,
      confidenceAdjustment: 0.0,
      oneTapTemporarilyDisabled: false,
      suggestionsByClient: const <String, SmartClientSuggestion>{},
      clientConfidenceById: const <String, double>{},
    );
  }
}

class SmartAutomationDecision {
  const SmartAutomationDecision({
    required this.mode,
    required this.tier,
    required this.confidenceScore,
    required this.clientConfidence,
    required this.serviceConfidence,
    required this.amountConfidence,
    required this.dueDateConfidence,
    required this.recencyConfidence,
    required this.hasClients,
    required this.hasInvoiceHistory,
    required this.hasConflictingPatterns,
    required this.recentAccuracyAverage,
    required this.oneTapTemporarilyDisabled,
    required this.draft,
    required this.reason,
  });

  final InvoiceAutomationMode mode;
  final InvoiceConfidenceTier tier;
  final double confidenceScore;
  final double clientConfidence;
  final double serviceConfidence;
  final double amountConfidence;
  final double dueDateConfidence;
  final double recencyConfidence;
  final bool hasClients;
  final bool hasInvoiceHistory;
  final bool hasConflictingPatterns;
  final double recentAccuracyAverage;
  final bool oneTapTemporarilyDisabled;
  final SmartInvoiceDraft? draft;
  final String reason;

  int get confidencePercent => _confidencePercent(confidenceScore);
  int get recentAccuracyPercent => _confidencePercent(recentAccuracyAverage);
  bool get allowsAutomation => mode == InvoiceAutomationMode.instant;
  bool get shouldPrefillForm => mode == InvoiceAutomationMode.prefilledForm;
  bool get shouldOpenManualForm => mode == InvoiceAutomationMode.manualForm;

  String get debugSummary =>
      'Confidence: $confidencePercent% (${tier.name}) | Accuracy: $recentAccuracyPercent%';
}

class SmartClientSuggestion {
  const SmartClientSuggestion({
    required this.client,
    required this.clientConfidence,
    required this.service,
    required this.serviceConfidence,
    required this.amount,
    required this.amountConfidence,
    required this.amountReason,
    required this.suggestedDueDays,
    required this.dueDaysConfidence,
    required this.recencyConfidence,
    required this.overallConfidence,
    required this.latestInvoice,
  });

  final Client client;
  final double clientConfidence;
  final String? service;
  final double serviceConfidence;
  final double? amount;
  final double amountConfidence;
  final String? amountReason;
  final int? suggestedDueDays;
  final double dueDaysConfidence;
  final double recencyConfidence;
  final double overallConfidence;
  final Invoice? latestInvoice;

  int get confidencePercent => _confidencePercent(overallConfidence);
}

class SmartInvoiceDraft {
  const SmartInvoiceDraft({
    required this.clientId,
    required this.clientName,
    required this.service,
    required this.amount,
    required this.dueDate,
    required this.dueDays,
    required this.client,
    required this.clientConfidence,
    required this.serviceConfidence,
    required this.amountConfidence,
    required this.dueDaysConfidence,
    required this.recencyConfidence,
    required this.overallConfidence,
    required this.usedFallbackClient,
    required this.usedFallbackService,
    required this.usedFallbackAmount,
    required this.usedFallbackDueDays,
    required this.feedbackService,
    required this.feedbackAmount,
    required this.feedbackDueDays,
  });

  final String clientId;
  final String clientName;
  final String service;
  final double amount;
  final DateTime dueDate;
  final int dueDays;
  final Client? client;
  final double clientConfidence;
  final double serviceConfidence;
  final double amountConfidence;
  final double dueDaysConfidence;
  final double recencyConfidence;
  final double overallConfidence;
  final bool usedFallbackClient;
  final bool usedFallbackService;
  final bool usedFallbackAmount;
  final bool usedFallbackDueDays;
  final String? feedbackService;
  final double? feedbackAmount;
  final int? feedbackDueDays;

  String get dedupeSignature {
    final dueDateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return '$clientId|$service|${amount.toStringAsFixed(2)}|${dueDateOnly.toIso8601String()}';
  }

  int get confidencePercent => _confidencePercent(overallConfidence);
}

class _PredictionContext {
  _PredictionContext(this.now)
    : weekday = now.weekday,
      timeBucket = _timeBucketFor(now);

  final DateTime now;
  final int weekday;
  final _TimeBucket timeBucket;

  bool isRecent(DateTime? value, Duration window) {
    if (value == null) {
      return false;
    }
    return now.difference(value) <= window;
  }
}

enum _TimeBucket { morning, afternoon, evening, night }

class _ClientAccumulator {
  _ClientAccumulator(this.clientId);

  final String clientId;
  int invoiceCount = 0;
  int unpaidCount = 0;
  int overdueCount = 0;
  DateTime? lastCreatedAt;
  Invoice? latestInvoice;
  final Map<int, int> weekdayCounts = {};
  final Map<_TimeBucket, int> timeBucketCounts = {};
  final Map<int, int> dueDayCounts = {};
  final Map<int, DateTime> dueDayLastUsedAt = {};
  final Map<String, _ServiceAccumulator> services = {};

  void add(Invoice invoice, _PredictionContext context) {
    invoiceCount += 1;
    lastCreatedAt =
        lastCreatedAt == null || invoice.createdAt.isAfter(lastCreatedAt!)
        ? invoice.createdAt
        : lastCreatedAt;
    if (latestInvoice == null ||
        invoice.createdAt.isAfter(latestInvoice!.createdAt)) {
      latestInvoice = invoice;
    }

    _incrementIntMap(weekdayCounts, invoice.createdAt.weekday);
    _incrementTimeBucketMap(
      timeBucketCounts,
      _timeBucketFor(invoice.createdAt),
    );

    final isOverdue =
        invoice.status == InvoiceStatus.overdue ||
        (invoice.status != InvoiceStatus.paid &&
            invoice.dueDate.isBefore(context.now));
    if (invoice.status != InvoiceStatus.paid) {
      unpaidCount += 1;
    }
    if (isOverdue) {
      overdueCount += 1;
    }

    final dueDays = _positiveDueDays(invoice.createdAt, invoice.dueDate);
    if (dueDays != null) {
      _incrementIntMap(dueDayCounts, dueDays);
      final previous = dueDayLastUsedAt[dueDays];
      if (previous == null || invoice.createdAt.isAfter(previous)) {
        dueDayLastUsedAt[dueDays] = invoice.createdAt;
      }
    }

    final service = invoice.service.trim();
    if (service.isEmpty) {
      return;
    }

    final serviceAccumulator = services.putIfAbsent(
      service,
      () => _ServiceAccumulator(service),
    );
    serviceAccumulator.add(invoice, context);
  }
}

class _ServiceAccumulator {
  _ServiceAccumulator(this.service);

  final String service;
  int usageCount = 0;
  int unpaidCount = 0;
  int overdueCount = 0;
  DateTime? lastUsedAt;
  double? lastAmount;
  final List<double> amounts = <double>[];
  final Map<int, int> weekdayCounts = {};
  final Map<_TimeBucket, int> timeBucketCounts = {};

  void add(Invoice invoice, _PredictionContext context) {
    usageCount += 1;
    lastUsedAt = lastUsedAt == null || invoice.createdAt.isAfter(lastUsedAt!)
        ? invoice.createdAt
        : lastUsedAt;
    lastAmount = invoice.amount;
    amounts.add(invoice.amount);

    _incrementIntMap(weekdayCounts, invoice.createdAt.weekday);
    _incrementTimeBucketMap(
      timeBucketCounts,
      _timeBucketFor(invoice.createdAt),
    );

    final isOverdue =
        invoice.status == InvoiceStatus.overdue ||
        (invoice.status != InvoiceStatus.paid &&
            invoice.dueDate.isBefore(context.now));
    if (invoice.status != InvoiceStatus.paid) {
      unpaidCount += 1;
    }
    if (isOverdue) {
      overdueCount += 1;
    }
  }
}

class _RankedClient {
  const _RankedClient({
    required this.client,
    required this.score,
    required this.reason,
    required this.sampleCount,
    required this.feedbackScore,
  });

  final Client client;
  final double score;
  final String reason;
  final int sampleCount;
  final double feedbackScore;
}

class _RankedService {
  const _RankedService({
    required this.service,
    required this.score,
    required this.sampleCount,
    required this.feedbackScore,
  });

  final String service;
  final double score;
  final int sampleCount;
  final double feedbackScore;
}

class _ValuePrediction<T> {
  const _ValuePrediction({
    required this.value,
    required this.confidence,
    required this.reason,
  });

  final T? value;
  final double confidence;
  final String? reason;
}

_RankedClient _scoreClient({
  required Client client,
  required _ClientAccumulator? stats,
  required InvoiceCreationClientMemory? memory,
  required InvoiceCreationLearningState learning,
  required AdaptiveSystemState adaptiveState,
  required _PredictionContext context,
  required int maxClientUsageCount,
  required int maxUnpaidCount,
  required int maxOverdueCount,
}) {
  final usageCount = math.max(
    stats?.invoiceCount ?? 0,
    memory?.usageCount ?? 0,
  );
  final frequencyScore = maxClientUsageCount <= 0
      ? 0.0
      : usageCount / maxClientUsageCount;
  final recencyScore = _recencyScore(
    stats?.lastCreatedAt ?? memory?.lastUsedAt,
    context.now,
    decayDays: 28,
  );
  final timePatternScore = stats == null
      ? 0.0
      : _timeMatchScore(
          weekdayCounts: stats.weekdayCounts,
          timeBucketCounts: stats.timeBucketCounts,
          totalCount: stats.invoiceCount,
          context: context,
        );

  var recentInteractionBoost = 0.0;
  if (learning.lastClientId == client.id) {
    recentInteractionBoost = 0.75;
  }
  if (adaptiveState.lastAction == AdaptiveActionKey.newInvoice &&
      adaptiveState.lastActionAt != null &&
      context.isRecent(adaptiveState.lastActionAt, const Duration(hours: 12)) &&
      learning.lastClientId == client.id) {
    recentInteractionBoost = 0.95;
  }
  if (adaptiveState.lastAction == AdaptiveActionKey.addClient &&
      adaptiveState.lastActionAt != null &&
      context.isRecent(adaptiveState.lastActionAt, const Duration(hours: 6)) &&
      context.isRecent(client.createdAt, const Duration(hours: 6))) {
    recentInteractionBoost = math.max(recentInteractionBoost, 0.98);
  }

  final viewedBoost =
      learning.lastViewedClientId == client.id &&
          context.isRecent(
            learning.lastViewedClientAt,
            const Duration(minutes: 45),
          )
      ? 1.0
      : 0.0;
  final unpaidBoost = maxUnpaidCount <= 0
      ? 0.0
      : (stats?.unpaidCount ?? 0) / maxUnpaidCount;
  final overdueBoost = maxOverdueCount <= 0
      ? 0.0
      : (stats?.overdueCount ?? 0) / maxOverdueCount;
  var contextScore = _clamp01(
    math.max(viewedBoost, recentInteractionBoost) * 0.65 +
        unpaidBoost * 0.15 +
        overdueBoost * 0.20,
  );

  if (adaptiveState.lastAction == AdaptiveActionKey.reviewPayments &&
      adaptiveState.lastActionAt != null &&
      context.isRecent(adaptiveState.lastActionAt, const Duration(hours: 6)) &&
      (stats?.overdueCount ?? 0) > 0) {
    contextScore = _clamp01(contextScore + 0.12);
  }

  final feedbackScore =
      learning.clientPredictionFeedback[client.id]?.smoothedAcceptanceRate ??
      0.65;
  final historyScore = _clamp01(usageCount / 4);
  var score = _clamp01(
    (frequencyScore * 0.28) +
        (recencyScore * 0.22) +
        (timePatternScore * 0.16) +
        (contextScore * 0.16) +
        (feedbackScore * 0.10) +
        (historyScore * 0.08),
  );

  if (usageCount <= 1 && viewedBoost < 0.9 && recentInteractionBoost < 0.9) {
    score *= 0.58;
  }
  if (usageCount == 0 && viewedBoost == 0 && recentInteractionBoost == 0) {
    score *= 0.35;
  }

  String reason = 'Frequent client';
  if (viewedBoost > 0.9) {
    reason = 'Recently viewed client';
  } else if (recentInteractionBoost > 0.9) {
    reason = 'Recent client activity';
  } else if (timePatternScore > math.max(frequencyScore, recencyScore) &&
      timePatternScore > 0.32) {
    reason = 'Typical for this time';
  } else if (recencyScore >= frequencyScore && recencyScore > 0.42) {
    reason = 'Recent client';
  }

  return _RankedClient(
    client: client,
    score: score,
    reason: reason,
    sampleCount: usageCount,
    feedbackScore: feedbackScore,
  );
}

SmartClientSuggestion _buildClientSuggestion({
  required Client client,
  required _ClientAccumulator? stats,
  required InvoiceCreationClientMemory? memory,
  required InvoiceCreationLearningState learning,
  required AdaptiveSystemState adaptiveState,
  required _PredictionContext context,
  required double clientConfidence,
  required _ValuePrediction<int> fallbackDueSuggestion,
}) {
  final latestInvoice = stats?.latestInvoice;
  final recencyConfidence = _recentActivityConfidence(
    stats?.lastCreatedAt ?? memory?.lastUsedAt,
    context.now,
  );
  final serviceNames = <String>{
    if (memory?.lastService != null) memory!.lastService!,
    ...?stats?.services.keys,
    ...?memory?.serviceUsageCounts.keys,
  }..removeWhere((service) => service.trim().isEmpty);

  final rankedServices = <_RankedService>[];
  var maxServiceUsageCount = 0;
  for (final service in serviceNames) {
    final statsUsage = stats?.services[service]?.usageCount ?? 0;
    final memoryUsage = memory?.serviceUsageCounts[service] ?? 0;
    maxServiceUsageCount = math.max(
      maxServiceUsageCount,
      math.max(statsUsage, memoryUsage),
    );
  }

  for (final service in serviceNames) {
    final serviceStats = stats?.services[service];
    final usageCount = math.max(
      serviceStats?.usageCount ?? 0,
      memory?.serviceUsageCounts[service] ?? 0,
    );
    final frequencyScore = maxServiceUsageCount <= 0
        ? 0.0
        : usageCount / maxServiceUsageCount;
    final recencyScore = _recencyScore(
      serviceStats?.lastUsedAt ??
          (memory?.lastService == service ? memory?.lastUsedAt : null),
      context.now,
      decayDays: 21,
    );
    final timePatternScore = serviceStats == null
        ? 0.0
        : _timeMatchScore(
            weekdayCounts: serviceStats.weekdayCounts,
            timeBucketCounts: serviceStats.timeBucketCounts,
            totalCount: serviceStats.usageCount,
            context: context,
          );
    final feedbackScore =
        learning
            .servicePredictionFeedback[_serviceFeedbackKey(client.id, service)]
            ?.smoothedAcceptanceRate ??
        0.65;

    var contextScore = 0.0;
    if (latestInvoice != null &&
        _normalizedText(latestInvoice.service) == _normalizedText(service)) {
      contextScore = math.max(contextScore, 0.72);
    }
    if ((serviceStats?.overdueCount ?? 0) > 0) {
      contextScore = math.max(contextScore, 0.82);
    }
    if (learning.lastViewedClientId == client.id &&
        context.isRecent(
          learning.lastViewedClientAt,
          const Duration(minutes: 45),
        ) &&
        latestInvoice != null &&
        _normalizedText(latestInvoice.service) == _normalizedText(service)) {
      contextScore = math.max(contextScore, 0.95);
    }
    if (adaptiveState.lastAction == AdaptiveActionKey.newInvoice &&
        adaptiveState.lastActionAt != null &&
        context.isRecent(
          adaptiveState.lastActionAt,
          const Duration(hours: 12),
        ) &&
        memory?.lastService == service) {
      contextScore = math.max(contextScore, 0.88);
    }

    var score = _clamp01(
      (frequencyScore * 0.30) +
          (recencyScore * 0.22) +
          (timePatternScore * 0.18) +
          (contextScore * 0.14) +
          (feedbackScore * 0.10) +
          (_clamp01(usageCount / 3) * 0.06),
    );
    if (usageCount <= 1 && contextScore < 0.8) {
      score *= 0.60;
    }

    rankedServices.add(
      _RankedService(
        service: service,
        score: score,
        sampleCount: usageCount,
        feedbackScore: feedbackScore,
      ),
    );
  }
  rankedServices.sort((a, b) => b.score.compareTo(a.score));

  final topService = rankedServices.isEmpty ? null : rankedServices.first;
  final serviceConfidence = topService == null
      ? 0.0
      : _confidenceFromScores(
          topService.score,
          rankedServices.length > 1 ? rankedServices[1].score : null,
          topService.sampleCount,
          topService.feedbackScore,
        );
  final selectedService = topService?.service;
  final selectedServiceStats = selectedService == null
      ? null
      : stats?.services[selectedService];

  final amountSuggestion = _resolveAmountSuggestion(
    amounts:
        selectedServiceStats?.amounts ??
        _expandAmountCounts(
          memory?.serviceAmountUsageCounts[selectedService] ??
              const <String, int>{},
        ),
    fallbackAmount: selectedServiceStats?.lastAmount ?? memory?.lastAmount,
    feedback: selectedService == null
        ? null
        : learning.amountPredictionFeedback[_amountFeedbackKey(
            client.id,
            selectedService,
            selectedServiceStats?.lastAmount ?? memory?.lastAmount ?? 0.0,
          )],
  );

  final dueSuggestion = _resolveDueDaysSuggestion(
    counts: (stats?.dueDayCounts.isNotEmpty ?? false)
        ? stats!.dueDayCounts
        : _singleValueCount(memory?.lastDueDays),
    lastUsedByValue: stats?.dueDayLastUsedAt ?? const <int, DateTime>{},
    fallbackValue: memory?.lastDueDays ?? fallbackDueSuggestion.value ?? 7,
    feedback:
        learning.dueDaysPredictionFeedback[_dueDaysFeedbackKey(
          client.id,
          memory?.lastDueDays ?? fallbackDueSuggestion.value ?? 7,
        )],
    defaultValue: fallbackDueSuggestion.value ?? 7,
  );

  final overallConfidence = _clamp01(
    _composeConfidence(
      weights: learning.predictionWeights,
      clientConfidence: clientConfidence,
      serviceConfidence: serviceConfidence,
      amountConfidence: amountSuggestion.confidence,
      dueDateConfidence: dueSuggestion.confidence,
      recencyConfidence: recencyConfidence,
      adjustment: learning.confidenceAdjustment,
    ),
  );

  return SmartClientSuggestion(
    client: client,
    clientConfidence: clientConfidence,
    service: selectedService,
    serviceConfidence: serviceConfidence,
    amount: amountSuggestion.value,
    amountConfidence: amountSuggestion.confidence,
    amountReason: amountSuggestion.reason,
    suggestedDueDays: dueSuggestion.value,
    dueDaysConfidence: dueSuggestion.confidence,
    recencyConfidence: recencyConfidence,
    overallConfidence: overallConfidence,
    latestInvoice: latestInvoice,
  );
}

_ValuePrediction<double> _resolveAmountSuggestion({
  required List<double> amounts,
  required double? fallbackAmount,
  required PredictionFeedback? feedback,
}) {
  if (amounts.isEmpty) {
    if (fallbackAmount == null) {
      return const _ValuePrediction<double>(
        value: null,
        confidence: 0.0,
        reason: null,
      );
    }
    return _ValuePrediction<double>(
      value: fallbackAmount,
      confidence: _clamp01((feedback?.smoothedAcceptanceRate ?? 0.55) * 0.65),
      reason: 'last used',
    );
  }

  final median = _median(amounts);
  final deviations = amounts
      .map((amount) => (amount - median).abs())
      .toList(growable: false);
  final mad = _median(deviations);
  final threshold = mad <= 0.01
      ? math.max(1.0, median.abs() * 0.10)
      : mad * 2.5;
  final filtered = amounts
      .where((amount) => (amount - median).abs() <= threshold)
      .toList(growable: false);
  final normalizedAmounts = filtered.isEmpty ? amounts : filtered;
  final normalizedMedian = _median(normalizedAmounts);
  final normalizedMad = _median(
    normalizedAmounts
        .map((amount) => (amount - normalizedMedian).abs())
        .toList(growable: false),
  );

  final absoluteMedian = normalizedMedian.abs();
  final variationScore = absoluteMedian <= 0.01
      ? 1.0
      : _clamp01(1 - ((normalizedMad / absoluteMedian) * 2.2));

  final counts = <String, int>{};
  for (final amount in normalizedAmounts) {
    final key = amount.toStringAsFixed(2);
    counts[key] = (counts[key] ?? 0) + 1;
  }
  var topCount = 0;
  for (final count in counts.values) {
    topCount = math.max(topCount, count);
  }
  final dominanceScore = normalizedAmounts.isEmpty
      ? 0.0
      : topCount / normalizedAmounts.length;
  final sampleScore = _clamp01(normalizedAmounts.length / 4);
  final feedbackScore = feedback?.smoothedAcceptanceRate ?? 0.65;

  if (variationScore >= 0.74) {
    return _ValuePrediction<double>(
      value: normalizedMedian,
      confidence: _clamp01(
        (variationScore * 0.45) +
            (dominanceScore * 0.20) +
            (sampleScore * 0.20) +
            (feedbackScore * 0.15),
      ),
      reason: 'typical',
    );
  }

  final fallbackValue = fallbackAmount ?? normalizedMedian;
  return _ValuePrediction<double>(
    value: fallbackValue,
    confidence: _clamp01(
      (feedbackScore * 0.25) +
          (sampleScore * 0.20) +
          (dominanceScore * 0.15) +
          ((fallbackAmount != null ? 0.85 : 0.55) * 0.40),
    ),
    reason: 'last used',
  );
}

_ValuePrediction<int> _resolveDueDaysSuggestion({
  required Map<int, int> counts,
  required Map<int, DateTime> lastUsedByValue,
  required int fallbackValue,
  required PredictionFeedback? feedback,
  required int defaultValue,
}) {
  if (counts.isEmpty) {
    return _ValuePrediction<int>(
      value: fallbackValue > 0 ? fallbackValue : defaultValue,
      confidence: feedback?.smoothedAcceptanceRate ?? 0.40,
      reason: fallbackValue > 0 ? 'last used' : 'default',
    );
  }

  int? topValue;
  var topCount = -1;
  var secondCount = -1;
  for (final entry in counts.entries) {
    if (entry.value > topCount) {
      secondCount = topCount;
      topCount = entry.value;
      topValue = entry.key;
    } else if (entry.value > secondCount) {
      secondCount = entry.value;
    }
  }

  final totalCount = counts.values.fold<int>(0, (sum, value) => sum + value);
  final frequencyScore = totalCount <= 0 ? 0.0 : topCount / totalCount;
  final marginScore = topCount <= 0
      ? 0.0
      : _clamp01((topCount - math.max(secondCount, 0)) / topCount);
  final recencyScore = _recencyScore(
    topValue == null ? null : lastUsedByValue[topValue],
    DateTime.now(),
    decayDays: 28,
  );
  final feedbackScore = feedback?.smoothedAcceptanceRate ?? 0.65;
  final confidence = _clamp01(
    (frequencyScore * 0.45) +
        (marginScore * 0.20) +
        (recencyScore * 0.20) +
        (feedbackScore * 0.15),
  );

  return _ValuePrediction<int>(
    value: topValue ?? fallbackValue,
    confidence: confidence,
    reason: confidence >= 0.70 ? 'preferred' : 'last used',
  );
}

double _timeMatchScore({
  required Map<int, int> weekdayCounts,
  required Map<_TimeBucket, int> timeBucketCounts,
  required int totalCount,
  required _PredictionContext context,
}) {
  if (totalCount <= 0) {
    return 0.0;
  }

  final weekdayScore = (weekdayCounts[context.weekday] ?? 0) / totalCount;
  final timeBucketScore =
      (timeBucketCounts[context.timeBucket] ?? 0) / totalCount;
  return _clamp01((weekdayScore * 0.60) + (timeBucketScore * 0.40));
}

double _confidenceFromScores(
  double topScore,
  double? nextScore,
  int sampleCount,
  double feedbackScore,
) {
  final marginScore = nextScore == null || topScore <= 0
      ? 1.0
      : _clamp01((topScore - nextScore) / topScore);
  final sampleScore = _clamp01(sampleCount / 4);

  return _clamp01(
    (topScore * 0.55) +
        (marginScore * 0.25) +
        (sampleScore * 0.10) +
        (feedbackScore * 0.10),
  );
}

double _recencyScore(
  DateTime? timestamp,
  DateTime now, {
  required int decayDays,
}) {
  if (timestamp == null) {
    return 0.0;
  }

  final ageInDays = now.difference(timestamp).inHours / 24;
  if (ageInDays <= 0) {
    return 1.0;
  }

  return 1 / (1 + (ageInDays / decayDays));
}

double _recentActivityConfidence(DateTime? timestamp, DateTime now) {
  if (timestamp == null) {
    return 0.0;
  }

  final age = now.difference(timestamp);
  if (age <= const Duration(days: 1)) {
    return 1.0;
  }
  if (age <= const Duration(days: 3)) {
    return 0.92;
  }
  if (age <= const Duration(days: 7)) {
    return 0.72;
  }
  if (age <= const Duration(days: 14)) {
    return 0.48;
  }
  if (age <= const Duration(days: 30)) {
    return 0.28;
  }
  return 0.10;
}

double _composeConfidence({
  required PredictionModelWeights weights,
  required double clientConfidence,
  required double serviceConfidence,
  required double amountConfidence,
  required double dueDateConfidence,
  required double recencyConfidence,
  required double adjustment,
}) {
  return _clamp01(
    (clientConfidence * weights.clientWeight) +
        (serviceConfidence * weights.serviceWeight) +
        (amountConfidence * weights.amountWeight) +
        (dueDateConfidence * weights.dueDateWeight) +
        (recencyConfidence * weights.recencyWeight) +
        adjustment,
  );
}

double _clamp01(double value) {
  return value.clamp(0.0, 1.0).toDouble();
}

int _confidencePercent(double value) => (_clamp01(value) * 100).round();

_TimeBucket _timeBucketFor(DateTime dateTime) {
  final hour = dateTime.hour;
  if (hour >= 5 && hour < 12) {
    return _TimeBucket.morning;
  }
  if (hour >= 12 && hour < 17) {
    return _TimeBucket.afternoon;
  }
  if (hour >= 17 && hour < 22) {
    return _TimeBucket.evening;
  }
  return _TimeBucket.night;
}

void _incrementIntMap(Map<int, int> counts, int key) {
  counts[key] = (counts[key] ?? 0) + 1;
}

void _incrementTimeBucketMap(Map<_TimeBucket, int> counts, _TimeBucket key) {
  counts[key] = (counts[key] ?? 0) + 1;
}

Map<int, int> _parseIntCounts(Map<String, int> source) {
  final parsed = <int, int>{};
  for (final entry in source.entries) {
    final value = int.tryParse(entry.key);
    if (value != null) {
      parsed[value] = entry.value;
    }
  }
  return parsed;
}

Map<int, int> _singleValueCount(int? value) {
  if (value == null || value <= 0) {
    return const <int, int>{};
  }
  return <int, int>{value: 1};
}

List<double> _expandAmountCounts(Map<String, int> counts) {
  final values = <double>[];
  for (final entry in counts.entries) {
    final amount = double.tryParse(entry.key);
    if (amount == null) {
      continue;
    }
    for (var index = 0; index < entry.value; index++) {
      values.add(amount);
    }
  }
  return values;
}

double _median(List<double> values) {
  if (values.isEmpty) {
    return 0.0;
  }

  final items = List<double>.from(values);
  final middle = items.length ~/ 2;
  if (items.length.isOdd) {
    return _quickSelect(items, middle);
  }

  final lower = _quickSelect(List<double>.from(items), middle - 1);
  final upper = _quickSelect(items, middle);
  return (lower + upper) / 2;
}

double _quickSelect(List<double> items, int k) {
  var left = 0;
  var right = items.length - 1;

  while (true) {
    if (left == right) {
      return items[left];
    }

    final pivotIndex = _partition(
      items,
      left,
      right,
      left + ((right - left) ~/ 2),
    );

    if (k == pivotIndex) {
      return items[k];
    }
    if (k < pivotIndex) {
      right = pivotIndex - 1;
    } else {
      left = pivotIndex + 1;
    }
  }
}

int _partition(List<double> items, int left, int right, int pivotIndex) {
  final pivotValue = items[pivotIndex];
  _swap(items, pivotIndex, right);
  var storeIndex = left;

  for (var index = left; index < right; index++) {
    if (items[index] < pivotValue) {
      _swap(items, storeIndex, index);
      storeIndex += 1;
    }
  }

  _swap(items, right, storeIndex);
  return storeIndex;
}

void _swap(List<double> items, int left, int right) {
  if (left == right) {
    return;
  }

  final temporary = items[left];
  items[left] = items[right];
  items[right] = temporary;
}

int? _positiveDueDays(DateTime createdAt, DateTime dueDate) {
  final createdDate = DateTime(createdAt.year, createdAt.month, createdAt.day);
  final dueDateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);
  final difference = dueDateOnly.difference(createdDate).inDays;
  if (difference <= 0) {
    return null;
  }
  return difference;
}

String _normalizedText(String value) => value.trim().toLowerCase();

String _serviceFeedbackKey(String clientId, String service) {
  return '$clientId|${_normalizedText(service)}';
}

String _amountFeedbackKey(String clientId, String service, double amount) {
  return '$clientId|${_normalizedText(service)}|${amount.toStringAsFixed(2)}';
}

String _dueDaysFeedbackKey(String clientId, int dueDays) {
  return '$clientId|$dueDays';
}
