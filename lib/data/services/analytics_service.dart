import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Service to handle Firebase Analytics and Crashlytics reporting.
class AnalyticsService {
  static final AnalyticsService instance = AnalyticsService._internal();

  AnalyticsService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Logs a screen view event.
  Future<void> logScreenView(String screenName) async {
    try {
      await _analytics.logScreenView(screenName: screenName);
    } catch (e) {
      debugPrint('Analytics logScreenView failed: $e');
    }
  }

  /// Logs when a new invoice is created.
  Future<void> logInvoiceCreated({
    required String invoiceId,
    required double amount,
    required String currency,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'invoice_created',
        parameters: {
          'invoice_id': invoiceId,
          'amount': amount,
          'currency': currency,
        },
      );
    } catch (e) {
      debugPrint('Analytics logInvoiceCreated failed: $e');
    }
  }

  /// Logs when an invoice is fully paid.
  Future<void> logInvoicePaid({
    required String invoiceId,
    required double amount,
    required String currency,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'invoice_paid',
        parameters: {
          'invoice_id': invoiceId,
          'amount': amount,
          'currency': currency,
        },
      );
    } catch (e) {
      debugPrint('Analytics logInvoicePaid failed: $e');
    }
  }

  /// Logs when an invoice is shared (WhatsApp, Email, etc.).
  Future<void> logInvoiceShared(String method) async {
    try {
      await _analytics.logEvent(
        name: 'invoice_shared',
        parameters: {
          'method': method,
        },
      );
    } catch (e) {
      debugPrint('Analytics logInvoiceShared failed: $e');
    }
  }

  /// Logs when a new client is created.
  Future<void> logClientCreated({required String clientId}) async {
    try {
      await _analytics.logEvent(
        name: 'client_created',
        parameters: {
          'client_id': clientId,
        },
      );
    } catch (e) {
      debugPrint('Analytics logClientCreated failed: $e');
    }
  }

  /// Logs when an upgrade prompt is shown.
  Future<void> logUpgradePromptShown(String featureName) async {
    try {
      await _analytics.logEvent(
        name: 'upgrade_prompt_shown',
        parameters: {
          'feature_name': featureName,
        },
      );
    } catch (e) {
      debugPrint('Analytics logUpgradePromptShown failed: $e');
    }
  }

  /// Logs when an upgrade button is tapped.
  Future<void> logUpgradeTapped(String featureName) async {
    try {
      await _analytics.logEvent(
        name: 'upgrade_tapped',
        parameters: {
          'feature_name': featureName,
        },
      );
    } catch (e) {
      debugPrint('Analytics logUpgradeTapped failed: $e');
    }
  }

  /// Logs when data is exported to CSV.
  Future<void> logCsvExported() async {
    try {
      await _analytics.logEvent(name: 'csv_exported');
    } catch (e) {
      debugPrint('Analytics logCsvExported failed: $e');
    }
  }

  /// Logs when a recurring invoice is created.
  Future<void> logRecurringInvoiceCreated({
    required String parentInvoiceId,
    required String newInvoiceId,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'recurring_invoice_created',
        parameters: {
          'parent_invoice_id': parentInvoiceId,
          'new_invoice_id': newInvoiceId,
        },
      );
    } catch (e) {
      debugPrint('Analytics logRecurringInvoiceCreated failed: $e');
    }
  }

  /// Reports an error to Firebase Crashlytics.
  static Future<void> reportError(
    dynamic error,
    StackTrace? stack, {
    bool fatal = false,
  }) async {
    try {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        fatal: fatal,
      );
    } catch (e) {
      debugPrint('Crashlytics reportError failed: $e');
    }
  }
}
