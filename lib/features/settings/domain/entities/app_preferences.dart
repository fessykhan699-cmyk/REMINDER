enum PaymentTermsOption { net7, net15, net30 }

extension PaymentTermsOptionX on PaymentTermsOption {
  String get label {
    switch (this) {
      case PaymentTermsOption.net7:
        return 'Net 7';
      case PaymentTermsOption.net15:
        return 'Net 15';
      case PaymentTermsOption.net30:
        return 'Net 30';
    }
  }

  int get days {
    switch (this) {
      case PaymentTermsOption.net7:
        return 7;
      case PaymentTermsOption.net15:
        return 15;
      case PaymentTermsOption.net30:
        return 30;
    }
  }
}

class AppPreferences {
  const AppPreferences({
    required this.pushNotificationsEnabled,
    required this.whatsAppRemindersEnabled,
    required this.smsRemindersEnabled,
    required this.remind24HoursBefore,
    required this.remind3HoursBefore,
    required this.remindOnDueDate,
    required this.appLockEnabled,
    required this.appLockPin,
    required this.defaultCurrency,
    required this.expenseCurrency,
    required this.defaultTaxPercent,
    required this.invoicePrefix,
    required this.nextInvoiceNumber,
    required this.paymentTerms,
    required this.oneTapInvoiceEnabled,
    required this.smartPredictionEnabled,
    required this.biometricLockEnabled,
    required this.faceUnlockEnabled,
  });

  const AppPreferences.defaults()
    : pushNotificationsEnabled = true,
      whatsAppRemindersEnabled = true,
      smsRemindersEnabled = true,
      remind24HoursBefore = true,
      remind3HoursBefore = true,
      remindOnDueDate = true,
      appLockEnabled = false,
      appLockPin = '',
      defaultCurrency = 'USD',
      expenseCurrency = 'AED',
      defaultTaxPercent = 0,
      invoicePrefix = 'INV',
      nextInvoiceNumber = 1,
      paymentTerms = PaymentTermsOption.net30,
      oneTapInvoiceEnabled = true,
      smartPredictionEnabled = true,
      biometricLockEnabled = false,
      faceUnlockEnabled = false;

  final bool pushNotificationsEnabled;
  final bool whatsAppRemindersEnabled;
  final bool smsRemindersEnabled;
  final bool remind24HoursBefore;
  final bool remind3HoursBefore;
  final bool remindOnDueDate;
  final bool appLockEnabled;
  final String appLockPin;
  final String defaultCurrency;
  final String expenseCurrency;
  final double defaultTaxPercent;
  final String invoicePrefix;
  final int nextInvoiceNumber;
  final PaymentTermsOption paymentTerms;
  final bool oneTapInvoiceEnabled;
  final bool smartPredictionEnabled;
  final bool biometricLockEnabled;
  final bool faceUnlockEnabled;

  bool get hasPin => appLockPin.trim().length >= 4;

  AppPreferences copyWith({
    bool? pushNotificationsEnabled,
    bool? whatsAppRemindersEnabled,
    bool? smsRemindersEnabled,
    bool? remind24HoursBefore,
    bool? remind3HoursBefore,
    bool? remindOnDueDate,
    bool? appLockEnabled,
    String? appLockPin,
    bool clearPin = false,
    String? defaultCurrency,
    String? expenseCurrency,
    double? defaultTaxPercent,
    String? invoicePrefix,
    int? nextInvoiceNumber,
    PaymentTermsOption? paymentTerms,
    bool? oneTapInvoiceEnabled,
    bool? smartPredictionEnabled,
    bool? biometricLockEnabled,
    bool? faceUnlockEnabled,
  }) {
    return AppPreferences(
      pushNotificationsEnabled:
          pushNotificationsEnabled ?? this.pushNotificationsEnabled,
      whatsAppRemindersEnabled:
          whatsAppRemindersEnabled ?? this.whatsAppRemindersEnabled,
      smsRemindersEnabled: smsRemindersEnabled ?? this.smsRemindersEnabled,
      remind24HoursBefore: remind24HoursBefore ?? this.remind24HoursBefore,
      remind3HoursBefore: remind3HoursBefore ?? this.remind3HoursBefore,
      remindOnDueDate: remindOnDueDate ?? this.remindOnDueDate,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      appLockPin: clearPin ? '' : (appLockPin ?? this.appLockPin),
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      expenseCurrency: expenseCurrency ?? this.expenseCurrency,
      defaultTaxPercent: defaultTaxPercent ?? this.defaultTaxPercent,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
      nextInvoiceNumber: nextInvoiceNumber ?? this.nextInvoiceNumber,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      oneTapInvoiceEnabled: oneTapInvoiceEnabled ?? this.oneTapInvoiceEnabled,
      smartPredictionEnabled:
          smartPredictionEnabled ?? this.smartPredictionEnabled,
      biometricLockEnabled: biometricLockEnabled ?? this.biometricLockEnabled,
      faceUnlockEnabled: faceUnlockEnabled ?? this.faceUnlockEnabled,
    );
  }
}
