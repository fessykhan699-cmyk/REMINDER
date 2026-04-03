class AppFormatters {
  AppFormatters._();

  static String currency(num amount) => '\$${amount.toStringAsFixed(2)}';

  static String shortDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
