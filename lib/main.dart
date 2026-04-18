import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'firebase_options.dart';

import 'features/clients/data/models/client_model.dart';
import 'features/invoices/data/models/invoice_model.dart';
import 'features/reminders/data/models/reminder_model.dart';
import 'features/settings/data/models/app_preferences_model.dart';
import 'features/settings/data/models/profile_model.dart';
import 'features/expenses/data/models/expense_model.dart';

import 'app.dart';
import 'core/storage/hive_storage.dart';
import 'data/services/notification_service.dart';
import 'data/services/overdue_flip_service.dart';

const Color _rootBackground = Color(0xFF0F1115);

Future<Box<T>> _openBoxSafe<T>(String name) async {
  if (Hive.isBoxOpen(name)) {
    return Hive.box<T>(name);
  }
  return Hive.openBox<T>(name);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  HiveStorage.registerAdapters();

  // ✅ Open all boxes
  await _openBoxSafe<ClientModel>(HiveStorage.clientsBoxName);
  await _openBoxSafe<InvoiceModel>(HiveStorage.invoicesBoxName);
  await _openBoxSafe<dynamic>(HiveStorage.settingsBoxName);
  await _openBoxSafe<ReminderModel>(HiveStorage.remindersBoxName);
  await _openBoxSafe<ProfileModel>(HiveStorage.userProfileBoxName);
  await _openBoxSafe<AppPreferencesModel>(HiveStorage.appPreferencesBoxName);
  await _openBoxSafe<ExpenseModel>(HiveStorage.expensesBoxName);

  // 🔥 One-time cleanup: remove any leftover demo/seed data from previous versions
  await HiveStorage.purgeDemoDataOnce();
  await HiveStorage.pruneRemindersOnce();


  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 🛡️ Initialize Crashlytics
  try {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (e) {
    debugPrint('Firebase Crashlytics initialization failed: $e');
  }

  await NotificationService.init();

  // Flip overdue invoices on startup
  try {
    await OverdueFlipService().flipOverdueInvoices();
  } catch (e) {
    debugPrint('OverdueFlipService error on startup: $e');
  }

  runApp(
    const ProviderScope(
      child: InvoiceReminderApp(scaffoldBackgroundColor: _rootBackground),
    ),
  );
}
