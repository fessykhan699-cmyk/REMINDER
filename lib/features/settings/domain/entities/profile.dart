class UserProfile {
  const UserProfile({
    required this.name,
    required this.email,
    required this.businessName,
    required this.phone,
    required this.address,
  });

  const UserProfile.empty()
    : name = '',
      email = '',
      businessName = '',
      phone = '',
      address = '';

  static final RegExp _emailRegex = RegExp(
    r'^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$',
    caseSensitive: false,
  );

  final String name;
  final String email;
  final String businessName;
  final String phone;
  final String address;

  bool get hasAddress => address.trim().isNotEmpty;
  bool get isEmpty =>
      name.trim().isEmpty &&
      email.trim().isEmpty &&
      businessName.trim().isEmpty &&
      phone.trim().isEmpty &&
      address.trim().isEmpty;

  bool get isComplete =>
      name.trim().isNotEmpty &&
      businessName.trim().isNotEmpty &&
      isValidEmail(email) &&
      hasValidInternationalPhone(phone);

  UserProfile copyWith({
    String? name,
    String? email,
    String? businessName,
    String? phone,
    String? address,
  }) {
    return UserProfile(
      name: name ?? this.name,
      email: email ?? this.email,
      businessName: businessName ?? this.businessName,
      phone: phone ?? this.phone,
      address: address ?? this.address,
    );
  }

  static bool isValidEmail(String value) {
    return _emailRegex.hasMatch(value.trim());
  }

  static bool hasValidInternationalPhone(String value) {
    final trimmed = value.trim();
    if (!trimmed.startsWith('+')) {
      return false;
    }

    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 8 && digits.length <= 15;
  }
}
