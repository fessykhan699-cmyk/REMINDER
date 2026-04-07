import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? get userId => _auth.currentUser?.uid;

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

  // Temporary: delete all reminders for the current user
  Future<void> deleteAllReminders() async {
    final uid = userId;
    if (uid == null) return;

    final snapshot = await _firestore
        .collection('reminders')
        .where('userId', isEqualTo: uid)
        .get();

    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
