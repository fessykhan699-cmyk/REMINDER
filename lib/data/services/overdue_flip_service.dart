import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'firestore_sync_service.dart';
import 'notification_service.dart';
import '../../features/invoices/data/models/invoice_model.dart';
import '../../features/invoices/domain/entities/invoice.dart';
import '../../core/storage/hive_storage.dart';

/// Service to automatically flip unpaid invoices to 'overdue' status.
class OverdueFlipService {
  final FirestoreSyncService _syncService;
  final FirebaseAuth _auth;

  OverdueFlipService({
    FirestoreSyncService? syncService,
    FirebaseAuth? auth,
  })  : _syncService = syncService ?? FirestoreSyncService(),
        _auth = auth ?? FirebaseAuth.instance;

  static const String _notifiedDateKey = 'overdue_notified_date';
  static const String _notifiedIdsKey = 'overdue_notified_ids';

  /// Scans all local invoices and flips unpaid ones to overdue if the due date has passed.
  /// Sends a notification once per overdue invoice per day.
  Future<void> flipOverdueInvoices() async {
    try {
      if (!Hive.isBoxOpen(HiveStorage.invoicesBoxName)) return;

      final box = Hive.box<InvoiceModel>(HiveStorage.invoicesBoxName);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final user = _auth.currentUser;
      final userId = user?.uid;


      // Load daily dedup state from Hive
      final notifiedIds = _loadNotifiedTodayIds(today);

      bool flippedAny = false;
      bool notifiedChanged = false;

      for (final invoice in box.values.toList()) {
        if (invoice.status == InvoiceStatus.paid) continue;

        final dueDate = DateTime(
          invoice.dueDate.year,
          invoice.dueDate.month,
          invoice.dueDate.day,
        );

        if (!dueDate.isBefore(today)) continue;

        InvoiceModel candidate = invoice;

        // Flip draft/sent/viewed → overdue
        if (invoice.status != InvoiceStatus.overdue) {
          candidate = invoice.copyWith(status: InvoiceStatus.overdue);
          await box.put(candidate.id, candidate);

          if (userId != null) {
            await _syncService.syncInvoiceToCloud(
              userId: userId,
              invoice: candidate,
            );
          }

          flippedAny = true;
          debugPrint('[OverdueFlip] Invoice ${candidate.id} flipped to overdue.');
        }

        // Notify once per invoice per day
        if (!notifiedIds.contains(candidate.id)) {
          await NotificationService.showOverdueNotification(candidate);
          notifiedIds.add(candidate.id);
          notifiedChanged = true;
        }
      }

      if (notifiedChanged) {
        _saveNotifiedTodayIds(today, notifiedIds);
      }

      if (flippedAny) {
        debugPrint('[OverdueFlip] Finished flipping invoices.');
      }
    } catch (e, st) {
      debugPrint('[OverdueFlip] Error during flip: $e\n$st');
    }
  }

  List<String> _loadNotifiedTodayIds(DateTime today) {
    return []; // TEMP TEST: bypass daily dedup — revert after testing
    // ignore: dead_code
    if (!Hive.isBoxOpen(HiveStorage.settingsBoxName)) return [];
    final box = Hive.box<dynamic>(HiveStorage.settingsBoxName);
    final todayStr = _dateKey(today);
    final savedDate = box.get(_notifiedDateKey) as String? ?? '';
    if (savedDate != todayStr) return [];
    final raw = box.get(_notifiedIdsKey);
    if (raw is! List) return [];
    return raw.cast<String>().toList();
  }

  void _saveNotifiedTodayIds(DateTime today, List<String> ids) {
    if (!Hive.isBoxOpen(HiveStorage.settingsBoxName)) return;
    final box = Hive.box<dynamic>(HiveStorage.settingsBoxName);
    box.put(_notifiedDateKey, _dateKey(today));
    box.put(_notifiedIdsKey, ids);
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
