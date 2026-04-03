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
}
