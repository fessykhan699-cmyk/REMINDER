import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../features/clients/data/models/client_model.dart';
import '../../features/invoices/data/models/invoice_model.dart';
import '../../features/reminders/data/models/reminder_model.dart';
import '../../features/settings/data/models/profile_model.dart';
import '../../features/expenses/data/models/expense_model.dart';
import '../../core/storage/hive_storage.dart';

/// Firestore cloud backup/restore service.
///
/// - All writes are fire-and-forget with try/catch — Firestore errors never
///   surface to the user.
/// - Reads (restore) return normally; the caller decides what to do on error.
/// - isPro and userId are passed per-call so callers can gate sync without
///   coupling to Riverpod.
class FirestoreSyncService {
  FirestoreSyncService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  // ── Path helpers ──────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _invoices(String userId) =>
      _db.collection('users').doc(userId).collection('invoices');

  CollectionReference<Map<String, dynamic>> _clients(String userId) =>
      _db.collection('users').doc(userId).collection('clients');

  CollectionReference<Map<String, dynamic>> _reminders(String userId) =>
      _db.collection('users').doc(userId).collection('reminders');

  DocumentReference<Map<String, dynamic>> _profile(String userId) =>
      _db.collection('users').doc(userId).collection('profile').doc('data');

  CollectionReference<Map<String, dynamic>> _expenses(String userId) =>
      _db.collection('users').doc(userId).collection('expenses');

  // ── Write operations (fire-and-forget, never throws to caller) ────────────

  Future<void> syncInvoiceToCloud({
    required String userId,
    required bool isPro,
    required InvoiceModel invoice,
  }) async {
    if (!isPro) return;
    try {
      await _invoices(userId).doc(invoice.id).set(invoice.toJson());
    } catch (e, st) {
      debugPrint('[FirestoreSync] syncInvoiceToCloud failed: $e\n$st');
    }
  }

  Future<void> syncClientToCloud({
    required String userId,
    required bool isPro,
    required ClientModel client,
  }) async {
    if (!isPro) return;
    try {
      await _clients(userId).doc(client.id).set(client.toJson());
    } catch (e, st) {
      debugPrint('[FirestoreSync] syncClientToCloud failed: $e\n$st');
    }
  }

  Future<void> syncReminderToCloud({
    required String userId,
    required bool isPro,
    required ReminderModel reminder,
  }) async {
    if (!isPro) return;
    try {
      await _reminders(userId).doc(reminder.id).set(reminder.toJson());
    } catch (e, st) {
      debugPrint('[FirestoreSync] syncReminderToCloud failed: $e\n$st');
    }
  }

  Future<void> syncProfileToCloud({
    required String userId,
    required bool isPro,
    required ProfileModel profile,
  }) async {
    if (!isPro) return;
    try {
      await _profile(userId).set(profile.toJson());
    } catch (e, st) {
      debugPrint('[FirestoreSync] syncProfileToCloud failed: $e\n$st');
    }
  }

  Future<void> syncExpenseToCloud({
    required String userId,
    required bool isPro,
    required ExpenseModel expense,
  }) async {
    if (!isPro) return;
    try {
      await _expenses(userId).doc(expense.id).set(expense.toJson());
    } catch (e, st) {
      debugPrint('[FirestoreSync] syncExpenseToCloud failed: $e\n$st');
    }
  }

  Future<void> deleteInvoiceFromCloud({
    required String userId,
    required bool isPro,
    required String invoiceId,
  }) async {
    if (!isPro) return;
    try {
      await _invoices(userId).doc(invoiceId).delete();
    } catch (e, st) {
      debugPrint('[FirestoreSync] deleteInvoiceFromCloud failed: $e\n$st');
    }
  }

  Future<void> deleteClientFromCloud({
    required String userId,
    required bool isPro,
    required String clientId,
  }) async {
    if (!isPro) return;
    try {
      await _clients(userId).doc(clientId).delete();
    } catch (e, st) {
      debugPrint('[FirestoreSync] deleteClientFromCloud failed: $e\n$st');
    }
  }

  Future<void> deleteExpenseFromCloud({
    required String userId,
    required bool isPro,
    required String expenseId,
  }) async {
    if (!isPro) return;
    try {
      await _expenses(userId).doc(expenseId).delete();
    } catch (e, st) {
      debugPrint('[FirestoreSync] deleteExpenseFromCloud failed: $e\n$st');
    }
  }

  // ── Restore (pull from Firestore → write to Hive) ─────────────────────────

  /// Pulls all data for [userId] from Firestore into local Hive boxes.
  /// Skips if Hive already has invoices OR clients.
  Future<void> restoreAllFromCloud(String userId) async {
    try {
      final invoicesBox = Hive.box<InvoiceModel>(HiveStorage.invoicesBoxName);
      final clientsBox = Hive.box<ClientModel>(HiveStorage.clientsBoxName);

      if (invoicesBox.isNotEmpty || clientsBox.isNotEmpty) {
        debugPrint('[FirestoreSync] Hive has data — skipping restore.');
        return;
      }

      await Future.wait([
        _restoreInvoices(userId, invoicesBox),
        _restoreClients(userId, clientsBox),
        _restoreReminders(userId),
        _restoreProfile(userId),
        _restoreExpenses(userId),
      ]);

      debugPrint('[FirestoreSync] restoreAllFromCloud complete for $userId');
    } catch (e, st) {
      debugPrint('[FirestoreSync] restoreAllFromCloud failed: $e\n$st');
    }
  }

  Future<void> _restoreInvoices(
    String userId,
    Box<InvoiceModel> box,
  ) async {
    final snapshot = await _invoices(userId).get();
    for (final doc in snapshot.docs) {
      try {
        final model = InvoiceModel.fromJson(doc.data());
        await box.put(model.id, model);
      } catch (e) {
        debugPrint('[FirestoreSync] skipping malformed invoice ${doc.id}: $e');
      }
    }
  }

  Future<void> _restoreClients(
    String userId,
    Box<ClientModel> box,
  ) async {
    final snapshot = await _clients(userId).get();
    for (final doc in snapshot.docs) {
      try {
        final model = ClientModel.fromJson(doc.data());
        await box.put(model.id, model);
      } catch (e) {
        debugPrint('[FirestoreSync] skipping malformed client ${doc.id}: $e');
      }
    }
  }

  Future<void> _restoreReminders(String userId) async {
    final box = Hive.box<ReminderModel>(HiveStorage.remindersBoxName);
    final snapshot = await _reminders(userId).get();
    for (final doc in snapshot.docs) {
      try {
        final model = ReminderModel.fromJson(doc.data());
        await box.put(model.id, model);
      } catch (e) {
        debugPrint('[FirestoreSync] skipping malformed reminder ${doc.id}: $e');
      }
    }
  }

  Future<void> _restoreProfile(String userId) async {
    final doc = await _profile(userId).get();
    if (!doc.exists || doc.data() == null) return;
    try {
      final model = ProfileModel.fromJson(doc.data()!);
      // Write to the actual profile Hive box using the same key as SettingsLocalDatasource
      final settingsBox = Hive.box<dynamic>(HiveStorage.settingsBoxName);
      await settingsBox.put('currentUserProfile', model);
    } catch (e) {
      debugPrint('[FirestoreSync] skipping malformed profile: $e');
    }
  }

  Future<void> _restoreExpenses(String userId) async {
    final box = Hive.box<ExpenseModel>(HiveStorage.expensesBoxName);
    final snapshot = await _expenses(userId).get();
    for (final doc in snapshot.docs) {
      try {
        final model = ExpenseModel.fromJson(doc.data());
        await box.put(model.id, model);
      } catch (e) {
        debugPrint('[FirestoreSync] skipping malformed expense ${doc.id}: $e');
      }
    }
  }

  // ── Upload local Hive data to Firestore (used on Pro upgrade) ────────────

  /// Reads every local Hive record and writes to Firestore.
  /// Called once when a free user upgrades to Pro.
  Future<void> uploadLocalDataToCloud(String userId) async {
    try {
      final invoicesBox = Hive.box<InvoiceModel>(HiveStorage.invoicesBoxName);
      final clientsBox = Hive.box<ClientModel>(HiveStorage.clientsBoxName);
      final remindersBox =
          Hive.box<ReminderModel>(HiveStorage.remindersBoxName);

      WriteBatch batch = _db.batch();
      int opCount = 0;

      Future<void> flush() async {
        if (opCount == 0) return;
        await batch.commit();
        batch = _db.batch();
        opCount = 0;
      }

      for (final invoice in invoicesBox.values) {
        batch.set(_invoices(userId).doc(invoice.id), invoice.toJson());
        if (++opCount >= 490) await flush();
      }
      for (final client in clientsBox.values) {
        batch.set(_clients(userId).doc(client.id), client.toJson());
        if (++opCount >= 490) await flush();
      }
      for (final reminder in remindersBox.values) {
        batch.set(_reminders(userId).doc(reminder.id), reminder.toJson());
        if (++opCount >= 490) await flush();
      }
      final expensesBox = Hive.box<ExpenseModel>(HiveStorage.expensesBoxName);
      for (final expense in expensesBox.values) {
        batch.set(_expenses(userId).doc(expense.id), expense.toJson());
        if (++opCount >= 490) await flush();
      }
      await flush();

      debugPrint('[FirestoreSync] uploadLocalDataToCloud complete for $userId');
    } catch (e, st) {
      debugPrint('[FirestoreSync] uploadLocalDataToCloud failed: $e\n$st');
    }
  }
}
