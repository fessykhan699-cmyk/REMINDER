class Client {
  const Client({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final DateTime createdAt;

  Client copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    DateTime? createdAt,
  }) {
    return Client(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static bool isValidEmail(String value) {
    final email = value.trim();
    return email.isNotEmpty && email.contains('@');
  }

  static bool hasValidInternationalPhone(String value) {
    final normalized = normalizePhone(value);
    final digits = normalized.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 8 && digits.length <= 15;
  }

  static String normalizePhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return '';
    }
    return '+$digits';
  }
}
