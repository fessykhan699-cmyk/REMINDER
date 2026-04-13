class AppFormatters {
  AppFormatters._();

  static const Map<String, String> _currencySymbols = <String, String>{
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'INR': '₹',
    'AED': 'AED ',
    'SAR': 'SAR ',
    'PKR': '₨',
    'BDT': '৳',
    'NGN': '₦',
    'KES': 'KSh ',
    'GHS': 'GH₵',
    'ZAR': 'R',
    'EGP': 'EGP ',
    'MYR': 'RM',
    'SGD': 'S\$',
    'CAD': 'CA\$',
    'AUD': 'A\$',
  };

  // Maps international phone dial codes to ISO 4217 currency codes.
  static const Map<String, String> _phonePrefixToCurrency = <String, String>{
    '+971': 'AED', // UAE
    '+966': 'SAR', // Saudi Arabia
    '+974': 'QAR', // Qatar  (no symbol above, will fall back to 'QAR ')
    '+973': 'BHD', // Bahrain
    '+965': 'KWD', // Kuwait
    '+968': 'OMR', // Oman
    '+92': 'PKR',  // Pakistan
    '+91': 'INR',  // India
    '+880': 'BDT', // Bangladesh
    '+44': 'GBP',  // UK
    '+1': 'USD',   // US / Canada (ambiguous — default USD)
    '+61': 'AUD',  // Australia
    '+65': 'SGD',  // Singapore
    '+60': 'MYR',  // Malaysia
    '+234': 'NGN', // Nigeria
    '+254': 'KES', // Kenya
    '+233': 'GHS', // Ghana
    '+27': 'ZAR',  // South Africa
    '+20': 'EGP',  // Egypt
    '+49': 'EUR',  // Germany
    '+33': 'EUR',  // France
    '+39': 'EUR',  // Italy
    '+34': 'EUR',  // Spain
    '+31': 'EUR',  // Netherlands
  };

  /// Detects the most likely currency from a phone number (e.g. '+971501234567' → 'AED').
  /// Returns null if the prefix is not recognised.
  static String? currencyFromPhone(String phone) {
    final normalised = phone.trim();
    if (!normalised.startsWith('+')) return null;
    // Try longest prefix first to avoid '+1' matching '+1...' countries wrongly.
    final sortedPrefixes = _phonePrefixToCurrency.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final prefix in sortedPrefixes) {
      if (normalised.startsWith(prefix)) {
        return _phonePrefixToCurrency[prefix];
      }
    }
    return null;
  }

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
