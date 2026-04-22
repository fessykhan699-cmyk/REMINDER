import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> authenticate({bool facePreferred = false}) async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      if (!canCheck || !isSupported) {
        return true; // no hardware → never lock the user out
      }
      return await _auth.authenticate(
        localizedReason: facePreferred
            ? 'Use face unlock to open Invoice Flow'
            : 'Authenticate to open Invoice Flow',
        authMessages: [
          AndroidAuthMessages(
            signInTitle: facePreferred ? 'Face Unlock' : 'Biometric Authentication',
            cancelButton: 'Cancel',
          ),
        ],
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (e) {
      debugPrint('[BiometricService] authenticate error: $e');
      return false;
    }
  }
}
