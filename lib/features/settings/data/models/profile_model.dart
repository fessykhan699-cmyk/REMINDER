import 'package:hive/hive.dart';

import '../../domain/entities/profile.dart';

class ProfileModel extends UserProfile {
  const ProfileModel({
    required super.name,
    required super.email,
    required super.businessName,
    required super.phone,
    required super.address,
    super.logoPath,
    super.signaturePath,
  });

  factory ProfileModel.fromEntity(UserProfile profile) {
    return ProfileModel(
      name: profile.name,
      email: profile.email,
      businessName: profile.businessName,
      phone: profile.phone,
      address: profile.address,
      logoPath: profile.logoPath,
      signaturePath: profile.signaturePath,
    );
  }
}

class ProfileModelAdapter extends TypeAdapter<ProfileModel> {
  @override
  final int typeId = 6;

  @override
  ProfileModel read(BinaryReader reader) {
    final name = reader.readString();
    final email = reader.readString();
    String businessName = '';
    String phone = '';
    String address = '';
    String logoPath = '';
    String signaturePath = '';

    if (reader.availableBytes > 0) {
      final thirdValue = reader.readString();
      if (reader.availableBytes > 0) {
        businessName = thirdValue;
        phone = reader.readString();
        address = reader.availableBytes > 0 ? reader.readString() : '';
        logoPath = reader.availableBytes > 0 ? reader.readString() : '';
        signaturePath = reader.availableBytes > 0 ? reader.readString() : '';
      } else {
        phone = thirdValue;
      }
    }

    return ProfileModel(
      name: name,
      email: email,
      businessName: businessName,
      phone: phone,
      address: address,
      logoPath: logoPath,
      signaturePath: signaturePath,
    );
  }

  @override
  void write(BinaryWriter writer, ProfileModel obj) {
    writer
      ..writeString(obj.name)
      ..writeString(obj.email)
      ..writeString(obj.businessName)
      ..writeString(obj.phone)
      ..writeString(obj.address)
      ..writeString(obj.logoPath)
      ..writeString(obj.signaturePath);
  }
}
