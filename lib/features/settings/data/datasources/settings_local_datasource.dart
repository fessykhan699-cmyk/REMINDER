import '../models/profile_model.dart';

class SettingsLocalDatasource {
  Future<ProfileModel> getProfile() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));

    return const ProfileModel(
      name: 'Studio Owner',
      email: 'owner@studio.com',
      businessName: 'Studio Ledger Co.',
    );
  }
}
