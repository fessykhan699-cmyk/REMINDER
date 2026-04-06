import 'package:hive/hive.dart';

import '../../../../core/storage/hive_storage.dart';
import '../../../clients/data/models/client_model.dart';
import '../../../invoices/data/models/invoice_model.dart';
import '../../domain/entities/subscription_state.dart';

class SubscriptionLocalDatasource {
  const SubscriptionLocalDatasource();

  static const String storageKey = 'invoice_flow_is_pro_v1';

  Box<dynamic>? get _settingsBoxOrNull {
    if (!Hive.isBoxOpen(HiveStorage.settingsBoxName)) {
      return null;
    }

    return Hive.box<dynamic>(HiveStorage.settingsBoxName);
  }

  Future<SubscriptionState> loadState() async {
    final isPro = _settingsBoxOrNull?.get(storageKey) as bool? ?? false;
    return isPro
        ? const SubscriptionState.pro()
        : const SubscriptionState.free();
  }

  Future<SubscriptionState> savePlan({required bool isPro}) async {
    final settingsBox = _settingsBoxOrNull;
    if (settingsBox != null) {
      await settingsBox.put(storageKey, isPro);
    }

    return isPro
        ? const SubscriptionState.pro()
        : const SubscriptionState.free();
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
