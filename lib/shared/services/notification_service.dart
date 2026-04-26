import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../core/services/app_feedback_service.dart';
import '../../core/utils/formatters.dart';
import '../../features/invoices/domain/entities/invoice.dart';
import '../../features/settings/data/datasources/settings_local_datasource.dart';
import '../../features/settings/domain/entities/app_preferences.dart';
import '../../features/subscription/data/datasources/subscription_local_datasource.dart';

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService.instance,
);

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();
  static const MethodChannel _timezoneChannel = MethodChannel(
    'reminder/device_timezone',
  );
  static const String _channelId = 'invoice_due_reminders';
  static const String _channelName = 'Invoice Due Reminders';
  static const String _channelDescription =
      'Notifications for upcoming and due invoices.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  Completer<void>? _initCompleter;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    // If already initializing, wait for that to complete
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }

    _initCompleter = Completer<void>();

    try {
      tz.initializeTimeZones();
      await _configureLocalTimezone();

      const androidSettings = AndroidInitializationSettings(
        'ic_notification',
      );
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const settings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );

      await _plugin.initialize(settings: settings);
      _initialized = true;
      _initCompleter!.complete();
    } catch (e) {
      if (!_initCompleter!.isCompleted) {
        _initCompleter!.completeError(e);
      }
    }
  }

  Future<bool> requestPermissionsIfNeeded() async {
    await initialize();
    return _requestPermissions();
  }

  Future<void> scheduleInvoiceReminders(Invoice invoice) async {
    try {
      await initialize();
      final subscription = await const SubscriptionLocalDatasource()
          .loadState();
      if (!subscription.isPro) {
        await cancelInvoiceReminders(invoice.id);
        return;
      }

      final preferences = await _loadPreferences();
      if (!preferences.pushNotificationsEnabled) {
        await cancelInvoiceReminders(invoice.id);
        return;
      }

      final hasPermission = await _requestPermissions();
      if (!hasPermission) {
        AppFeedbackService.showSnackBar(
          'Notification permission denied. Invoice reminders were not scheduled.',
        );
        return;
      }

      await cancelInvoiceReminders(invoice.id);

      final now = DateTime.now();
      final dueDate = invoice.dueDate;
      final scheduleItems = <_ScheduledReminder>[
        if (preferences.remindOnDueDate)
          _ScheduledReminder(
            id: _notificationId(invoice.id, 'due'),
            title: 'Invoice due now',
            body: _buildReminderBody(invoice),
            scheduledAt: dueDate,
            payload: invoice.id,
          ),
        if (preferences.remind24HoursBefore)
          _ScheduledReminder(
            id: _notificationId(invoice.id, 'day-before'),
            title: 'Invoice due in 24 hours',
            body: _buildReminderBody(invoice),
            scheduledAt: dueDate.subtract(const Duration(hours: 24)),
            payload: invoice.id,
          ),
        if (preferences.remind3HoursBefore)
          _ScheduledReminder(
            id: _notificationId(invoice.id, 'three-hours'),
            title: 'Invoice due in 3 hours',
            body: _buildReminderBody(invoice),
            scheduledAt: dueDate.subtract(const Duration(hours: 3)),
            payload: invoice.id,
          ),
      ];

      if (scheduleItems.isEmpty) {
        return;
      }

      var scheduledAny = false;
      for (final item in scheduleItems) {
        if (!item.scheduledAt.isAfter(now)) {
          continue;
        }

        await scheduleReminder(
          id: item.id,
          scheduledAt: item.scheduledAt,
          title: item.title,
          body: item.body,
          payload: item.payload,
        );
        scheduledAny = true;
      }

      if (!scheduledAny &&
          preferences.remindOnDueDate &&
          !dueDate.isAfter(now)) {
        await showInstantReminder(
          id: _notificationId(invoice.id, 'instant'),
          title: 'Invoice reminder',
          body: _buildReminderBody(invoice),
          payload: invoice.id,
        );
      }
    } catch (_) {
      AppFeedbackService.showSnackBar(
        'Unable to schedule invoice reminders right now.',
      );
    }
  }

  Future<void> scheduleReminder({
    required int id,
    required DateTime scheduledAt,
    required String title,
    required String body,
    String? payload,
  }) async {
    final scheduledDate = tz.TZDateTime.from(scheduledAt, tz.local);

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: _notificationDetails,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> showInstantReminder({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await initialize();
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _notificationDetails,
      payload: payload,
    );
  }

  Future<void> cancelInvoiceReminders(String invoiceId) async {
    await initialize();
    await _plugin.cancel(id: _notificationId(invoiceId, 'due'));
    await _plugin.cancel(id: _notificationId(invoiceId, 'day-before'));
    await _plugin.cancel(id: _notificationId(invoiceId, 'three-hours'));
    await _plugin.cancel(id: _notificationId(invoiceId, 'instant'));
  }

  NotificationDetails get _notificationDetails => const NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_notification',
      color: Color(0xFFC8A96A),
    ),
    iOS: DarwinNotificationDetails(threadIdentifier: _channelId),
    macOS: DarwinNotificationDetails(threadIdentifier: _channelId),
  );

  Future<void> _configureLocalTimezone() async {
    try {
      final timezoneName = await _timezoneChannel.invokeMethod<String>(
        'getLocalTimezone',
      );
      if (timezoneName == null || timezoneName.isEmpty) {
        tz.setLocalLocation(tz.UTC);
        return;
      }

      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
  }

  Future<bool> _requestPermissions() async {
    if (kIsWeb) {
      return false;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final androidImplementation = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

        final notificationsGranted =
            await androidImplementation?.requestNotificationsPermission() ??
            true;
        if (!notificationsGranted) {
          return false;
        }

        final exactAlarmsGranted =
            await androidImplementation?.requestExactAlarmsPermission() ?? true;
        return exactAlarmsGranted;
      case TargetPlatform.iOS:
        final iosImplementation = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        return await iosImplementation?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      case TargetPlatform.macOS:
        final macOsImplementation = _plugin
            .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >();
        return await macOsImplementation?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            true;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return true;
    }
  }

  String _buildReminderBody(Invoice invoice) {
    final dueDate = invoice.dueDate.toLocal().toString().split(' ').first;
    final amount = AppFormatters.currency(
      invoice.amount,
      currencyCode: invoice.currencyCode,
    );
    return '${invoice.clientName} has an invoice for '
        '$amount due on $dueDate.';
  }

  int _notificationId(String invoiceId, String slot) {
    return Object.hash(invoiceId, slot) & 0x7fffffff;
  }

  Future<AppPreferences> _loadPreferences() async {
    try {
      return await SettingsLocalDatasource().getAppPreferences();
    } catch (_) {
      return const AppPreferences.defaults();
    }
  }
}

class _ScheduledReminder {
  const _ScheduledReminder({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledAt,
    required this.payload,
  });

  final int id;
  final String title;
  final String body;
  final DateTime scheduledAt;
  final String payload;
}
