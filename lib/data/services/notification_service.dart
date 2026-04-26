import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

import '../../features/invoices/domain/entities/invoice.dart';
import '../../features/subscription/data/datasources/subscription_local_datasource.dart';

const String _overdueChannelId = 'overdue_invoices';
const String _overdueChannelName = 'Paydeck Reminders';
const String _overdueChannelDesc = 'Daily notifications for overdue invoices';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    try {
      tz.initializeTimeZones();
      final String timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
      
      const androidSettings = AndroidInitializationSettings('ic_notification');
      const settings = InitializationSettings(android: androidSettings);
      
      await _plugin.initialize(settings: settings);
      
      final androidImplementation = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      // Request notification permission on Android 13+
      await androidImplementation?.requestNotificationsPermission();
      
      // Delete old cached channels before recreating
      await androidImplementation?.deleteNotificationChannel(channelId: 'invoice_reminders');
      await androidImplementation?.deleteNotificationChannel(channelId: 'overdue_invoices');
      await androidImplementation?.deleteNotificationChannel(channelId: 'invoice_due_reminders');

      // Configure notification channels
      const channel = AndroidNotificationChannel(
        'invoice_reminders',
        'Paydeck',
        importance: Importance.high,
      );
      await androidImplementation?.createNotificationChannel(channel);

      const overdueChannel = AndroidNotificationChannel(
        'overdue_invoices',
        'Paydeck Reminders',
        description: 'Notifications for overdue invoices',
        importance: Importance.high,
      );
      await androidImplementation?.createNotificationChannel(overdueChannel);
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  static Future<void> scheduleInvoiceReminders(Invoice invoice) async {
    try {
      // Step 6 — Subscription gate
      final subscription = await const SubscriptionLocalDatasource().loadState();
      if (!subscription.isPro) return;

      if (invoice.status.isPaid) {
        await cancelInvoiceReminders(invoice.id);
        return;
      }

      final now = DateTime.now();
      final dueDate = invoice.dueDate;

      // Skip if due date is already in the past
      if (dueDate.isBefore(now) && 
          !(dueDate.year == now.year && dueDate.month == now.month && dueDate.day == now.day)) {
        return;
      }

      final invoiceHash = invoice.id.hashCode;

      // Notification 1: 1 day before due date
      final oneDayBefore = dueDate.subtract(const Duration(days: 1));
      final oneDayBeforeAt9 = DateTime(oneDayBefore.year, oneDayBefore.month, oneDayBefore.day, 9, 0);
      
      if (oneDayBeforeAt9.isAfter(now)) {
        await _schedule(
          id: (invoiceHash * 2) & 0x7FFFFFFF,
          title: 'Payment Due Tomorrow',
          body: 'Invoice #${invoice.id} for ${invoice.clientName} is due tomorrow.',
          scheduledAt: oneDayBeforeAt9,
        );
      }

      // Notification 2: on the due date at 9:00 AM
      final dueDayAt9 = DateTime(dueDate.year, dueDate.month, dueDate.day, 9, 0);
      
      if (dueDayAt9.isAfter(now)) {
        await _schedule(
          id: (invoiceHash * 2 + 1) & 0x7FFFFFFF,
          title: 'Payment Due Today',
          body: 'Invoice #${invoice.id} for ${invoice.clientName} is due today.',
          scheduledAt: dueDayAt9,
        );
      }
    } catch (e) {
      debugPrint('NotificationService scheduleInvoiceReminders error: $e');
    }
  }

  static Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
  }) async {
    final tzDate = tz.TZDateTime.from(scheduledAt, tz.local);
    
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tzDate,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'invoice_reminders',
          'Paydeck',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_notification',
          color: Color(0xFFC8A96A),
          colorized: false,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  static Future<void> cancelInvoiceReminders(String invoiceId) async {
    try {
      final invoiceHash = invoiceId.hashCode;
      await _plugin.cancel(id: (invoiceHash * 2) & 0x7FFFFFFF);
      await _plugin.cancel(id: (invoiceHash * 2 + 1) & 0x7FFFFFFF);
    } catch (e) {
      debugPrint('NotificationService cancelInvoiceReminders error: $e');
    }
  }

  static Future<void> showOverdueNotification(Invoice invoice) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dueDay = DateTime(
        invoice.dueDate.year,
        invoice.dueDate.month,
        invoice.dueDate.day,
      );
      final daysOverdue = today.difference(dueDay).inDays.clamp(1, 9999);

      final symbol = _currencySymbol(invoice.currencyCode);
      final amount = '$symbol${invoice.amount.toStringAsFixed(2)}';

      await _plugin.show(
        id: (invoice.id.hashCode * 2 + 2) & 0x7FFFFFFF,
        title: 'Invoice Overdue',
        body: '${invoice.clientName} invoice for $amount is overdue by '
            '$daysOverdue day${daysOverdue == 1 ? '' : 's'}',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _overdueChannelId,
            _overdueChannelName,
            channelDescription: _overdueChannelDesc,
            importance: Importance.max,
            priority: Priority.high,
            icon: 'ic_notification',
            color: Color(0xFFC8A96A),
            colorized: false,
          ),
        ),
        payload: invoice.id,
      );
    } catch (e) {
      debugPrint('NotificationService showOverdueNotification error: $e');
    }
  }

  static String _currencySymbol(String code) {
    const symbols = <String, String>{
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'AED': 'AED ',
      'INR': '₹',
      'SAR': 'SAR ',
    };
    return symbols[code] ?? '$code ';
  }

  static Future<void> cancelAllNotifications() async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('NotificationService cancelAllNotifications error: $e');
    }
  }
}
