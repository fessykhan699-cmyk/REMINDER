// ignore_for_file: overridden_fields
import 'package:hive/hive.dart';
import '../../domain/entities/payment.dart';

@HiveType(typeId: 10)
class PaymentModel extends Payment {
  const PaymentModel({
    required this.id,
    required this.amount,
    required this.date,
    this.note,
    this.paymentMethod,
  }) : super(
          id: id,
          amount: amount,
          date: date,
          note: note,
          paymentMethod: paymentMethod,
        );

  @override
  @HiveField(0)
  final String id;

  @override
  @HiveField(1)
  final double amount;

  @override
  @HiveField(2)
  final DateTime date;

  @override
  @HiveField(3)
  final String? note;

  @override
  @HiveField(4)
  final String? paymentMethod;

  factory PaymentModel.fromEntity(Payment payment) {
    return PaymentModel(
      id: payment.id,
      amount: payment.amount,
      date: payment.date,
      note: payment.note,
      paymentMethod: payment.paymentMethod,
    );
  }

  Payment toEntity() {
    return Payment(
      id: id,
      amount: amount,
      date: date,
      note: note,
      paymentMethod: paymentMethod,
    );
  }

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
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
}

class PaymentModelAdapter extends TypeAdapter<PaymentModel> {
  @override
  final int typeId = 10;

  @override
  PaymentModel read(BinaryReader reader) {
    final id = reader.readString();
    final amount = reader.readDouble();
    final date = DateTime.parse(reader.readString());
    final note = reader.availableBytes > 0 ? reader.readString() : null;
    final paymentMethod = reader.availableBytes > 0 ? reader.readString() : null;

    return PaymentModel(
      id: id,
      amount: amount,
      date: date,
      note: note?.isEmpty == true ? null : note,
      paymentMethod: paymentMethod?.isEmpty == true ? null : paymentMethod,
    );
  }

  @override
  void write(BinaryWriter writer, PaymentModel obj) {
    writer
      ..writeString(obj.id)
      ..writeDouble(obj.amount)
      ..writeString(obj.date.toIso8601String())
      ..writeString(obj.note ?? '')
      ..writeString(obj.paymentMethod ?? '');
  }
}
