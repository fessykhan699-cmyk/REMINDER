import 'dart:convert';

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
    required this.openDetailAfterQuickCreate,
  });

  const InvoiceCreationLearningState.initial()
    : lastClientId = null,
      dueDaysUsageCounts = const {},
      amountUsageCounts = const {},
      clientMemories = const {},
      openDetailAfterQuickCreate = false;

  final String? lastClientId;
  final Map<String, int> dueDaysUsageCounts;
  final Map<String, int> amountUsageCounts;
  final Map<String, InvoiceCreationClientMemory> clientMemories;
  final bool openDetailAfterQuickCreate;

  InvoiceCreationLearningState copyWith({
    String? lastClientId,
    bool clearLastClientId = false,
    Map<String, int>? dueDaysUsageCounts,
    Map<String, int>? amountUsageCounts,
    Map<String, InvoiceCreationClientMemory>? clientMemories,
    bool? openDetailAfterQuickCreate,
  }) {
    return InvoiceCreationLearningState(
      lastClientId: clearLastClientId
          ? null
          : (lastClientId ?? this.lastClientId),
      dueDaysUsageCounts: dueDaysUsageCounts ?? this.dueDaysUsageCounts,
      amountUsageCounts: amountUsageCounts ?? this.amountUsageCounts,
      clientMemories: clientMemories ?? this.clientMemories,
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

  Future<void> rebuildFromInvoices(List<Invoice> invoices) async {
    await _ensureBootstrapped();

    final derivedState = _deriveStateFromInvoices(
      invoices,
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
    required bool openDetailAfterQuickCreate,
  }) {
    if (invoices.isEmpty) {
      return InvoiceCreationLearningState(
        lastClientId: null,
        dueDaysUsageCounts: const {},
        amountUsageCounts: const {},
        clientMemories: const {},
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
      openDetailAfterQuickCreate: openDetailAfterQuickCreate,
    );
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
