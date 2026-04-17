class Payment {
  const Payment({
    required this.id,
    required this.amount,
    required this.date,
    this.note,
  });

  final String id;
  final double amount;
  final DateTime date;
  final String? note;
}
