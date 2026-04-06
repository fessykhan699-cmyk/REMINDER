import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/domain/usecases/get_profile_usecase.dart';
import '../../features/settings/presentation/controllers/settings_controller.dart';

final invoicePdfProfileHookProvider = Provider<InvoicePdfProfileHook>(
  (ref) => InvoicePdfProfileHook(ref.watch(getProfileUseCaseProvider)),
);

class InvoicePdfProfileHook {
  const InvoicePdfProfileHook(this._getProfileUseCase);

  final GetProfileUseCase _getProfileUseCase;

  Future<InvoicePdfSenderProfile?> loadSenderProfile() async {
    final profile = await _getProfileUseCase.call();
    if (profile.isEmpty) {
      return null;
    }

    return InvoicePdfSenderProfile(
      name: profile.name.trim(),
      businessName: profile.businessName.trim(),
      email: profile.email.trim(),
      phone: profile.phone.trim(),
      address: profile.address.trim(),
      logoPath: profile.logoPath.trim(),
      signaturePath: profile.signaturePath.trim(),
    );
  }
}

class InvoicePdfSenderProfile {
  const InvoicePdfSenderProfile({
    required this.name,
    required this.businessName,
    required this.email,
    required this.phone,
    required this.address,
    required this.logoPath,
    required this.signaturePath,
  });

  final String name;
  final String businessName;
  final String email;
  final String phone;
  final String address;
  final String logoPath;
  final String signaturePath;

  bool get hasCustomLogo => logoPath.trim().isNotEmpty;
  bool get hasSignature => signaturePath.trim().isNotEmpty;
  String? get normalizedLogoPath => hasCustomLogo ? logoPath.trim() : null;
  String? get normalizedSignaturePath =>
      hasSignature ? signaturePath.trim() : null;

  String get displayBusinessName {
    if (businessName.trim().isNotEmpty) {
      return businessName.trim();
    }
    if (name.trim().isNotEmpty) {
      return name.trim();
    }
    return 'Your Business';
  }

  Map<String, String> toPdfFromSection() {
    return <String, String>{
      'name': name,
      'businessName': businessName,
      'email': email,
      'phone': phone,
      'address': address,
      'logoPath': logoPath,
      'signaturePath': signaturePath,
    };
  }
}
