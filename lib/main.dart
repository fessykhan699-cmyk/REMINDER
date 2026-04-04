import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/storage/hive_storage.dart';

const Color _rootBackground = Color(0xFF0F1115);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveStorage.initialize();
  runApp(
    const ProviderScope(
      child: InvoiceReminderApp(scaffoldBackgroundColor: _rootBackground),
    ),
  );
}
