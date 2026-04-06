import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/auth/firebase_auth_service.dart';
import '../../features/clients/data/models/client_model.dart';
import '../../features/invoices/data/models/invoice_model.dart';

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  String? get _uid => FirebaseAuthService.instance.getCurrentUserId();

  Future<void> syncClientToFirebase(ClientModel client) async {
    try {
      final uid = _uid;
      if (uid == null) return;
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('clients')
          .doc(client.id)
          .set(client.toJson());
    } catch (_) {}
  }

  Future<void> syncInvoiceToFirebase(InvoiceModel invoice) async {
    try {
      final uid = _uid;
      if (uid == null) return;
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('invoices')
          .doc(invoice.id)
          .set(invoice.toJson());
    } catch (_) {}
  }

  Future<void> deleteClientFromFirebase(String clientId) async {
    try {
      final uid = _uid;
      if (uid == null) return;
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('clients')
          .doc(clientId)
          .delete();
    } catch (_) {}
  }

  Future<void> deleteInvoiceFromFirebase(String invoiceId) async {
    try {
      final uid = _uid;
      if (uid == null) return;
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('invoices')
          .doc(invoiceId)
          .delete();
    } catch (_) {}
  }
}
