import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/services/reminder_launcher_service.dart';
import '../../domain/repositories/reminder_repository.dart';
import '../datasources/reminders_local_datasource.dart';
import '../repositories/reminder_repository_impl.dart';

final remindersLocalDatasourceProvider = Provider<RemindersLocalDatasource>(
  (ref) => RemindersLocalDatasource(ref.watch(reminderLauncherServiceProvider)),
);

final reminderRepositoryProvider = Provider<ReminderRepository>(
  (ref) => ReminderRepositoryImpl(ref.watch(remindersLocalDatasourceProvider)),
);
