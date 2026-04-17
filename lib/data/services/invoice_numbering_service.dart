import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/settings/domain/entities/app_preferences.dart';
import '../../features/settings/presentation/controllers/app_preferences_controller.dart';

final invoiceNumberingServiceProvider = Provider<InvoiceNumberingService>((ref) {
  return InvoiceNumberingService(ref);
});

class InvoiceNumberingService {
  InvoiceNumberingService(this._ref);

  final Ref _ref;

  /// Gets the next invoice number formatted as a string.
  /// Example: "INV-001"
  String getNextInvoiceNumber(AppPreferences prefs) {
    final numberText = prefs.nextInvoiceNumber.toString().padLeft(3, '0');
    return '${prefs.invoicePrefix}$numberText';
  }

  /// Increments the next invoice number in preferences.
  Future<void> incrementNextInvoiceNumber() async {
    await _ref.read(appPreferencesControllerProvider.notifier).patch(
          (current) => current.copyWith(
            nextInvoiceNumber: current.nextInvoiceNumber + 1,
          ),
        );
  }

  /// Parses an invoice number string to try and find the numeric part.
  /// This is useful if the user overrides the number and we want to 
  /// keep the counter in sync (optional/advanced).
  int? parseInvoiceNumber(String number) {
    final match = RegExp(r'(\d+)$').firstMatch(number);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }
}
