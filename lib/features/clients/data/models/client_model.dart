// ignore_for_file: overridden_fields

import 'package:hive/hive.dart';

import '../../domain/entities/client.dart';

@HiveType(typeId: 0)
class ClientModel extends Client {
  const ClientModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.createdAt,
  }) : super(
         id: id,
         name: name,
         email: email,
         phone: phone,
         createdAt: createdAt,
       );

  @override
  @HiveField(0)
  final String id;

  @override
  @HiveField(1)
  final String name;

  @override
  @HiveField(2)
  final String email;

  @override
  @HiveField(3)
  final String phone;

  @override
  @HiveField(4)
  final DateTime createdAt;

  factory ClientModel.fromEntity(Client client) {
    return ClientModel(
      id: client.id,
      name: client.name,
      email: client.email,
      phone: client.phone,
      createdAt: client.createdAt,
    );
  }

  factory ClientModel.fromJson(Map<String, dynamic> json) {
    return ClientModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class ClientModelAdapter extends TypeAdapter<ClientModel> {
  @override
  final int typeId = 0;

  @override
  ClientModel read(BinaryReader reader) {
    return ClientModel(
      id: reader.readString(),
      name: reader.readString(),
      email: reader.readString(),
      phone: reader.readString(),
      createdAt: DateTime.parse(reader.readString()),
    );
  }

  @override
  void write(BinaryWriter writer, ClientModel obj) {
    writer
      ..writeString(obj.id)
      ..writeString(obj.name)
      ..writeString(obj.email)
      ..writeString(obj.phone)
      ..writeString(obj.createdAt.toIso8601String());
  }
}

