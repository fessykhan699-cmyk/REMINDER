import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AdaptiveTabKey { dashboard, invoices, clients, settings }

enum AdaptiveActionKey {
  newInvoice,
  addClient,
  sendReminder,
  reviewPayments,
  markPaid,
}

final adaptiveSystemProvider =
    NotifierProvider<AdaptiveSystemController, AdaptiveSystemState>(
      AdaptiveSystemController.new,
    );

class AdaptiveSystemState {
  const AdaptiveSystemState({
    required this.tabUsageCounts,
    required this.actionUsageCounts,
    required this.lastActionKey,
    required this.lastActionAt,
    required this.lastActivityAt,
    required this.lastReminderSentAt,
    required this.lastReminderOpportunityAt,
    required this.ignoredReminderCount,
  });

  const AdaptiveSystemState.initial()
    : tabUsageCounts = const {},
      actionUsageCounts = const {},
      lastActionKey = null,
      lastActionAt = null,
      lastActivityAt = null,
      lastReminderSentAt = null,
      lastReminderOpportunityAt = null,
      ignoredReminderCount = 0;

  final Map<String, int> tabUsageCounts;
  final Map<String, int> actionUsageCounts;
  final String? lastActionKey;
  final DateTime? lastActionAt;
  final DateTime? lastActivityAt;
  final DateTime? lastReminderSentAt;
  final DateTime? lastReminderOpportunityAt;
  final int ignoredReminderCount;

  AdaptiveSystemState copyWith({
    Map<String, int>? tabUsageCounts,
    Map<String, int>? actionUsageCounts,
    String? lastActionKey,
    bool clearLastActionKey = false,
    DateTime? lastActionAt,
    bool clearLastActionAt = false,
    DateTime? lastActivityAt,
    bool clearLastActivityAt = false,
    DateTime? lastReminderSentAt,
    bool clearLastReminderSentAt = false,
    DateTime? lastReminderOpportunityAt,
    bool clearLastReminderOpportunityAt = false,
    int? ignoredReminderCount,
  }) {
    return AdaptiveSystemState(
      tabUsageCounts: tabUsageCounts ?? this.tabUsageCounts,
      actionUsageCounts: actionUsageCounts ?? this.actionUsageCounts,
      lastActionKey: clearLastActionKey
          ? null
          : (lastActionKey ?? this.lastActionKey),
      lastActionAt: clearLastActionAt
          ? null
          : (lastActionAt ?? this.lastActionAt),
      lastActivityAt: clearLastActivityAt
          ? null
          : (lastActivityAt ?? this.lastActivityAt),
      lastReminderSentAt: clearLastReminderSentAt
          ? null
          : (lastReminderSentAt ?? this.lastReminderSentAt),
      lastReminderOpportunityAt: clearLastReminderOpportunityAt
          ? null
          : (lastReminderOpportunityAt ?? this.lastReminderOpportunityAt),
      ignoredReminderCount: ignoredReminderCount ?? this.ignoredReminderCount,
    );
  }

  int tabUsage(AdaptiveTabKey tab) => tabUsageCounts[tab.name] ?? 0;

  int actionUsage(AdaptiveActionKey action) =>
      actionUsageCounts[action.name] ?? 0;

  AdaptiveActionKey? get lastAction {
    final key = lastActionKey;
    if (key == null) {
      return null;
    }

    for (final action in AdaptiveActionKey.values) {
      if (action.name == key) {
        return action;
      }
    }
    return null;
  }

  AdaptiveActionKey? get preferredFabAction {
    final candidates = [
      AdaptiveActionKey.newInvoice,
      AdaptiveActionKey.addClient,
      AdaptiveActionKey.sendReminder,
    ];

    AdaptiveActionKey? bestAction;
    var bestCount = 0;
    var secondBest = 0;

    for (final candidate in candidates) {
      final count = actionUsage(candidate);
      if (count > bestCount) {
        secondBest = bestCount;
        bestCount = count;
        bestAction = candidate;
      } else if (count > secondBest) {
        secondBest = count;
      }
    }

    if (bestAction == null || bestCount == 0) {
      return null;
    }

    if (bestCount - secondBest < 2) {
      return null;
    }

    return bestAction;
  }

  List<AdaptiveTabKey> get orderedTabs {
    const workTabs = [
      AdaptiveTabKey.dashboard,
      AdaptiveTabKey.invoices,
      AdaptiveTabKey.clients,
    ];

    final sortedTabs = [...workTabs]
      ..sort((a, b) {
        final usageCompare = tabUsage(b).compareTo(tabUsage(a));
        if (usageCompare != 0) {
          return usageCompare;
        }
        return workTabs.indexOf(a).compareTo(workTabs.indexOf(b));
      });

    return [...sortedTabs, AdaptiveTabKey.settings];
  }

  bool get hasRecentResolution {
    final action = lastAction;
    final timestamp = lastActionAt;
    if (action == null || timestamp == null) {
      return false;
    }

    if (action != AdaptiveActionKey.sendReminder &&
        action != AdaptiveActionKey.markPaid) {
      return false;
    }

    return DateTime.now().difference(timestamp) <= const Duration(hours: 24);
  }

  int? get inactiveDays {
    final timestamp = lastActivityAt;
    if (timestamp == null) {
      return null;
    }

    final difference = DateTime.now().difference(timestamp).inDays;
    if (difference <= 0) {
      return null;
    }

    return difference;
  }

  factory AdaptiveSystemState.fromJson(Map<String, dynamic> json) {
    return AdaptiveSystemState(
      tabUsageCounts: _toIntMap(json['tabUsageCounts']),
      actionUsageCounts: _toIntMap(json['actionUsageCounts']),
      lastActionKey: json['lastActionKey'] as String?,
      lastActionAt: _parseDateTime(json['lastActionAt'] as String?),
      lastActivityAt: _parseDateTime(json['lastActivityAt'] as String?),
      lastReminderSentAt: _parseDateTime(json['lastReminderSentAt'] as String?),
      lastReminderOpportunityAt: _parseDateTime(
        json['lastReminderOpportunityAt'] as String?,
      ),
      ignoredReminderCount:
          (json['ignoredReminderCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tabUsageCounts': tabUsageCounts,
      'actionUsageCounts': actionUsageCounts,
      'lastActionKey': lastActionKey,
      'lastActionAt': lastActionAt?.toIso8601String(),
      'lastActivityAt': lastActivityAt?.toIso8601String(),
      'lastReminderSentAt': lastReminderSentAt?.toIso8601String(),
      'lastReminderOpportunityAt': lastReminderOpportunityAt?.toIso8601String(),
      'ignoredReminderCount': ignoredReminderCount,
    };
  }

  static Map<String, int> _toIntMap(Object? raw) {
    if (raw is! Map) {
      return const {};
    }

    final output = <String, int>{};
    for (final entry in raw.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is String && value is num) {
        output[key] = value.toInt();
      }
    }
    return output;
  }

  static DateTime? _parseDateTime(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }
}

class AdaptiveSystemController extends Notifier<AdaptiveSystemState> {
  static const _storageKey = 'adaptive_system_state_v1';

  Future<void>? _bootstrapFuture;

  @override
  AdaptiveSystemState build() {
    Future<void>(_ensureBootstrapped);
    return const AdaptiveSystemState.initial();
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
      final decoded = jsonDecode(rawState) as Map<String, dynamic>;
      state = AdaptiveSystemState.fromJson(decoded);
    } catch (_) {
      state = const AdaptiveSystemState.initial();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(state.toJson()));
  }

  Future<void> recordTabVisit(AdaptiveTabKey tab) async {
    await _ensureBootstrapped();

    final updatedCounts = Map<String, int>.from(state.tabUsageCounts);
    updatedCounts[tab.name] = (updatedCounts[tab.name] ?? 0) + 1;

    state = state.copyWith(
      tabUsageCounts: updatedCounts,
      lastActivityAt: DateTime.now(),
    );
    await _persist();
  }

  Future<void> recordAction(AdaptiveActionKey action) async {
    await _ensureBootstrapped();

    final now = DateTime.now();
    final updatedCounts = Map<String, int>.from(state.actionUsageCounts);
    updatedCounts[action.name] = (updatedCounts[action.name] ?? 0) + 1;

    final resetsReminderPressure =
        action == AdaptiveActionKey.sendReminder ||
        action == AdaptiveActionKey.markPaid;

    state = state.copyWith(
      actionUsageCounts: updatedCounts,
      lastActionKey: action.name,
      lastActionAt: now,
      lastActivityAt: now,
      lastReminderSentAt: action == AdaptiveActionKey.sendReminder
          ? now
          : state.lastReminderSentAt,
      lastReminderOpportunityAt: resetsReminderPressure
          ? now
          : state.lastReminderOpportunityAt,
      ignoredReminderCount: resetsReminderPressure
          ? state.ignoredReminderCount > 0
                ? state.ignoredReminderCount - 1
                : 0
          : state.ignoredReminderCount,
    );
    await _persist();
  }

  Future<void> recordReminderOpportunity({required int overdueCount}) async {
    await _ensureBootstrapped();

    if (overdueCount <= 0) {
      return;
    }

    final now = DateTime.now();
    final lastOpportunityAt = state.lastReminderOpportunityAt;
    if (lastOpportunityAt != null &&
        now.difference(lastOpportunityAt) < const Duration(hours: 12)) {
      return;
    }

    final lastReminderSentAt = state.lastReminderSentAt;
    if (lastReminderSentAt != null &&
        now.difference(lastReminderSentAt) < const Duration(hours: 12)) {
      return;
    }

    state = state.copyWith(
      lastReminderOpportunityAt: now,
      ignoredReminderCount: state.ignoredReminderCount + 1,
    );
    await _persist();
  }
}
