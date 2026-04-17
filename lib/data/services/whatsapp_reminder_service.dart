import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/storage/hive_storage.dart';

final whatsAppReminderServiceProvider = Provider<WhatsAppReminderService>((ref) {
  return WhatsAppReminderService();
});

class WhatsAppReminderService {
  String getFriendlyMessage(String clientName, String amount, String dueDate) {
    return "Hi $clientName, this is a friendly reminder that invoice of $amount is due on $dueDate. Please let us know if you have any questions. Thank you!";
  }

  String getFirmMessage(String clientName, String amount, String dueDate) {
    return "Dear $clientName, your payment of $amount was due on $dueDate and remains outstanding. Kindly process the payment at your earliest convenience.";
  }

  String getFinalMessage(String clientName, String amount, String dueDate) {
    return "FINAL NOTICE: Dear $clientName, your payment of $amount is now overdue since $dueDate. Immediate payment is required to avoid further action.";
  }

  Future<bool> sendReminder({
    required String invoiceId,
    required String phone,
    required String message,
    required String template,
  }) async {
    try {
      // sanitizes phone: strip all spaces, dashes, brackets
      final sanitizedPhone = phone.replaceAll(RegExp(r'[\s\-()\[\]]'), '');
      if (sanitizedPhone.isEmpty) return false;

      // builds URL: https://wa.me/[phone]?text=[Uri.encodeComponent(message)]
      final url = "https://wa.me/$sanitizedPhone?text=${Uri.encodeComponent(message)}";
      final uri = Uri.parse(url);

      if (await canLaunchUrl(uri)) {
        // calls launchUrl with mode: LaunchMode.externalApplication
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (launched) {
          // logs reminder timestamp to Hive under key: 'wa_reminder_[invoiceId]'
          // Based on the prefix requirement in getReminderHistory, we use unique keys per entry
          final box = Hive.box(HiveStorage.settingsBoxName);
          final entryKey = 'wa_reminder_${invoiceId}_${DateTime.now().millisecondsSinceEpoch}';
          await box.put(entryKey, {
            'timestamp': DateTime.now().toIso8601String(),
            'template': template,
          });
          return true;
        }
      }
      return false;
    } catch (e) {
      // on any error: log to console, return false
      debugPrint('WhatsAppReminderService.sendReminder error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getReminderHistory(String invoiceId) async {
    try {
      // reads all Hive entries with prefix 'wa_reminder_[invoiceId]'
      final box = Hive.box(HiveStorage.settingsBoxName);
      final prefix = 'wa_reminder_$invoiceId';
      final history = <Map<String, dynamic>>[];

      for (final key in box.keys) {
        if (key is String && key.startsWith(prefix)) {
          final entry = box.get(key);
          if (entry is Map) {
            history.add(Map<String, dynamic>.from(entry));
          }
        }
      }

      // Sort by timestamp descending
      history.sort((a, b) => (b['timestamp'] as String).compareTo(a['timestamp'] as String));
      
      return history;
    } catch (e) {
      debugPrint('WhatsAppReminderService.getReminderHistory error: $e');
      return [];
    }
  }
}
