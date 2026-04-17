import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> authenticate() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      if (!canCheck || !isSupported) {
        return true; // no hardware → never lock the user out
      }
      return await _auth.authenticate(
        localizedReason: 'Please authenticate to access Invoice Flow',
        options: const AuthenticationOptions(biometricOnly: false),
      );
    } catch (e) {
      debugPrint('[BiometricService] authenticate error: $e');
      return false;
    }
  }
}
