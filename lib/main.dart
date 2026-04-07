import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'firebase_options.dart';

import 'features/clients/data/models/client_model.dart';
import 'features/invoices/data/models/invoice_model.dart';
import 'features/reminders/data/models/reminder_model.dart';
import 'features/settings/data/models/app_preferences_model.dart';
import 'features/settings/data/models/profile_model.dart';

import 'app.dart';
import 'core/storage/hive_storage.dart';
import 'shared/services/notification_service.dart';

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

  await _openBoxSafe<ClientModel>(HiveStorage.clientsBoxName);
  await _openBoxSafe<InvoiceModel>(HiveStorage.invoicesBoxName);
  await _openBoxSafe<dynamic>(HiveStorage.settingsBoxName);
  await _openBoxSafe<ReminderModel>(HiveStorage.remindersBoxName);
  await _openBoxSafe<ProfileModel>(HiveStorage.userProfileBoxName);
  await _openBoxSafe<AppPreferencesModel>(HiveStorage.appPreferencesBoxName);

  await HiveStorage.seedDefaultsIfNeeded();
  await NotificationService.instance.initialize();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ── Firebase Connection Debug ──
  try {
    final user = FirebaseAuth.instance.currentUser;
    // ignore: avoid_print
    print('[Firebase] Current user: ${user?.uid ?? 'none'}');

    await FirebaseFirestore.instance.collection('test').add({
      'status': 'connected',
      'timestamp': FieldValue.serverTimestamp(),
    });
    // ignore: avoid_print
    print('[Firebase] Firestore write successful → test doc created');
  } catch (e) {
    // ignore: avoid_print
    print('[Firebase] Connection failed: $e');
  }

  runApp(
    const ProviderScope(
      child: InvoiceReminderApp(scaffoldBackgroundColor: _rootBackground),
    ),
  );
}
