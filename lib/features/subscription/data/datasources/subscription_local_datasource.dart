import 'package:hive/hive.dart';

import '../../../../core/storage/hive_storage.dart';
import '../../../clients/data/models/client_model.dart';
import '../../../invoices/data/models/invoice_model.dart';
import '../../domain/entities/subscription_state.dart';

class SubscriptionLocalDatasource {
  const SubscriptionLocalDatasource();

  static const String storageKey = 'invoice_flow_is_pro_v1';
  static const String planStorageKey = 'invoice_flow_plan_v2';
  static const String debugModeKey = 'debug_mode_enabled';

  Box<dynamic>? get _settingsBoxOrNull {
    if (!Hive.isBoxOpen(HiveStorage.settingsBoxName)) {
      return null;
    }

    return Hive.box<dynamic>(HiveStorage.settingsBoxName);
  }

  bool loadDebugMode() {
    return _settingsBoxOrNull?.get(debugModeKey, defaultValue: false) as bool? ??
        false;
  }

  Future<void> saveDebugMode(bool value) async {
    await _settingsBoxOrNull?.put(debugModeKey, value);
  }

  Future<SubscriptionState> loadState() async {
    final savedPlanName = _settingsBoxOrNull?.get(planStorageKey) as String?;
    if (savedPlanName != null) {
      final savedPlan = InvoiceFlowPlan.values
          .where((plan) => plan.name == savedPlanName)
          .cast<InvoiceFlowPlan?>()
          .firstWhere((plan) => plan != null, orElse: () => null);
      if (savedPlan != null) {
        return _stateFromPlan(savedPlan);
      }
    }

    final isPro = _settingsBoxOrNull?.get(storageKey) as bool? ?? false;
    return isPro
        ? const SubscriptionState.pro()
        : const SubscriptionState.free();
  }

  Future<SubscriptionState> savePlan({required bool isPro}) async {
    final settingsBox = _settingsBoxOrNull;
    if (settingsBox != null) {
      await settingsBox.put(storageKey, isPro);
      await settingsBox.put(
        planStorageKey,
        isPro ? InvoiceFlowPlan.pro.name : InvoiceFlowPlan.free.name,
      );
    }

    return isPro
        ? const SubscriptionState.pro()
        : const SubscriptionState.free();
  }

  Future<SubscriptionState> savePlanTier(InvoiceFlowPlan plan) async {
    final settingsBox = _settingsBoxOrNull;
    if (settingsBox != null) {
      await settingsBox.put(storageKey, plan != InvoiceFlowPlan.free);
      await settingsBox.put(planStorageKey, plan.name);
    }
    return _stateFromPlan(plan);
  }

  SubscriptionState _stateFromPlan(InvoiceFlowPlan plan) {
    return switch (plan) {
      InvoiceFlowPlan.free => const SubscriptionState.free(),
      InvoiceFlowPlan.pro => const SubscriptionState.pro(),
      InvoiceFlowPlan.business => const SubscriptionState.business(),
    };
  }

  SubscriptionUsage loadUsage({DateTime? now}) {
    final current = now ?? DateTime.now();
    final monthStart = DateTime(current.year, current.month);
    final nextMonth = current.month == 12
        ? DateTime(current.year + 1, 1)
        : DateTime(current.year, current.month + 1);

    final clientCount = Hive.isBoxOpen(HiveStorage.clientsBoxName)
        ? Hive.box<ClientModel>(HiveStorage.clientsBoxName).length
        : 0;

    var monthlyInvoiceCount = 0;
    if (Hive.isBoxOpen(HiveStorage.invoicesBoxName)) {
      final invoicesBox = Hive.box<InvoiceModel>(HiveStorage.invoicesBoxName);
      for (final invoice in invoicesBox.values) {
        final createdAt = invoice.createdAt;
        if (!createdAt.isBefore(monthStart) && createdAt.isBefore(nextMonth)) {
          monthlyInvoiceCount++;
        }
      }
    }

    return SubscriptionUsage(
      clientCount: clientCount,
      monthlyInvoiceCount: monthlyInvoiceCount,
    );
  }
}
