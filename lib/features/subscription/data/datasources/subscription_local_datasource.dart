import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/storage/hive_storage.dart';
import '../../../clients/data/models/client_model.dart';
import '../../../invoices/data/models/invoice_model.dart';
import '../../domain/entities/subscription_state.dart';

class SubscriptionLocalDatasource {
  const SubscriptionLocalDatasource();

  static const String storageKey = 'invoice_flow_is_pro_v1';

  Future<SubscriptionState> loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final isPro = prefs.getBool(storageKey) ?? false;
    return isPro
        ? const SubscriptionState.pro()
        : const SubscriptionState.free();
  }

  Future<SubscriptionState> savePlan({required bool isPro}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(storageKey, isPro);
    return isPro
        ? const SubscriptionState.pro()
        : const SubscriptionState.free();
  }

  SubscriptionUsage loadUsage({DateTime? now}) {
    final clientsBox = Hive.box<ClientModel>(HiveStorage.clientsBoxName);
    final invoicesBox = Hive.box<InvoiceModel>(HiveStorage.invoicesBoxName);
    final current = now ?? DateTime.now();
    final monthStart = DateTime(current.year, current.month);
    final nextMonth = current.month == 12
        ? DateTime(current.year + 1, 1)
        : DateTime(current.year, current.month + 1);

    var monthlyInvoiceCount = 0;
    for (final invoice in invoicesBox.values) {
      final createdAt = invoice.createdAt;
      if (!createdAt.isBefore(monthStart) && createdAt.isBefore(nextMonth)) {
        monthlyInvoiceCount++;
      }
    }

    return SubscriptionUsage(
      clientCount: clientsBox.length,
      monthlyInvoiceCount: monthlyInvoiceCount,
    );
  }
}
