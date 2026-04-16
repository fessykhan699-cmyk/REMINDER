import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/providers/firestore_sync_provider.dart';
import '../../../../shared/services/reminder_launcher_service.dart';
import '../../../subscription/presentation/controllers/subscription_controller.dart';
import '../../domain/repositories/reminder_repository.dart';
import '../datasources/reminders_local_datasource.dart';
import '../repositories/reminder_repository_impl.dart';

final remindersLocalDatasourceProvider = Provider<RemindersLocalDatasource>(
  (ref) => RemindersLocalDatasource(ref.watch(reminderLauncherServiceProvider)),
);

final reminderRepositoryProvider = Provider<ReminderRepository>(
  (ref) {
    final datasource = ref.watch(remindersLocalDatasourceProvider);
    return ReminderRepositoryImpl(
      datasource,
      syncService: ref.watch(firestoreSyncServiceProvider),
      userId: ref.watch(currentUserIdProvider),
      isPro:
          ref.watch(subscriptionControllerProvider).valueOrNull?.isPro ?? false,
    );
  },
);
