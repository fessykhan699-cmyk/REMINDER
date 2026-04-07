import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../features/clients/data/models/client_model.dart';
import '../../features/invoices/data/models/invoice_model.dart';
import '../../features/invoices/domain/entities/invoice.dart';
import '../../features/reminders/data/models/reminder_model.dart';
import '../../features/settings/data/models/app_preferences_model.dart';
import '../../features/settings/data/models/profile_model.dart';

class HiveStorage {
  HiveStorage._();

  static const String clientsBoxName = 'clientsBox';
  static const String invoicesBoxName = 'invoicesBox';
  static const String settingsBoxName = 'settingsBox';
  static const String remindersBoxName = 'remindersBox';
  static const String userProfileBoxName = 'userProfileBox';
  static const String appPreferencesBoxName = 'appPreferencesBox';
  static const String _seededFlag = '_hasBeenSeeded';

  /// Exposed for reset button access
  static String get seededFlag => _seededFlag;

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

  static Future<void> seedDefaultsIfNeeded() async {
    // Check if seeding has ever been done (persistent across restarts)
    final settingsBox = Hive.isBoxOpen(settingsBoxName)
        ? Hive.box<dynamic>(settingsBoxName)
        : null;
    final hasBeenSeeded = settingsBox?.get(_seededFlag) ?? false;

    if (!hasBeenSeeded) {
      debugPrint("🔥 SEEDING initial data (first launch only)");
      await _seedClients(clientsBox);
      await _seedInvoices(invoicesBox);
      settingsBox?.put(_seededFlag, true);
    } else {
      debugPrint("✅ SKIPPING seed — already seeded previously");
    }
  }

  static Future<void> _seedClients(Box<ClientModel> box) async {
    if (box.isEmpty) {
      debugPrint("🔥 SEEDING initial clients data");
      final now = DateTime.now();
      final clients = <ClientModel>[
        ClientModel(
          id: 'client-1',
          name: 'Northwind Studio',
          email: 'billing@northwind.com',
          phone: '+1 555 103 882',
          createdAt: now.subtract(const Duration(days: 20)),
        ),
        ClientModel(
          id: 'client-2',
          name: 'Acme Retail',
          email: 'finance@acme.co',
          phone: '+1 555 912 100',
          createdAt: now.subtract(const Duration(days: 12)),
        ),
      ];

      await box.putAll({for (final client in clients) client.id: client});
    }
  }

  static Future<void> _seedInvoices(Box<InvoiceModel> box) async {
    if (box.isEmpty) {
      debugPrint("🔥 SEEDING initial invoices data");
      final now = DateTime.now();
      final invoices = <InvoiceModel>[
        InvoiceModel(
          id: 'inv-1',
          clientId: 'client-1',
          clientName: 'Northwind Studio',
          service: 'Brand identity package',
          amount: 1850,
          dueDate: now.subtract(const Duration(days: 4)),
          status: InvoiceStatus.draft,
          createdAt: now.subtract(const Duration(days: 21)),
          currencyCode: 'USD',
          taxPercent: 0,
          paymentTermsDays: 0,
          discountAmount: 0,
          paymentLink: 'https://pay.invoiceflow.app/inv-1',
        ),
        InvoiceModel(
          id: 'inv-2',
          clientId: 'client-2',
          clientName: 'Acme Retail',
          service: 'Monthly analytics report',
          amount: 920,
          dueDate: now.add(const Duration(days: 6)),
          status: InvoiceStatus.draft,
          createdAt: now.subtract(const Duration(days: 9)),
          currencyCode: 'USD',
          taxPercent: 0,
          paymentTermsDays: 0,
          discountAmount: 0,
          paymentLink: 'https://pay.invoiceflow.app/inv-2',
        ),
      ];

      await box.putAll({for (final invoice in invoices) invoice.id: invoice});
    }
  }
}
