import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();
  static const _channel = MethodChannel('com.apexmobilelabs.reminder/biometric');

  Future<bool> authenticate({
    bool facePreferred = false,
    bool fingerprintPreferred = false,
  }) async {
    try {
      if (facePreferred) {
        final result = await _channel.invokeMethod<bool>('authenticateFace');
        return result ?? false;
      }
      if (fingerprintPreferred) {
        final result = await _channel.invokeMethod<bool>('authenticateFingerprint');
        return result ?? false;
      }
      // fallback: generic biometric via local_auth
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      if (!canCheck || !isSupported) {
        return true;
      }
      return await _auth.authenticate(
        localizedReason: 'Authenticate to open Paydeck',
        authMessages: [
          AndroidAuthMessages(
            signInTitle: 'Biometric Authentication',
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
