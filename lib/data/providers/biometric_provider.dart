import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/biometric_service.dart';

final biometricServiceProvider = Provider<BiometricService>(
  (ref) => BiometricService(),
);

final isBiometricLockedProvider = StateProvider<bool>((ref) => false);
