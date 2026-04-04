import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/storage/hive_storage.dart';
import 'shared/services/notification_service.dart';

const Color _rootBackground = Color(0xFF0F1115);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveStorage.initialize();
  await NotificationService.instance.initialize();
  runApp(
    const ProviderScope(
      child: InvoiceReminderApp(scaffoldBackgroundColor: _rootBackground),
    ),
  );
}
