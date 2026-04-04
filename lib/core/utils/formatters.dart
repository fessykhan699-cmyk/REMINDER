class AppFormatters {
  AppFormatters._();

  static const Map<String, String> _currencySymbols = <String, String>{
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'INR': '₹',
    'AED': 'AED ',
  };

  static String currency(
    num amount, {
    String currencyCode = 'USD',
    bool includeDecimals = true,
  }) {
    final normalizedCode = currencyCode.trim().toUpperCase();
    final symbol = _currencySymbols[normalizedCode] ?? '$normalizedCode ';
    final formattedAmount = includeDecimals
        ? amount.toStringAsFixed(2)
        : amount.toStringAsFixed(0);
    return '$symbol$formattedAmount';
  }

  static String shortDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
