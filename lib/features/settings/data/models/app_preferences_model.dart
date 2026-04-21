import 'package:hive/hive.dart';

import '../../domain/entities/app_preferences.dart';

class PaymentTermsOptionAdapter extends TypeAdapter<PaymentTermsOption> {
  @override
  final int typeId = 7;

  @override
  PaymentTermsOption read(BinaryReader reader) {
    return PaymentTermsOption.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, PaymentTermsOption obj) {
    writer.writeByte(obj.index);
  }
}

class AppPreferencesModel extends AppPreferences {
  const AppPreferencesModel({
    required super.pushNotificationsEnabled,
    required super.whatsAppRemindersEnabled,
    required super.smsRemindersEnabled,
    required super.remind24HoursBefore,
    required super.remind3HoursBefore,
    required super.remindOnDueDate,
    required super.appLockEnabled,
    required super.appLockPin,
    required super.defaultCurrency,
    required super.expenseCurrency,
    required super.defaultTaxPercent,
    required super.invoicePrefix,
    required super.nextInvoiceNumber,
    required super.paymentTerms,
    required super.oneTapInvoiceEnabled,
    required super.smartPredictionEnabled,
    required super.biometricLockEnabled,
  });

  const AppPreferencesModel.defaults() : super.defaults();

  factory AppPreferencesModel.fromEntity(AppPreferences preferences) {
    return AppPreferencesModel(
      pushNotificationsEnabled: preferences.pushNotificationsEnabled,
      whatsAppRemindersEnabled: preferences.whatsAppRemindersEnabled,
      smsRemindersEnabled: preferences.smsRemindersEnabled,
      remind24HoursBefore: preferences.remind24HoursBefore,
      remind3HoursBefore: preferences.remind3HoursBefore,
      remindOnDueDate: preferences.remindOnDueDate,
      appLockEnabled: preferences.appLockEnabled,
      appLockPin: preferences.appLockPin,
      defaultCurrency: preferences.defaultCurrency,
      expenseCurrency: preferences.expenseCurrency,
      defaultTaxPercent: preferences.defaultTaxPercent,
      invoicePrefix: preferences.invoicePrefix,
      nextInvoiceNumber: preferences.nextInvoiceNumber,
      paymentTerms: preferences.paymentTerms,
      oneTapInvoiceEnabled: preferences.oneTapInvoiceEnabled,
      smartPredictionEnabled: preferences.smartPredictionEnabled,
      biometricLockEnabled: preferences.biometricLockEnabled,
    );
  }
}

class AppPreferencesModelAdapter extends TypeAdapter<AppPreferencesModel> {
  @override
  final int typeId = 8;

  @override
  AppPreferencesModel read(BinaryReader reader) {
    return AppPreferencesModel(
      pushNotificationsEnabled: reader.readBool(),
      whatsAppRemindersEnabled: reader.readBool(),
      smsRemindersEnabled: reader.readBool(),
      remind24HoursBefore: reader.readBool(),
      remind3HoursBefore: reader.readBool(),
      remindOnDueDate: reader.readBool(),
      appLockEnabled: reader.readBool(),
      appLockPin: reader.readString(),
      defaultCurrency: reader.readString(),
      defaultTaxPercent: reader.readDouble(),
      invoicePrefix: reader.readString(),
      paymentTerms: reader.read() as PaymentTermsOption,
      oneTapInvoiceEnabled: reader.readBool(),
      smartPredictionEnabled: reader.readBool(),
      nextInvoiceNumber: reader.availableBytes > 0 ? reader.readInt() : 1,
      biometricLockEnabled: reader.availableBytes > 0 ? reader.readBool() : false,
      expenseCurrency: reader.availableBytes > 0 ? reader.readString() : 'AED',
    );
  }

  @override
  void write(BinaryWriter writer, AppPreferencesModel obj) {
    writer
      ..writeBool(obj.pushNotificationsEnabled)
      ..writeBool(obj.whatsAppRemindersEnabled)
      ..writeBool(obj.smsRemindersEnabled)
      ..writeBool(obj.remind24HoursBefore)
      ..writeBool(obj.remind3HoursBefore)
      ..writeBool(obj.remindOnDueDate)
      ..writeBool(obj.appLockEnabled)
      ..writeString(obj.appLockPin)
      ..writeString(obj.defaultCurrency)
      ..writeDouble(obj.defaultTaxPercent)
      ..writeString(obj.invoicePrefix)
      ..write(obj.paymentTerms)
      ..writeBool(obj.oneTapInvoiceEnabled)
      ..writeBool(obj.smartPredictionEnabled)
      ..writeInt(obj.nextInvoiceNumber)
      ..writeBool(obj.biometricLockEnabled)
      ..writeString(obj.expenseCurrency);
  }
}
