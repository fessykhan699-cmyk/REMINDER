import 'notification_service.dart';

/// Temporary test — schedule a notification 1 minute from now.
/// Delete this file after verifying notifications work.
Future<void> testNotificationNow() async {
  final service = NotificationService.instance;
  final granted = await service.requestPermissionsIfNeeded();
  if (!granted) {
    throw Exception(
      'Notification permission denied. Grant exact alarm permission in system settings.',
    );
  }

  final scheduledAt = DateTime.now().add(const Duration(minutes: 1));

  await service.scheduleReminder(
    id: 999999,
    scheduledAt: scheduledAt,
    title: 'Test Reminder',
    body: 'If you see this, notifications are working',
  );
}
