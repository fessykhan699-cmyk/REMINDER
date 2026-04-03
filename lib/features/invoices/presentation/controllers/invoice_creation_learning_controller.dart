import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../clients/domain/entities/client.dart';
import '../../domain/entities/invoice.dart';

final invoiceCreationLearningProvider =
    NotifierProvider<
      InvoiceCreationLearningController,
      InvoiceCreationLearningState
    >(InvoiceCreationLearningController.new);

class InvoiceCreationLearningState {
  const InvoiceCreationLearningState({
    required this.lastClientId,
    required this.dueDaysUsageCounts,
    required this.amountUsageCounts,
    required this.clientMemories,
    required this.clientPredictionFeedback,
    required this.servicePredictionFeedback,
    required this.amountPredictionFeedback,
    required this.dueDaysPredictionFeedback,
    required this.lastViewedClientId,
    required this.lastViewedClientAt,
    required this.predictionWeights,
    required this.predictionHistory,
    required this.openDetailAfterQuickCreate,
  });

  const InvoiceCreationLearningState.initial()
    : lastClientId = null,
      dueDaysUsageCounts = const {},
      amountUsageCounts = const {},
      clientMemories = const {},
      clientPredictionFeedback = const {},
      servicePredictionFeedback = const {},
      amountPredictionFeedback = const {},
      dueDaysPredictionFeedback = const {},
      lastViewedClientId = null,
      lastViewedClientAt = null,
      predictionWeights = const PredictionModelWeights.initial(),
      predictionHistory = const [],
      openDetailAfterQuickCreate = false;

  final String? lastClientId;
  final Map<String, int> dueDaysUsageCounts;
  final Map<String, int> amountUsageCounts;
  final Map<String, InvoiceCreationClientMemory> clientMemories;
  final Map<String, PredictionFeedback> clientPredictionFeedback;
  final Map<String, PredictionFeedback> servicePredictionFeedback;
  final Map<String, PredictionFeedback> amountPredictionFeedback;
  final Map<String, PredictionFeedback> dueDaysPredictionFeedback;
  final String? lastViewedClientId;
  final DateTime? lastViewedClientAt;
  final PredictionModelWeights predictionWeights;
  final List<PredictionResult> predictionHistory;
  final bool openDetailAfterQuickCreate;

  List<PredictionResult> get recentPredictionHistory {
    if (predictionHistory.isEmpty) {
      return const <PredictionResult>[];
    }

    final startIndex = predictionHistory.length > 10
        ? predictionHistory.length - 10
        : 0;
    return predictionHistory.sublist(startIndex);
  }

  double get recentAccuracyAverage {
    final recentPredictiveHistory = recentPredictionHistory
        .where((result) => result.hasAnyPrediction)
        .toList(growable: false);
    if (recentPredictiveHistory.isEmpty) {
      return 0.0;
    }

    final total = recentPredictiveHistory.fold<double>(
      0.0,
      (sum, result) => sum + result.accuracyScore,
    );
    return total / recentPredictiveHistory.length;
  }

  int get consecutiveWrongPredictions {
    var count = 0;
    for (final result in predictionHistory.reversed) {
      if (!result.hasAnyPrediction) {
        continue;
      }
      if (result.accuracyScore >= 0.50) {
        break;
      }
      count += 1;
    }
    return count;
  }

  bool get isOneTapTemporarilyDisabled => consecutiveWrongPredictions >= 3;

  double get confidenceAdjustment {
    if (!predictionHistory.any((result) => result.hasAnyPrediction)) {
      return 0.0;
    }

    if (recentAccuracyAverage >= 0.80) {
      return 0.04;
    }
    if (recentAccuracyAverage < 0.50) {
      return -0.06;
    }
    return 0.0;
  }

  InvoiceCreationLearningState copyWith({
    String? lastClientId,
    bool clearLastClientId = false,
    Map<String, int>? dueDaysUsageCounts,
    Map<String, int>? amountUsageCounts,
    Map<String, InvoiceCreationClientMemory>? clientMemories,
    Map<String, PredictionFeedback>? clientPredictionFeedback,
    Map<String, PredictionFeedback>? servicePredictionFeedback,
    Map<String, PredictionFeedback>? amountPredictionFeedback,
    Map<String, PredictionFeedback>? dueDaysPredictionFeedback,
    String? lastViewedClientId,
    bool clearLastViewedClientId = false,
    DateTime? lastViewedClientAt,
    bool clearLastViewedClientAt = false,
    PredictionModelWeights? predictionWeights,
    List<PredictionResult>? predictionHistory,
    bool? openDetailAfterQuickCreate,
  }) {
    return InvoiceCreationLearningState(
      lastClientId: clearLastClientId
          ? null
          : (lastClientId ?? this.lastClientId),
      dueDaysUsageCounts: dueDaysUsageCounts ?? this.dueDaysUsageCounts,
      amountUsageCounts: amountUsageCounts ?? this.amountUsageCounts,
      clientMemories: clientMemories ?? this.clientMemories,
      clientPredictionFeedback:
          clientPredictionFeedback ?? this.clientPredictionFeedback,
      servicePredictionFeedback:
          servicePredictionFeedback ?? this.servicePredictionFeedback,
      amountPredictionFeedback:
          amountPredictionFeedback ?? this.amountPredictionFeedback,
      dueDaysPredictionFeedback:
          dueDaysPredictionFeedback ?? this.dueDaysPredictionFeedback,
      lastViewedClientId: clearLastViewedClientId
          ? null
          : (lastViewedClientId ?? this.lastViewedClientId),
      lastViewedClientAt: clearLastViewedClientAt
          ? null
          : (lastViewedClientAt ?? this.lastViewedClientAt),
      predictionWeights: predictionWeights ?? this.predictionWeights,
      predictionHistory: predictionHistory ?? this.predictionHistory,
      openDetailAfterQuickCreate:
          openDetailAfterQuickCreate ?? this.openDetailAfterQuickCreate,
    );
  }

  factory InvoiceCreationLearningState.fromJson(Map<String, dynamic> json) {
    return InvoiceCreationLearningState(
      lastClientId: json['lastClientId'] as String?,
      dueDaysUsageCounts: _toIntMap(json['dueDaysUsageCounts']),
      amountUsageCounts: _toIntMap(json['amountUsageCounts']),
      clientMemories: _toClientMemoryMap(json['clientMemories']),
      clientPredictionFeedback: _toFeedbackMap(
        json['clientPredictionFeedback'],
      ),
      servicePredictionFeedback: _toFeedbackMap(
        json['servicePredictionFeedback'],
      ),
      amountPredictionFeedback: _toFeedbackMap(
        json['amountPredictionFeedback'],
      ),
      dueDaysPredictionFeedback: _toFeedbackMap(
        json['dueDaysPredictionFeedback'],
      ),
      lastViewedClientId: json['lastViewedClientId'] as String?,
      lastViewedClientAt: _parseDateTime(json['lastViewedClientAt'] as String?),
      predictionWeights: _toPredictionWeights(json['predictionWeights']),
      predictionHistory: _toPredictionHistory(json['predictionHistory']),
      openDetailAfterQuickCreate:
          json['openDetailAfterQuickCreate'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lastClientId': lastClientId,
      'dueDaysUsageCounts': dueDaysUsageCounts,
      'amountUsageCounts': amountUsageCounts,
      'clientMemories': clientMemories.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'clientPredictionFeedback': clientPredictionFeedback.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'servicePredictionFeedback': servicePredictionFeedback.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'amountPredictionFeedback': amountPredictionFeedback.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'dueDaysPredictionFeedback': dueDaysPredictionFeedback.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'lastViewedClientId': lastViewedClientId,
      'lastViewedClientAt': lastViewedClientAt?.toIso8601String(),
      'predictionWeights': predictionWeights.toJson(),
      'predictionHistory': predictionHistory
          .map((result) => result.toJson())
          .toList(growable: false),
      'openDetailAfterQuickCreate': openDetailAfterQuickCreate,
    };
  }

  static Map<String, int> _toIntMap(Object? raw) {
    if (raw is! Map) {
      return const {};
    }

    final output = <String, int>{};
    for (final entry in raw.entries) {
      if (entry.key is String && entry.value is num) {
        output[entry.key as String] = (entry.value as num).toInt();
      }
    }
    return output;
  }

  static Map<String, InvoiceCreationClientMemory> _toClientMemoryMap(
    Object? raw,
  ) {
    if (raw is! Map) {
      return const {};
    }

    final output = <String, InvoiceCreationClientMemory>{};
    for (final entry in raw.entries) {
      if (entry.key is String && entry.value is Map<String, dynamic>) {
        output[entry.key as String] = InvoiceCreationClientMemory.fromJson(
          entry.value as Map<String, dynamic>,
        );
      } else if (entry.key is String && entry.value is Map) {
        output[entry.key as String] = InvoiceCreationClientMemory.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        );
      }
    }
    return output;
  }

  static Map<String, PredictionFeedback> _toFeedbackMap(Object? raw) {
    if (raw is! Map) {
      return const {};
    }

    final output = <String, PredictionFeedback>{};
    for (final entry in raw.entries) {
      if (entry.key is String && entry.value is Map<String, dynamic>) {
        output[entry.key as String] = PredictionFeedback.fromJson(
          entry.value as Map<String, dynamic>,
        );
      } else if (entry.key is String && entry.value is Map) {
        output[entry.key as String] = PredictionFeedback.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        );
      }
    }
    return output;
  }

  static PredictionModelWeights _toPredictionWeights(Object? raw) {
    if (raw is Map<String, dynamic>) {
      return PredictionModelWeights.fromJson(raw);
    }
    if (raw is Map) {
      return PredictionModelWeights.fromJson(Map<String, dynamic>.from(raw));
    }
    return const PredictionModelWeights.initial();
  }

  static List<PredictionResult> _toPredictionHistory(Object? raw) {
    if (raw is! List) {
      return const <PredictionResult>[];
    }

    final output = <PredictionResult>[];
    for (final item in raw) {
      if (item is Map<String, dynamic>) {
        output.add(PredictionResult.fromJson(item));
      } else if (item is Map) {
        output.add(PredictionResult.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    return output;
  }
}

class PredictionFeedback {
  const PredictionFeedback({
    required this.acceptedCount,
    required this.editedCount,
    required this.lastUpdatedAt,
  });

  const PredictionFeedback.initial()
    : acceptedCount = 0,
      editedCount = 0,
      lastUpdatedAt = null;

  final int acceptedCount;
  final int editedCount;
  final DateTime? lastUpdatedAt;

  double get smoothedAcceptanceRate {
    final accepted = acceptedCount + 2.6;
    final edited = editedCount + 1.4;
    return accepted / (accepted + edited);
  }

  PredictionFeedback record({required bool accepted, required DateTime at}) {
    return PredictionFeedback(
      acceptedCount: acceptedCount + (accepted ? 1 : 0),
      editedCount: editedCount + (accepted ? 0 : 1),
      lastUpdatedAt: at,
    );
  }

  factory PredictionFeedback.fromJson(Map<String, dynamic> json) {
    return PredictionFeedback(
      acceptedCount: (json['acceptedCount'] as num?)?.toInt() ?? 0,
      editedCount: (json['editedCount'] as num?)?.toInt() ?? 0,
      lastUpdatedAt: _parseDateTime(json['lastUpdatedAt'] as String?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'acceptedCount': acceptedCount,
      'editedCount': editedCount,
      'lastUpdatedAt': lastUpdatedAt?.toIso8601String(),
    };
  }
}

class PredictionModelWeights {
  const PredictionModelWeights({
    required this.clientWeight,
    required this.serviceWeight,
    required this.amountWeight,
    required this.dueDateWeight,
    required this.recencyWeight,
  });

  const PredictionModelWeights.initial()
    : clientWeight = 0.30,
      serviceWeight = 0.20,
      amountWeight = 0.25,
      dueDateWeight = 0.15,
      recencyWeight = 0.10;

  final double clientWeight;
  final double serviceWeight;
  final double amountWeight;
  final double dueDateWeight;
  final double recencyWeight;

  PredictionModelWeights copyWith({
    double? clientWeight,
    double? serviceWeight,
    double? amountWeight,
    double? dueDateWeight,
    double? recencyWeight,
  }) {
    return PredictionModelWeights(
      clientWeight: clientWeight ?? this.clientWeight,
      serviceWeight: serviceWeight ?? this.serviceWeight,
      amountWeight: amountWeight ?? this.amountWeight,
      dueDateWeight: dueDateWeight ?? this.dueDateWeight,
      recencyWeight: recencyWeight ?? this.recencyWeight,
    );
  }

  PredictionModelWeights normalized() {
    const fixedRecencyWeight = 0.10;
    final nextClientWeight = clientWeight.clamp(0.06, 0.70).toDouble();
    final nextServiceWeight = serviceWeight.clamp(0.06, 0.70).toDouble();
    final nextAmountWeight = amountWeight.clamp(0.06, 0.70).toDouble();
    final nextDueDateWeight = dueDateWeight.clamp(0.06, 0.70).toDouble();
    final tunableWeightTotal =
        nextClientWeight +
        nextServiceWeight +
        nextAmountWeight +
        nextDueDateWeight;

    if (tunableWeightTotal <= 0.0) {
      return const PredictionModelWeights.initial();
    }

    final scale = (1.0 - fixedRecencyWeight) / tunableWeightTotal;
    return PredictionModelWeights(
      clientWeight: nextClientWeight * scale,
      serviceWeight: nextServiceWeight * scale,
      amountWeight: nextAmountWeight * scale,
      dueDateWeight: nextDueDateWeight * scale,
      recencyWeight: fixedRecencyWeight,
    );
  }

  factory PredictionModelWeights.fromJson(Map<String, dynamic> json) {
    return PredictionModelWeights(
      clientWeight: (json['clientWeight'] as num?)?.toDouble() ?? 0.30,
      serviceWeight: (json['serviceWeight'] as num?)?.toDouble() ?? 0.20,
      amountWeight: (json['amountWeight'] as num?)?.toDouble() ?? 0.25,
      dueDateWeight: (json['dueDateWeight'] as num?)?.toDouble() ?? 0.15,
      recencyWeight: (json['recencyWeight'] as num?)?.toDouble() ?? 0.10,
    ).normalized();
  }

  Map<String, dynamic> toJson() {
    return {
      'clientWeight': clientWeight,
      'serviceWeight': serviceWeight,
      'amountWeight': amountWeight,
      'dueDateWeight': dueDateWeight,
      'recencyWeight': recencyWeight,
    };
  }
}

class PredictionResult {
  const PredictionResult({
    required this.predictedClientId,
    required this.predictedService,
    required this.predictedAmount,
    required this.predictedDueDate,
    required this.actualClientId,
    required this.actualService,
    required this.actualAmount,
    required this.actualDueDate,
    required this.clientAccuracy,
    required this.serviceAccuracy,
    required this.amountAccuracy,
    required this.dueDateAccuracy,
    required this.accuracyScore,
    required this.createdAt,
  });

  final String? predictedClientId;
  final String? predictedService;
  final double? predictedAmount;
  final DateTime? predictedDueDate;
  final String actualClientId;
  final String actualService;
  final double actualAmount;
  final DateTime actualDueDate;
  final double clientAccuracy;
  final double serviceAccuracy;
  final double amountAccuracy;
  final double dueDateAccuracy;
  final double accuracyScore;
  final DateTime createdAt;

  bool get hasAnyPrediction {
    return predictedClientId != null ||
        predictedService != null ||
        predictedAmount != null ||
        predictedDueDate != null;
  }

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    return PredictionResult(
      predictedClientId: json['predictedClientId'] as String?,
      predictedService: json['predictedService'] as String?,
      predictedAmount: (json['predictedAmount'] as num?)?.toDouble(),
      predictedDueDate: _parseDateTime(json['predictedDueDate'] as String?),
      actualClientId: json['actualClientId'] as String? ?? '',
      actualService: json['actualService'] as String? ?? '',
      actualAmount: (json['actualAmount'] as num?)?.toDouble() ?? 0.0,
      actualDueDate:
          _parseDateTime(json['actualDueDate'] as String?) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      clientAccuracy: (json['clientAccuracy'] as num?)?.toDouble() ?? 0.0,
      serviceAccuracy: (json['serviceAccuracy'] as num?)?.toDouble() ?? 0.0,
      amountAccuracy: (json['amountAccuracy'] as num?)?.toDouble() ?? 0.0,
      dueDateAccuracy: (json['dueDateAccuracy'] as num?)?.toDouble() ?? 0.0,
      accuracyScore: (json['accuracyScore'] as num?)?.toDouble() ?? 0.0,
      createdAt:
          _parseDateTime(json['createdAt'] as String?) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'predictedClientId': predictedClientId,
      'predictedService': predictedService,
      'predictedAmount': predictedAmount,
      'predictedDueDate': predictedDueDate?.toIso8601String(),
      'actualClientId': actualClientId,
      'actualService': actualService,
      'actualAmount': actualAmount,
      'actualDueDate': actualDueDate.toIso8601String(),
      'clientAccuracy': clientAccuracy,
      'serviceAccuracy': serviceAccuracy,
      'amountAccuracy': amountAccuracy,
      'dueDateAccuracy': dueDateAccuracy,
      'accuracyScore': accuracyScore,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class InvoiceCreationClientMemory {
  const InvoiceCreationClientMemory({
    required this.usageCount,
    required this.lastService,
    required this.lastAmount,
    required this.lastDueDays,
    required this.lastUsedAt,
    required this.serviceUsageCounts,
    required this.serviceAmountUsageCounts,
  });

  const InvoiceCreationClientMemory.initial()
    : usageCount = 0,
      lastService = null,
      lastAmount = null,
      lastDueDays = null,
      lastUsedAt = null,
      serviceUsageCounts = const {},
      serviceAmountUsageCounts = const {};

  final int usageCount;
  final String? lastService;
  final double? lastAmount;
  final int? lastDueDays;
  final DateTime? lastUsedAt;
  final Map<String, int> serviceUsageCounts;
  final Map<String, Map<String, int>> serviceAmountUsageCounts;

  InvoiceCreationClientMemory copyWith({
    int? usageCount,
    String? lastService,
    bool clearLastService = false,
    double? lastAmount,
    bool clearLastAmount = false,
    int? lastDueDays,
    bool clearLastDueDays = false,
    DateTime? lastUsedAt,
    bool clearLastUsedAt = false,
    Map<String, int>? serviceUsageCounts,
    Map<String, Map<String, int>>? serviceAmountUsageCounts,
  }) {
    return InvoiceCreationClientMemory(
      usageCount: usageCount ?? this.usageCount,
      lastService: clearLastService ? null : (lastService ?? this.lastService),
      lastAmount: clearLastAmount ? null : (lastAmount ?? this.lastAmount),
      lastDueDays: clearLastDueDays ? null : (lastDueDays ?? this.lastDueDays),
      lastUsedAt: clearLastUsedAt ? null : (lastUsedAt ?? this.lastUsedAt),
      serviceUsageCounts: serviceUsageCounts ?? this.serviceUsageCounts,
      serviceAmountUsageCounts:
          serviceAmountUsageCounts ?? this.serviceAmountUsageCounts,
    );
  }

  factory InvoiceCreationClientMemory.fromJson(Map<String, dynamic> json) {
    return InvoiceCreationClientMemory(
      usageCount: (json['usageCount'] as num?)?.toInt() ?? 0,
      lastService: json['lastService'] as String?,
      lastAmount: (json['lastAmount'] as num?)?.toDouble(),
      lastDueDays: (json['lastDueDays'] as num?)?.toInt(),
      lastUsedAt: _parseDateTime(json['lastUsedAt'] as String?),
      serviceUsageCounts: _toIntMap(json['serviceUsageCounts']),
      serviceAmountUsageCounts: _toNestedIntMap(
        json['serviceAmountUsageCounts'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'usageCount': usageCount,
      'lastService': lastService,
      'lastAmount': lastAmount,
      'lastDueDays': lastDueDays,
      'lastUsedAt': lastUsedAt?.toIso8601String(),
      'serviceUsageCounts': serviceUsageCounts,
      'serviceAmountUsageCounts': serviceAmountUsageCounts,
    };
  }

  static Map<String, int> _toIntMap(Object? raw) {
    if (raw is! Map) {
      return const {};
    }

    final output = <String, int>{};
    for (final entry in raw.entries) {
      if (entry.key is String && entry.value is num) {
        output[entry.key as String] = (entry.value as num).toInt();
      }
    }
    return output;
  }

  static Map<String, Map<String, int>> _toNestedIntMap(Object? raw) {
    if (raw is! Map) {
      return const {};
    }

    final output = <String, Map<String, int>>{};
    for (final entry in raw.entries) {
      if (entry.key is! String || entry.value is! Map) {
        continue;
      }

      final nested = <String, int>{};
      for (final nestedEntry in (entry.value as Map).entries) {
        if (nestedEntry.key is String && nestedEntry.value is num) {
          nested[nestedEntry.key as String] = (nestedEntry.value as num)
              .toInt();
        }
      }

      output[entry.key as String] = nested;
    }
    return output;
  }
}

class InvoiceCreationLearningController
    extends Notifier<InvoiceCreationLearningState> {
  static const _storageKey = 'invoice_creation_learning_v1';
  static const _maxPredictionHistory = 30;
  static const _rollingWindowSize = 10;
  static const _weightAdjustmentStep = 0.02;

  Future<void>? _bootstrapFuture;

  @override
  InvoiceCreationLearningState build() {
    Future<void>(_ensureBootstrapped);
    return const InvoiceCreationLearningState.initial();
  }

  Future<void> _ensureBootstrapped() {
    return _bootstrapFuture ??= _bootstrap();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final rawState = prefs.getString(_storageKey);
    if (rawState == null || rawState.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(rawState);
      if (decoded is Map<String, dynamic>) {
        state = InvoiceCreationLearningState.fromJson(decoded);
      } else if (decoded is Map) {
        state = InvoiceCreationLearningState.fromJson(
          Map<String, dynamic>.from(decoded),
        );
      }
    } catch (_) {
      state = const InvoiceCreationLearningState.initial();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(state.toJson()));
  }

  Future<void> recordCreatedInvoice(Invoice invoice) async {
    await _ensureBootstrapped();

    final dueDays = _positiveDueDays(invoice.createdAt, invoice.dueDate);
    final amountKey = _amountKey(invoice.amount);
    final service = invoice.service.trim();

    final updatedDueDayCounts = Map<String, int>.from(state.dueDaysUsageCounts);
    if (dueDays != null) {
      final dueDaysKey = dueDays.toString();
      updatedDueDayCounts[dueDaysKey] =
          (updatedDueDayCounts[dueDaysKey] ?? 0) + 1;
    }

    final updatedAmountCounts = Map<String, int>.from(state.amountUsageCounts);
    updatedAmountCounts[amountKey] = (updatedAmountCounts[amountKey] ?? 0) + 1;

    final updatedClientMemories = Map<String, InvoiceCreationClientMemory>.from(
      state.clientMemories,
    );
    final previousMemory =
        updatedClientMemories[invoice.clientId] ??
        const InvoiceCreationClientMemory.initial();

    final updatedServiceUsageCounts = Map<String, int>.from(
      previousMemory.serviceUsageCounts,
    );
    final updatedServiceAmountUsageCounts = _cloneNestedIntMap(
      previousMemory.serviceAmountUsageCounts,
    );

    if (service.isNotEmpty) {
      updatedServiceUsageCounts[service] =
          (updatedServiceUsageCounts[service] ?? 0) + 1;

      final serviceAmountCounts = Map<String, int>.from(
        updatedServiceAmountUsageCounts[service] ?? const <String, int>{},
      );
      serviceAmountCounts[amountKey] =
          (serviceAmountCounts[amountKey] ?? 0) + 1;
      updatedServiceAmountUsageCounts[service] = serviceAmountCounts;
    }

    updatedClientMemories[invoice.clientId] = previousMemory.copyWith(
      usageCount: previousMemory.usageCount + 1,
      lastService: service.isEmpty ? previousMemory.lastService : service,
      lastAmount: invoice.amount,
      lastDueDays: dueDays,
      lastUsedAt: invoice.createdAt,
      serviceUsageCounts: updatedServiceUsageCounts,
      serviceAmountUsageCounts: updatedServiceAmountUsageCounts,
    );

    state = state.copyWith(
      lastClientId: invoice.clientId,
      dueDaysUsageCounts: updatedDueDayCounts,
      amountUsageCounts: updatedAmountCounts,
      clientMemories: updatedClientMemories,
    );
    await _persist();
  }

  Future<void> recordViewedClient(String clientId) async {
    if (clientId.isEmpty) {
      return;
    }

    await _ensureBootstrapped();
    final now = DateTime.now();
    final lastViewedClientAt = state.lastViewedClientAt;

    if (state.lastViewedClientId == clientId &&
        lastViewedClientAt != null &&
        now.difference(lastViewedClientAt) < const Duration(minutes: 2)) {
      return;
    }

    state = state.copyWith(
      lastViewedClientId: clientId,
      lastViewedClientAt: now,
    );
    await _persist();
  }

  Future<void> recordPredictionOutcome({
    required String? predictedClientId,
    required String? predictedService,
    required double? predictedAmount,
    required DateTime? predictedDueDate,
    required Invoice actualInvoice,
  }) async {
    await _ensureBootstrapped();
    final now = DateTime.now();

    final clientFeedback = Map<String, PredictionFeedback>.from(
      state.clientPredictionFeedback,
    );
    final serviceFeedback = Map<String, PredictionFeedback>.from(
      state.servicePredictionFeedback,
    );
    final amountFeedback = Map<String, PredictionFeedback>.from(
      state.amountPredictionFeedback,
    );
    final dueDaysFeedback = Map<String, PredictionFeedback>.from(
      state.dueDaysPredictionFeedback,
    );
    final previousWeights = state.predictionWeights;

    final clientAccepted =
        predictedClientId != null &&
        predictedClientId == actualInvoice.clientId;
    final serviceAccepted =
        predictedService != null &&
        _normalizedText(predictedService) ==
            _normalizedText(actualInvoice.service);
    final amountAccepted =
        predictedAmount != null &&
        _amountWithinTolerance(predictedAmount, actualInvoice.amount);
    final dueDateAccepted =
        predictedDueDate != null &&
        _sameCalendarDay(predictedDueDate, actualInvoice.dueDate);

    if (predictedClientId != null && predictedClientId.isNotEmpty) {
      clientFeedback[predictedClientId] =
          (clientFeedback[predictedClientId] ??
                  const PredictionFeedback.initial())
              .record(accepted: clientAccepted, at: now);
    }

    if (predictedService != null && predictedService.isNotEmpty) {
      final serviceKey = _serviceFeedbackKey(
        actualInvoice.clientId,
        predictedService,
      );

      serviceFeedback[serviceKey] =
          (serviceFeedback[serviceKey] ?? const PredictionFeedback.initial())
              .record(accepted: serviceAccepted, at: now);
    }

    if (predictedAmount != null) {
      final amountKey = _amountFeedbackKey(
        actualInvoice.clientId,
        predictedService,
        predictedAmount,
      );
      amountFeedback[amountKey] =
          (amountFeedback[amountKey] ?? const PredictionFeedback.initial())
              .record(accepted: amountAccepted, at: now);
    }

    if (predictedDueDate != null) {
      final predictedDueDays = _positiveDueDays(
        actualInvoice.createdAt,
        predictedDueDate,
      );
      if (predictedDueDays != null) {
        final dueFeedbackKey = _dueDaysFeedbackKey(
          actualInvoice.clientId,
          predictedDueDays,
        );
        dueDaysFeedback[dueFeedbackKey] =
            (dueDaysFeedback[dueFeedbackKey] ??
                    const PredictionFeedback.initial())
                .record(accepted: dueDateAccepted, at: now);
      }
    }

    final predictionResult = PredictionResult(
      predictedClientId: predictedClientId,
      predictedService: predictedService,
      predictedAmount: predictedAmount,
      predictedDueDate: predictedDueDate,
      actualClientId: actualInvoice.clientId,
      actualService: actualInvoice.service,
      actualAmount: actualInvoice.amount,
      actualDueDate: actualInvoice.dueDate,
      clientAccuracy: clientAccepted ? 1.0 : 0.0,
      serviceAccuracy: serviceAccepted ? 1.0 : 0.0,
      amountAccuracy: amountAccepted ? 1.0 : 0.0,
      dueDateAccuracy: dueDateAccepted ? 1.0 : 0.0,
      accuracyScore:
          ((clientAccepted ? 1.0 : 0.0) * 0.30) +
          ((serviceAccepted ? 1.0 : 0.0) * 0.20) +
          ((amountAccepted ? 1.0 : 0.0) * 0.30) +
          ((dueDateAccepted ? 1.0 : 0.0) * 0.20),
      createdAt: now,
    );

    final updatedPredictionHistory = predictionResult.hasAnyPrediction
        ? _appendPredictionResult(state.predictionHistory, predictionResult)
        : state.predictionHistory;
    final updatedPredictionWeights = predictionResult.hasAnyPrediction
        ? _autoTuneWeights(state.predictionWeights, updatedPredictionHistory)
        : state.predictionWeights;

    assert(() {
      if (predictionResult.hasAnyPrediction) {
        debugPrint(
          'Prediction Accuracy: ${(predictionResult.accuracyScore * 100).round()}%',
        );
        final weightSummary = _weightDeltaSummary(
          previousWeights,
          updatedPredictionWeights,
        );
        if (weightSummary != null) {
          debugPrint('Weights updated: $weightSummary');
        }
        if (_trailingWrongPredictionCount(updatedPredictionHistory) >= 3) {
          debugPrint(
            'One-tap invoice temporarily disabled after repeated wrong predictions.',
          );
        }
      }
      return true;
    }());

    state = state.copyWith(
      clientPredictionFeedback: clientFeedback,
      servicePredictionFeedback: serviceFeedback,
      amountPredictionFeedback: amountFeedback,
      dueDaysPredictionFeedback: dueDaysFeedback,
      predictionWeights: updatedPredictionWeights,
      predictionHistory: updatedPredictionHistory,
    );
    await _persist();
  }

  Future<void> rebuildFromInvoices(List<Invoice> invoices) async {
    await _ensureBootstrapped();

    final derivedState = _deriveStateFromInvoices(
      invoices,
      lastViewedClientId: state.lastViewedClientId,
      lastViewedClientAt: state.lastViewedClientAt,
      clientPredictionFeedback: state.clientPredictionFeedback,
      servicePredictionFeedback: state.servicePredictionFeedback,
      amountPredictionFeedback: state.amountPredictionFeedback,
      dueDaysPredictionFeedback: state.dueDaysPredictionFeedback,
      predictionWeights: state.predictionWeights,
      predictionHistory: state.predictionHistory,
      openDetailAfterQuickCreate: state.openDetailAfterQuickCreate,
    );
    state = derivedState;
    await _persist();
  }

  Future<void> setOpenDetailAfterQuickCreate(bool value) async {
    await _ensureBootstrapped();
    if (state.openDetailAfterQuickCreate == value) {
      return;
    }

    state = state.copyWith(openDetailAfterQuickCreate: value);
    await _persist();
  }

  static InvoiceCreationLearningState _deriveStateFromInvoices(
    List<Invoice> invoices, {
    required String? lastViewedClientId,
    required DateTime? lastViewedClientAt,
    required Map<String, PredictionFeedback> clientPredictionFeedback,
    required Map<String, PredictionFeedback> servicePredictionFeedback,
    required Map<String, PredictionFeedback> amountPredictionFeedback,
    required Map<String, PredictionFeedback> dueDaysPredictionFeedback,
    required PredictionModelWeights predictionWeights,
    required List<PredictionResult> predictionHistory,
    required bool openDetailAfterQuickCreate,
  }) {
    if (invoices.isEmpty) {
      return InvoiceCreationLearningState(
        lastClientId: null,
        dueDaysUsageCounts: const {},
        amountUsageCounts: const {},
        clientMemories: const {},
        clientPredictionFeedback: clientPredictionFeedback,
        servicePredictionFeedback: servicePredictionFeedback,
        amountPredictionFeedback: amountPredictionFeedback,
        dueDaysPredictionFeedback: dueDaysPredictionFeedback,
        lastViewedClientId: lastViewedClientId,
        lastViewedClientAt: lastViewedClientAt,
        predictionWeights: predictionWeights,
        predictionHistory: predictionHistory,
        openDetailAfterQuickCreate: openDetailAfterQuickCreate,
      );
    }

    final dueDayCounts = <String, int>{};
    final amountUsageCounts = <String, int>{};
    final clientMemories = <String, InvoiceCreationClientMemory>{};
    Invoice? latestInvoice;

    for (final invoice in invoices) {
      if (latestInvoice == null ||
          invoice.createdAt.isAfter(latestInvoice.createdAt)) {
        latestInvoice = invoice;
      }

      final dueDays = _positiveDueDays(invoice.createdAt, invoice.dueDate);
      if (dueDays != null) {
        final dueDaysKey = dueDays.toString();
        dueDayCounts[dueDaysKey] = (dueDayCounts[dueDaysKey] ?? 0) + 1;
      }

      final amountKey = _amountKey(invoice.amount);
      amountUsageCounts[amountKey] = (amountUsageCounts[amountKey] ?? 0) + 1;

      final service = invoice.service.trim();
      final previousMemory =
          clientMemories[invoice.clientId] ??
          const InvoiceCreationClientMemory.initial();
      final updatedServiceUsageCounts = Map<String, int>.from(
        previousMemory.serviceUsageCounts,
      );
      final updatedServiceAmountUsageCounts = _cloneNestedIntMap(
        previousMemory.serviceAmountUsageCounts,
      );

      if (service.isNotEmpty) {
        updatedServiceUsageCounts[service] =
            (updatedServiceUsageCounts[service] ?? 0) + 1;

        final serviceAmountCounts = Map<String, int>.from(
          updatedServiceAmountUsageCounts[service] ?? const <String, int>{},
        );
        serviceAmountCounts[amountKey] =
            (serviceAmountCounts[amountKey] ?? 0) + 1;
        updatedServiceAmountUsageCounts[service] = serviceAmountCounts;
      }

      final nextMemory = previousMemory.copyWith(
        usageCount: previousMemory.usageCount + 1,
        lastService: service.isEmpty ? previousMemory.lastService : service,
        lastAmount: invoice.amount,
        lastDueDays: dueDays,
        lastUsedAt: invoice.createdAt,
        serviceUsageCounts: updatedServiceUsageCounts,
        serviceAmountUsageCounts: updatedServiceAmountUsageCounts,
      );

      final currentMemory = clientMemories[invoice.clientId];
      if (currentMemory == null ||
          (nextMemory.lastUsedAt != null &&
              (currentMemory.lastUsedAt == null ||
                  nextMemory.lastUsedAt!.isAfter(currentMemory.lastUsedAt!)))) {
        clientMemories[invoice.clientId] = nextMemory;
      } else {
        clientMemories[invoice.clientId] = currentMemory.copyWith(
          usageCount: nextMemory.usageCount,
          serviceUsageCounts: nextMemory.serviceUsageCounts,
          serviceAmountUsageCounts: nextMemory.serviceAmountUsageCounts,
        );
      }
    }

    return InvoiceCreationLearningState(
      lastClientId: latestInvoice?.clientId,
      dueDaysUsageCounts: dueDayCounts,
      amountUsageCounts: amountUsageCounts,
      clientMemories: clientMemories,
      clientPredictionFeedback: clientPredictionFeedback,
      servicePredictionFeedback: servicePredictionFeedback,
      amountPredictionFeedback: amountPredictionFeedback,
      dueDaysPredictionFeedback: dueDaysPredictionFeedback,
      lastViewedClientId: lastViewedClientId,
      lastViewedClientAt: lastViewedClientAt,
      predictionWeights: predictionWeights,
      predictionHistory: predictionHistory,
      openDetailAfterQuickCreate: openDetailAfterQuickCreate,
    );
  }

  static List<PredictionResult> _appendPredictionResult(
    List<PredictionResult> history,
    PredictionResult result,
  ) {
    final nextHistory = List<PredictionResult>.from(history)..add(result);
    if (nextHistory.length <= _maxPredictionHistory) {
      return nextHistory;
    }
    return nextHistory.sublist(nextHistory.length - _maxPredictionHistory);
  }

  static PredictionModelWeights _autoTuneWeights(
    PredictionModelWeights currentWeights,
    List<PredictionResult> history,
  ) {
    if (history.isEmpty) {
      return currentWeights;
    }

    final recentHistory = history.length > _rollingWindowSize
        ? history.sublist(history.length - _rollingWindowSize)
        : history;

    final clientAccuracy = _averageFieldAccuracy(
      recentHistory,
      selector: (result) => result.clientAccuracy,
      includeResult: (result) => result.predictedClientId != null,
    );
    final serviceAccuracy = _averageFieldAccuracy(
      recentHistory,
      selector: (result) => result.serviceAccuracy,
      includeResult: (result) => result.predictedService != null,
    );
    final amountAccuracy = _averageFieldAccuracy(
      recentHistory,
      selector: (result) => result.amountAccuracy,
      includeResult: (result) => result.predictedAmount != null,
    );
    final dueDateAccuracy = _averageFieldAccuracy(
      recentHistory,
      selector: (result) => result.dueDateAccuracy,
      includeResult: (result) => result.predictedDueDate != null,
    );

    return currentWeights
        .copyWith(
          clientWeight: _tuneWeight(
            currentWeights.clientWeight,
            clientAccuracy,
          ),
          serviceWeight: _tuneWeight(
            currentWeights.serviceWeight,
            serviceAccuracy,
          ),
          amountWeight: _tuneWeight(
            currentWeights.amountWeight,
            amountAccuracy,
          ),
          dueDateWeight: _tuneWeight(
            currentWeights.dueDateWeight,
            dueDateAccuracy,
          ),
        )
        .normalized();
  }

  static double _averageFieldAccuracy(
    List<PredictionResult> results, {
    required double Function(PredictionResult result) selector,
    required bool Function(PredictionResult result) includeResult,
  }) {
    final matchingResults = results
        .where(includeResult)
        .toList(growable: false);
    if (matchingResults.isEmpty) {
      return -1.0;
    }

    final total = matchingResults.fold<double>(
      0.0,
      (sum, result) => sum + selector(result),
    );
    return total / matchingResults.length;
  }

  static double _tuneWeight(double currentWeight, double recentAccuracy) {
    if (recentAccuracy < 0.0) {
      return currentWeight;
    }
    if (recentAccuracy >= 0.80) {
      return currentWeight + _weightAdjustmentStep;
    }
    if (recentAccuracy <= 0.50) {
      return currentWeight - _weightAdjustmentStep;
    }
    return currentWeight;
  }

  static int _trailingWrongPredictionCount(List<PredictionResult> history) {
    var count = 0;
    for (final result in history.reversed) {
      if (!result.hasAnyPrediction) {
        continue;
      }
      if (result.accuracyScore >= 0.50) {
        break;
      }
      count += 1;
    }
    return count;
  }

  static String? _weightDeltaSummary(
    PredictionModelWeights previous,
    PredictionModelWeights next,
  ) {
    final changes = <String>[];

    void addChange(String label, double previousValue, double nextValue) {
      final delta = nextValue - previousValue;
      if (delta.abs() < 0.0001) {
        return;
      }
      final prefix = delta >= 0 ? '+' : '';
      changes.add('$label $prefix${delta.toStringAsFixed(2)}');
    }

    addChange('client', previous.clientWeight, next.clientWeight);
    addChange('service', previous.serviceWeight, next.serviceWeight);
    addChange('amount', previous.amountWeight, next.amountWeight);
    addChange('due', previous.dueDateWeight, next.dueDateWeight);

    if (changes.isEmpty) {
      return null;
    }
    return changes.join(', ');
  }

  static Map<String, Map<String, int>> _cloneNestedIntMap(
    Map<String, Map<String, int>> source,
  ) {
    final clone = <String, Map<String, int>>{};
    for (final entry in source.entries) {
      clone[entry.key] = Map<String, int>.from(entry.value);
    }
    return clone;
  }

  static String _serviceFeedbackKey(String clientId, String service) {
    return '$clientId|${_normalizedText(service)}';
  }

  static String _amountFeedbackKey(
    String clientId,
    String? service,
    double amount,
  ) {
    return '$clientId|${_normalizedText(service ?? '*')}|${_amountKey(amount)}';
  }

  static String _dueDaysFeedbackKey(String clientId, int dueDays) {
    return '$clientId|$dueDays';
  }
}

String _normalizedText(String value) => value.trim().toLowerCase();

bool _amountWithinTolerance(double predictedAmount, double actualAmount) {
  final baseline = actualAmount.abs() < 0.01 ? 0.01 : actualAmount.abs();
  final delta = (predictedAmount - actualAmount).abs();
  return (delta / baseline) <= 0.05;
}

bool _sameCalendarDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

class CreateInvoiceIntelligence {
  const CreateInvoiceIntelligence({
    required this.suggestedClient,
    required this.suggestedClientReason,
    required this.preferredDueDays,
    required this.quickAmount,
    required this.quickAmountReason,
    required this.firstAvailableClient,
    required Map<String, CreateInvoiceClientSuggestion> suggestionsByClient,
  }) : _suggestionsByClient = suggestionsByClient;

  final Client? suggestedClient;
  final String? suggestedClientReason;
  final int? preferredDueDays;
  final double? quickAmount;
  final String? quickAmountReason;
  final Client? firstAvailableClient;
  final Map<String, CreateInvoiceClientSuggestion> _suggestionsByClient;

  CreateInvoiceClientSuggestion? suggestionFor(String clientId) {
    return _suggestionsByClient[clientId];
  }

  factory CreateInvoiceIntelligence.fromData({
    required List<Invoice> invoices,
    required List<Client> clients,
    required InvoiceCreationLearningState learning,
  }) {
    final clientById = <String, Client>{
      for (final client in clients) client.id: client,
    };
    final suggestionsByClient = <String, CreateInvoiceClientSuggestion>{};

    Client? suggestedClient;
    String? suggestedClientReason;
    int? preferredDueDays;
    double? quickAmount;
    String? quickAmountReason;

    if (invoices.isNotEmpty) {
      final clientAggregates = <String, _ClientInvoiceAggregate>{};
      final dueDayCounts = <int, int>{};
      final amountCounts = <String, int>{};
      Invoice? latestInvoice;

      for (final invoice in invoices) {
        final aggregate = clientAggregates.putIfAbsent(
          invoice.clientId,
          _ClientInvoiceAggregate.new,
        );
        aggregate.add(invoice);

        if (latestInvoice == null ||
            invoice.createdAt.isAfter(latestInvoice.createdAt)) {
          latestInvoice = invoice;
        }

        final dueDays = _positiveDueDays(invoice.createdAt, invoice.dueDate);
        if (dueDays != null) {
          dueDayCounts[dueDays] = (dueDayCounts[dueDays] ?? 0) + 1;
        }

        final amountKey = _amountKey(invoice.amount);
        amountCounts[amountKey] = (amountCounts[amountKey] ?? 0) + 1;
      }

      preferredDueDays = _pickTopInt(
        dueDayCounts,
        fallbackValue: latestInvoice == null
            ? null
            : _positiveDueDays(latestInvoice.createdAt, latestInvoice.dueDate),
      );

      final overallAmountSuggestion = _pickQuickAmountSuggestion(
        amountCounts,
        fallbackAmount: latestInvoice?.amount,
      );
      quickAmount = overallAmountSuggestion?.value;
      quickAmountReason = overallAmountSuggestion?.reason;

      for (final client in clients) {
        final aggregate = clientAggregates[client.id];
        final memory = learning.clientMemories[client.id];
        if (aggregate != null) {
          suggestionsByClient[client.id] = aggregate.toSuggestion(
            memory: memory,
            globalPreferredDueDays: preferredDueDays,
          );
        } else if (memory != null) {
          suggestionsByClient[client.id] = _suggestionFromMemory(
            memory,
            globalPreferredDueDays: preferredDueDays,
          );
        }
      }

      final lastClientId = learning.lastClientId;
      if (lastClientId != null && clientById.containsKey(lastClientId)) {
        suggestedClient = clientById[lastClientId];
        suggestedClientReason = 'Last used client';
      } else if (latestInvoice != null &&
          clientById.containsKey(latestInvoice.clientId)) {
        suggestedClient = clientById[latestInvoice.clientId];
        suggestedClientReason = 'Most recent client';
      } else {
        final frequentClientId = _pickMostFrequentClientId(clientAggregates);
        if (frequentClientId != null) {
          suggestedClient = clientById[frequentClientId];
          suggestedClientReason = 'Most used client';
        }
      }
    } else {
      preferredDueDays = _pickTopIntFromStringMap(learning.dueDaysUsageCounts);

      final overallAmountSuggestion = _pickQuickAmountSuggestion(
        learning.amountUsageCounts,
        fallbackAmount: null,
      );
      quickAmount = overallAmountSuggestion?.value;
      quickAmountReason = overallAmountSuggestion?.reason;

      for (final client in clients) {
        final memory = learning.clientMemories[client.id];
        if (memory != null) {
          suggestionsByClient[client.id] = _suggestionFromMemory(
            memory,
            globalPreferredDueDays: preferredDueDays,
          );
        }
      }

      final lastClientId = learning.lastClientId;
      if (lastClientId != null && clientById.containsKey(lastClientId)) {
        suggestedClient = clientById[lastClientId];
        suggestedClientReason = 'Last used client';
      } else {
        final memoryClientId = _pickMostRelevantMemoryClientId(
          learning.clientMemories,
          clientById.keys.toSet(),
        );
        if (memoryClientId != null) {
          suggestedClient = clientById[memoryClientId];
          suggestedClientReason = 'Frequently used client';
        }
      }
    }

    return CreateInvoiceIntelligence(
      suggestedClient: suggestedClient,
      suggestedClientReason: suggestedClientReason,
      preferredDueDays: preferredDueDays,
      quickAmount: quickAmount,
      quickAmountReason: quickAmountReason,
      firstAvailableClient: clients.isEmpty ? null : clients.first,
      suggestionsByClient: suggestionsByClient,
    );
  }

  QuickCreateInvoiceDraft buildQuickDraft({DateTime? now}) {
    final invoiceDate = now ?? DateTime.now();
    final selectedClient = suggestedClient ?? firstAvailableClient;
    final selectedSuggestion = selectedClient == null
        ? null
        : suggestionFor(selectedClient.id);
    final dueDays =
        selectedSuggestion?.suggestedDueDays ?? preferredDueDays ?? 7;

    return QuickCreateInvoiceDraft(
      clientId: selectedClient?.id ?? 'client-quick-general',
      clientName: selectedClient?.name ?? 'General Client',
      service: _normalizedService(selectedSuggestion?.service),
      amount: selectedSuggestion?.amount ?? quickAmount ?? 0,
      dueDate: DateTime(
        invoiceDate.year,
        invoiceDate.month,
        invoiceDate.day,
      ).add(Duration(days: dueDays)),
      client: selectedClient,
    );
  }

  static String _normalizedService(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'General Service';
    }
    return trimmed;
  }

  static CreateInvoiceClientSuggestion _suggestionFromMemory(
    InvoiceCreationClientMemory memory, {
    int? globalPreferredDueDays,
  }) {
    final fallbackService =
        memory.lastService ?? _pickTopService(memory.serviceUsageCounts);
    _AmountSuggestion? amountSuggestion;

    if (fallbackService != null && fallbackService.isNotEmpty) {
      amountSuggestion = _pickAmountSuggestionForService(
        memory.serviceAmountUsageCounts[fallbackService] ??
            const <String, int>{},
        fallbackAmount: memory.lastAmount,
      );
    }

    final amount = amountSuggestion?.value ?? memory.lastAmount;
    final reason =
        amountSuggestion?.reason ?? (amount == null ? null : 'last used');

    return CreateInvoiceClientSuggestion(
      service: fallbackService,
      amount: amount,
      amountReason: reason,
      suggestedDueDays: memory.lastDueDays ?? globalPreferredDueDays,
      latestInvoice: null,
    );
  }

  static String? _pickMostFrequentClientId(
    Map<String, _ClientInvoiceAggregate> clientAggregates,
  ) {
    String? bestClientId;
    var bestUsageCount = -1;
    DateTime? bestRecentUse;

    for (final entry in clientAggregates.entries) {
      final usageCount = entry.value.usageCount;
      final recentUse = entry.value.latestInvoice?.createdAt;
      if (usageCount > bestUsageCount) {
        bestClientId = entry.key;
        bestUsageCount = usageCount;
        bestRecentUse = recentUse;
        continue;
      }

      if (usageCount == bestUsageCount && recentUse != null) {
        if (bestRecentUse == null || recentUse.isAfter(bestRecentUse)) {
          bestClientId = entry.key;
          bestRecentUse = recentUse;
        }
      }
    }

    return bestClientId;
  }

  static String? _pickMostRelevantMemoryClientId(
    Map<String, InvoiceCreationClientMemory> memories,
    Set<String> allowedClientIds,
  ) {
    String? bestClientId;
    var bestUsageCount = -1;
    DateTime? bestRecentUse;

    for (final entry in memories.entries) {
      if (!allowedClientIds.contains(entry.key)) {
        continue;
      }

      final usageCount = entry.value.usageCount;
      final recentUse = entry.value.lastUsedAt;
      if (usageCount > bestUsageCount) {
        bestClientId = entry.key;
        bestUsageCount = usageCount;
        bestRecentUse = recentUse;
        continue;
      }

      if (usageCount == bestUsageCount && recentUse != null) {
        if (bestRecentUse == null || recentUse.isAfter(bestRecentUse)) {
          bestClientId = entry.key;
          bestRecentUse = recentUse;
        }
      }
    }

    return bestClientId;
  }

  static int? _pickTopInt(Map<int, int> counts, {int? fallbackValue}) {
    if (counts.isEmpty) {
      return fallbackValue;
    }

    int? bestValue;
    var bestCount = -1;
    for (final entry in counts.entries) {
      if (entry.value > bestCount) {
        bestValue = entry.key;
        bestCount = entry.value;
        continue;
      }

      if (entry.value == bestCount && entry.key == fallbackValue) {
        bestValue = entry.key;
      }
    }
    return bestValue ?? fallbackValue;
  }

  static int? _pickTopIntFromStringMap(Map<String, int> counts) {
    if (counts.isEmpty) {
      return null;
    }

    final parsed = <int, int>{};
    for (final entry in counts.entries) {
      final parsedKey = int.tryParse(entry.key);
      if (parsedKey != null) {
        parsed[parsedKey] = entry.value;
      }
    }

    return _pickTopInt(parsed);
  }

  static String? _pickTopService(Map<String, int> counts) {
    if (counts.isEmpty) {
      return null;
    }

    String? bestValue;
    var bestCount = -1;
    for (final entry in counts.entries) {
      if (entry.value > bestCount) {
        bestValue = entry.key;
        bestCount = entry.value;
      }
    }
    return bestValue;
  }

  static _AmountSuggestion? _pickQuickAmountSuggestion(
    Map<String, int> counts, {
    double? fallbackAmount,
  }) {
    if (counts.isEmpty) {
      if (fallbackAmount == null) {
        return null;
      }
      return _AmountSuggestion(value: fallbackAmount, reason: 'last used');
    }

    var topKey = '';
    var topCount = -1;
    var secondBestCount = -1;
    var uniqueTop = true;

    for (final entry in counts.entries) {
      if (entry.value > topCount) {
        secondBestCount = topCount;
        topKey = entry.key;
        topCount = entry.value;
        uniqueTop = true;
      } else if (entry.value == topCount) {
        uniqueTop = false;
      } else if (entry.value > secondBestCount) {
        secondBestCount = entry.value;
      }
    }

    if (topKey.isNotEmpty && uniqueTop && topCount > secondBestCount) {
      return _AmountSuggestion(
        value: _parseAmount(topKey),
        reason: 'common amount',
      );
    }

    if (fallbackAmount != null) {
      return _AmountSuggestion(value: fallbackAmount, reason: 'last used');
    }

    return _AmountSuggestion(
      value: _parseAmount(topKey),
      reason: 'common amount',
    );
  }

  static _AmountSuggestion? _pickAmountSuggestionForService(
    Map<String, int> counts, {
    double? fallbackAmount,
  }) {
    if (counts.isEmpty) {
      if (fallbackAmount == null) {
        return null;
      }
      return _AmountSuggestion(value: fallbackAmount, reason: 'last used');
    }

    if (counts.length == 1) {
      return _AmountSuggestion(
        value: _parseAmount(counts.keys.first),
        reason: 'last used',
      );
    }

    var topKey = '';
    var topCount = -1;
    var secondBestCount = -1;
    var uniqueTop = true;

    for (final entry in counts.entries) {
      if (entry.value > topCount) {
        secondBestCount = topCount;
        topKey = entry.key;
        topCount = entry.value;
        uniqueTop = true;
      } else if (entry.value == topCount) {
        uniqueTop = false;
      } else if (entry.value > secondBestCount) {
        secondBestCount = entry.value;
      }
    }

    if (topKey.isNotEmpty && uniqueTop && topCount > secondBestCount) {
      return _AmountSuggestion(
        value: _parseAmount(topKey),
        reason: 'most used',
      );
    }

    if (fallbackAmount != null) {
      return _AmountSuggestion(value: fallbackAmount, reason: 'average');
    }

    return _AmountSuggestion(value: _parseAmount(topKey), reason: 'most used');
  }
}

class CreateInvoiceClientSuggestion {
  const CreateInvoiceClientSuggestion({
    required this.service,
    required this.amount,
    required this.amountReason,
    required this.suggestedDueDays,
    required this.latestInvoice,
  });

  final String? service;
  final double? amount;
  final String? amountReason;
  final int? suggestedDueDays;
  final Invoice? latestInvoice;
}

class QuickCreateInvoiceDraft {
  const QuickCreateInvoiceDraft({
    required this.clientId,
    required this.clientName,
    required this.service,
    required this.amount,
    required this.dueDate,
    required this.client,
  });

  final String clientId;
  final String clientName;
  final String service;
  final double amount;
  final DateTime dueDate;
  final Client? client;

  String get dedupeSignature {
    final dueDateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return '$clientId|$service|${amount.toStringAsFixed(2)}|${dueDateOnly.toIso8601String()}';
  }
}

class _ClientInvoiceAggregate {
  int usageCount = 0;
  Invoice? latestInvoice;
  final Map<String, _ServiceAmountAggregate> _serviceAggregates = {};

  void add(Invoice invoice) {
    usageCount += 1;
    if (latestInvoice == null ||
        invoice.createdAt.isAfter(latestInvoice!.createdAt)) {
      latestInvoice = invoice;
    }

    final service = invoice.service.trim();
    if (service.isEmpty) {
      return;
    }

    final aggregate = _serviceAggregates.putIfAbsent(
      service,
      _ServiceAmountAggregate.new,
    );
    aggregate.add(invoice);
  }

  CreateInvoiceClientSuggestion toSuggestion({
    required InvoiceCreationClientMemory? memory,
    required int? globalPreferredDueDays,
  }) {
    final latest = latestInvoice;
    final latestService = latest?.service.trim();
    final service = latestService != null && latestService.isNotEmpty
        ? latestService
        : (memory?.lastService ??
              CreateInvoiceIntelligence._pickTopService(
                memory?.serviceUsageCounts ?? const <String, int>{},
              ));

    final serviceAggregate = service == null
        ? null
        : _serviceAggregates[service];
    final amountSuggestion =
        CreateInvoiceIntelligence._pickAmountSuggestionForService(
          serviceAggregate?.amountUsageCounts ??
              (service == null
                  ? const <String, int>{}
                  : (memory?.serviceAmountUsageCounts[service] ??
                        const <String, int>{})),
          fallbackAmount: latest?.amount ?? memory?.lastAmount,
        );

    return CreateInvoiceClientSuggestion(
      service: service,
      amount: amountSuggestion?.value ?? latest?.amount ?? memory?.lastAmount,
      amountReason:
          amountSuggestion?.reason ??
          ((latest?.amount ?? memory?.lastAmount) == null ? null : 'last used'),
      suggestedDueDays:
          _positiveDueDaysFromInvoice(latest) ??
          memory?.lastDueDays ??
          globalPreferredDueDays,
      latestInvoice: latest,
    );
  }
}

class _ServiceAmountAggregate {
  _ServiceAmountAggregate();

  final Map<String, int> amountUsageCounts = {};

  void add(Invoice invoice) {
    final amountKey = _amountKey(invoice.amount);
    amountUsageCounts[amountKey] = (amountUsageCounts[amountKey] ?? 0) + 1;
  }
}

class _AmountSuggestion {
  const _AmountSuggestion({required this.value, required this.reason});

  final double value;
  final String reason;
}

DateTime? _parseDateTime(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
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

int? _positiveDueDaysFromInvoice(Invoice? invoice) {
  if (invoice == null) {
    return null;
  }
  return _positiveDueDays(invoice.createdAt, invoice.dueDate);
}

String _amountKey(double amount) => amount.toStringAsFixed(2);

double _parseAmount(String value) => double.tryParse(value) ?? 0;
