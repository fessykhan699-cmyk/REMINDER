class Payment {
  const Payment({
    required this.id,
    required this.amount,
    required this.date,
    this.note,
    this.paymentMethod,
  });

  final String id;
  final double amount;
  final DateTime date;
  final String? note;
  final String? paymentMethod;

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      note: json['note'] as String?,
      paymentMethod: json['paymentMethod'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'date': date.toIso8601String(),
      'note': note,
      'paymentMethod': paymentMethod,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Payment &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          amount == other.amount &&
          date == other.date &&
          note == other.note &&
          paymentMethod == other.paymentMethod;

  @override
  int get hashCode =>
      id.hashCode ^
      amount.hashCode ^
      date.hashCode ^
      note.hashCode ^
      paymentMethod.hashCode;
}
