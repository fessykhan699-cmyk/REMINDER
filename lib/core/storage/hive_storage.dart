import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../features/clients/data/models/client_model.dart';
import '../../features/invoices/data/models/invoice_model.dart';
import '../../features/reminders/data/models/reminder_model.dart';
import '../../features/settings/data/models/app_preferences_model.dart';
import '../../features/settings/data/models/profile_model.dart';

/// Known demo/seed data identifiers that must be purged.
const _demoClientIds = {'client-1', 'client-2'};
const _demoInvoiceIds = {'inv-1', 'inv-2'};

class HiveStorage {
  HiveStorage._();

  static const String clientsBoxName = 'clientsBox';
  static const String invoicesBoxName = 'invoicesBox';
  static const String settingsBoxName = 'settingsBox';
  static const String remindersBoxName = 'remindersBox';
  static const String userProfileBoxName = 'userProfileBox';
  static const String appPreferencesBoxName = 'appPreferencesBox';

  static const String _demoCleanupFlag = '_demoCleanupDone';

  static void registerAdapters() {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ClientModelAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(InvoiceStatusAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(InvoiceModelAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(ReminderChannelAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(ReminderStatusAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(ReminderModelAdapter());
    }
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(ProfileModelAdapter());
    }
    if (!Hive.isAdapterRegistered(7)) {
      Hive.registerAdapter(PaymentTermsOptionAdapter());
    }
    if (!Hive.isAdapterRegistered(8)) {
      Hive.registerAdapter(AppPreferencesModelAdapter());
    }
  }

  static Box<ClientModel> get clientsBox =>
      Hive.box<ClientModel>(clientsBoxName);

  static Box<InvoiceModel> get invoicesBox =>
      Hive.box<InvoiceModel>(invoicesBoxName);

  static Box<dynamic> get settingsBox => Hive.box<dynamic>(settingsBoxName);

  /// One-time migration: removes any leftover demo/seed data from previous app versions.
  /// Runs once and never again.
  static Future<void> purgeDemoDataOnce() async {
    final settingsBox = Hive.isBoxOpen(settingsBoxName)
        ? Hive.box<dynamic>(settingsBoxName)
        : null;
    final alreadyCleaned = settingsBox?.get(_demoCleanupFlag) ?? false;
    if (alreadyCleaned) {
      debugPrint("✅ Demo cleanup already done — skipping");
      return;
    }

    debugPrint("🔥 Running one-time demo data cleanup…");
    var removedClients = 0;
    var removedInvoices = 0;

    // Remove demo clients
    if (Hive.isBoxOpen(clientsBoxName)) {
      final clientBox = clientsBox;
      for (final id in _demoClientIds) {
        if (clientBox.containsKey(id)) {
          await clientBox.delete(id);
          removedClients++;
        }
      }
    }

    // Remove demo invoices
    if (Hive.isBoxOpen(invoicesBoxName)) {
      final invoiceBox = invoicesBox;
      for (final id in _demoInvoiceIds) {
        if (invoiceBox.containsKey(id)) {
          await invoiceBox.delete(id);
          removedInvoices++;
        }
      }
    }

    debugPrint(
      "🔥 Demo cleanup complete: removed $removedClients clients, $removedInvoices invoices",
    );

    // Mark as done so it never runs again
    settingsBox?.put(_demoCleanupFlag, true);
  }
}
