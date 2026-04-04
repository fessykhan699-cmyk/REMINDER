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
  static const String remindersBoxName = 'remindersBox';
  static const String userProfileBoxName = 'userProfileBox';
  static const String appPreferencesBoxName = 'appPreferencesBox';

  static Future<void> initialize() async {
    await Hive.initFlutter();
    _registerAdapters();

    final clientsBox = await _openBox<ClientModel>(clientsBoxName);
    final invoicesBox = await _openBox<InvoiceModel>(invoicesBoxName);
    await _openBox<ReminderModel>(remindersBoxName);
    await _openBox<ProfileModel>(userProfileBoxName);
    await _openBox<AppPreferencesModel>(appPreferencesBoxName);

    await _seedClients(clientsBox);
    await _seedInvoices(invoicesBox);
  }

  static void _registerAdapters() {
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

  static Future<Box<T>> _openBox<T>(String name) async {
    if (Hive.isBoxOpen(name)) {
      return Hive.box<T>(name);
    }
    return Hive.openBox<T>(name);
  }

  static Future<void> _seedClients(Box<ClientModel> box) async {
    if (box.isNotEmpty) {
      return;
    }

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

  static Future<void> _seedInvoices(Box<InvoiceModel> box) async {
    if (box.isNotEmpty) {
      return;
    }

    final now = DateTime.now();
    final invoices = <InvoiceModel>[
      InvoiceModel(
        id: 'inv-1',
        clientId: 'client-1',
        clientName: 'Northwind Studio',
        service: 'Brand identity package',
        amount: 1850,
        dueDate: now.subtract(const Duration(days: 4)),
        status: InvoiceStatus.pending,
        createdAt: now.subtract(const Duration(days: 21)),
        currencyCode: 'USD',
        taxPercent: 0,
        paymentTermsDays: 0,
      ),
      InvoiceModel(
        id: 'inv-2',
        clientId: 'client-2',
        clientName: 'Acme Retail',
        service: 'Monthly analytics report',
        amount: 920,
        dueDate: now.add(const Duration(days: 6)),
        status: InvoiceStatus.pending,
        createdAt: now.subtract(const Duration(days: 9)),
        currencyCode: 'USD',
        taxPercent: 0,
        paymentTermsDays: 0,
      ),
    ];

    await box.putAll({for (final invoice in invoices) invoice.id: invoice});
  }
}
