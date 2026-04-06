import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? get userId => _auth.currentUser?.uid;

  Future<void> signInAnonymously() async {
    if (_auth.currentUser != null) return;
    await _auth.signInAnonymously();
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;

  Future<DocumentReference> addReminder({
    required String title,
    required String description,
  }) async {
    final uid = userId;
    if (uid == null) {
      throw StateError('User not authenticated');
    }

    return _firestore.collection('reminders').add({
      'userId': uid,
      'title': title,
      'description': description,
      'createdAt': FieldValue.serverTimestamp(),
      'completed': false,
    });
  }

  Stream<QuerySnapshot> streamReminders() {
    final uid = userId;
    if (uid == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('reminders')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> updateReminder(String id, Map<String, dynamic> data) async {
    final uid = userId;
    if (uid == null) {
      throw StateError('User not authenticated');
    }

    await _firestore.collection('reminders').doc(id).update(data);
  }

  Future<void> deleteReminder(String id) async {
    final uid = userId;
    if (uid == null) {
      throw StateError('User not authenticated');
    }

    await _firestore.collection('reminders').doc(id).delete();
  }
}
