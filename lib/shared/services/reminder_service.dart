import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../../features/invoices/domain/entities/invoice.dart';
import '../../features/settings/data/datasources/settings_local_datasource.dart';
import '../../features/settings/domain/entities/app_preferences.dart';
import '../../features/subscription/data/datasources/subscription_local_datasource.dart';
import 'notification_service.dart';

final reminderServiceProvider = Provider<ReminderService>(
  (ref) => ReminderService(
    notificationService: ref.watch(notificationServiceProvider),
  ),
);

class ReminderService {
  const ReminderService({required NotificationService notificationService})
    : _notificationService = notificationService;

  final NotificationService _notificationService;

  Future<void> scheduleInvoiceReminders(Invoice invoice) async {
    try {
      await _notificationService.initialize();

      final subscription = await const SubscriptionLocalDatasource()
          .loadState();
      if (!subscription.isPro || invoice.status.isPaid) {
        await cancelInvoiceReminders(invoice.id);
        return;
      }

      final preferences = await _loadPreferences();
      if (!preferences.pushNotificationsEnabled) {
        await cancelInvoiceReminders(invoice.id);
        return;
      }

      final hasPermission = await _notificationService
          .requestPermissionsIfNeeded();
      if (!hasPermission) {
        debugPrint(
          'Notification permissions unavailable for invoice ${invoice.id}.',
        );
        return;
      }

      await _notificationService.cancelInvoiceReminders(invoice.id);

      final now = DateTime.now();
      final dueDate = invoice.dueDate;
      final scheduleItems = <_ReminderScheduleItem>[
        if (preferences.remind24HoursBefore)
          _ReminderScheduleItem(
            id: Object.hash(invoice.id, '24h') & 0x7fffffff,
            scheduledAt: dueDate.subtract(const Duration(hours: 24)),
          ),
        if (preferences.remind3HoursBefore)
          _ReminderScheduleItem(
            id: Object.hash(invoice.id, '3h') & 0x7fffffff,
            scheduledAt: dueDate.subtract(const Duration(hours: 3)),
          ),
        if (preferences.remindOnDueDate)
          _ReminderScheduleItem(
            id: Object.hash(invoice.id, 'due') & 0x7fffffff,
            scheduledAt: dueDate,
          ),
      ];

      for (final item in scheduleItems) {
        if (!item.scheduledAt.isAfter(now)) {
          continue;
        }

        await _notificationService.scheduleReminder(
          id: item.id,
          scheduledAt: item.scheduledAt,
          title: 'Invoice Due Reminder',
          body: _buildBody(invoice),
          payload: invoice.id,
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to schedule invoice reminders: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> rescheduleInvoiceReminders(Invoice invoice) async {
    await scheduleInvoiceReminders(invoice);
  }

  Future<void> cancelInvoiceReminders(String invoiceId) async {
    try {
      await _notificationService.cancelInvoiceReminders(invoiceId);
    } catch (error, stackTrace) {
      debugPrint('Failed to cancel invoice reminders for $invoiceId: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<AppPreferences> _loadPreferences() async {
    try {
      return await SettingsLocalDatasource().getAppPreferences();
    } catch (_) {
      return const AppPreferences.defaults();
    }
  }

  String _buildBody(Invoice invoice) {
    final amount = AppFormatters.currency(
      invoice.amount,
      currencyCode: invoice.currencyCode,
    );
    final date = invoice.dueDate.toLocal().toString().split(' ').first;
    return 'Invoice for ${invoice.clientName} of $amount is due on $date.';
  }
}

class _ReminderScheduleItem {
  const _ReminderScheduleItem({required this.id, required this.scheduledAt});

  final int id;
  final DateTime scheduledAt;
}
