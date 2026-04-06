import 'package:firebase_auth/firebase_auth.dart';

class FirebaseAuthService {
  FirebaseAuthService._();
  static final FirebaseAuthService instance = FirebaseAuthService._();

  String? _uid;

  Future<void> signInAnonymously() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _uid = user.uid;
        return;
      }
      final credential = await FirebaseAuth.instance.signInAnonymously();
      _uid = credential.user?.uid;
    } catch (_) {
      _uid = null;
    }
  }

  String? getCurrentUserId() => _uid ?? FirebaseAuth.instance.currentUser?.uid;
}
