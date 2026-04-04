import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/reminders/domain/entities/reminder.dart';

final reminderLauncherServiceProvider = Provider<ReminderLauncherService>(
  (ref) => const ReminderLauncherService(),
);

class ReminderLaunchResult {
  const ReminderLaunchResult({
    required this.channel,
    this.usedFallback = false,
  });

  final ReminderChannel channel;
  final bool usedFallback;
}

class ReminderLauncherService {
  const ReminderLauncherService();

  bool hasValidPhoneNumber(String? phoneNumber) {
    final digits = _digitsOnly(phoneNumber);
    return digits.length >= 8 && digits.length <= 15;
  }

  Future<ReminderLaunchResult> launchReminder({
    required ReminderChannel preferredChannel,
    required String phoneNumber,
    required String message,
  }) async {
    if (!hasValidPhoneNumber(phoneNumber)) {
      throw Exception('Client phone number is missing.');
    }

    switch (preferredChannel) {
      case ReminderChannel.whatsapp:
        final openedWhatsApp = await _launchWhatsApp(
          phoneNumber: phoneNumber,
          message: message,
        );
        if (openedWhatsApp) {
          return const ReminderLaunchResult(channel: ReminderChannel.whatsapp);
        }

        final openedSms = await _launchSms(
          phoneNumber: phoneNumber,
          message: message,
        );
        if (openedSms) {
          return const ReminderLaunchResult(
            channel: ReminderChannel.sms,
            usedFallback: true,
          );
        }

        throw Exception('Unable to open WhatsApp or SMS on this device.');
      case ReminderChannel.sms:
        final openedSms = await _launchSms(
          phoneNumber: phoneNumber,
          message: message,
        );
        if (openedSms) {
          return const ReminderLaunchResult(channel: ReminderChannel.sms);
        }

        throw Exception('Unable to open SMS on this device.');
    }
  }

  Future<bool> _launchWhatsApp({
    required String phoneNumber,
    required String message,
  }) async {
    final whatsAppPhone = _digitsOnly(phoneNumber);
    final uri = Uri(
      scheme: 'https',
      host: 'wa.me',
      path: whatsAppPhone,
      queryParameters: <String, String>{'text': message},
    );

    try {
      return await launchUrl(
        uri,
        mode: LaunchMode.externalNonBrowserApplication,
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> _launchSms({
    required String phoneNumber,
    required String message,
  }) async {
    final uri = Uri(
      scheme: 'sms',
      path: _smsPath(phoneNumber),
      query: _encodeQueryParameters(<String, String>{'body': message}),
    );

    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  String _digitsOnly(String? phoneNumber) {
    return (phoneNumber ?? '').replaceAll(RegExp(r'[^0-9]'), '');
  }

  String _smsPath(String phoneNumber) {
    return phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
  }

  String _encodeQueryParameters(Map<String, String> parameters) {
    return parameters.entries
        .map(
          (entry) =>
              '${Uri.encodeComponent(entry.key)}='
              '${Uri.encodeComponent(entry.value)}',
        )
        .join('&');
  }
}
