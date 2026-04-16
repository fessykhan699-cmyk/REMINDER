import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'firestore_sync_service.dart';
import 'notification_service.dart';
import '../../features/invoices/data/models/invoice_model.dart';
import '../../features/invoices/domain/entities/invoice.dart';
import '../../core/storage/hive_storage.dart';
import '../../features/subscription/data/datasources/subscription_local_datasource.dart';

/// Service to automatically flip unpaid invoices to 'overdue' status.
class OverdueFlipService {
  final FirestoreSyncService _syncService;
  final FirebaseAuth _auth;

  OverdueFlipService({
    FirestoreSyncService? syncService,
    FirebaseAuth? auth,
  })  : _syncService = syncService ?? FirestoreSyncService(),
        _auth = auth ?? FirebaseAuth.instance;

  /// Scans all local invoices and flips unpaid ones to overdue if the due date has passed.
  Future<void> flipOverdueInvoices() async {
    try {
      if (!Hive.isBoxOpen(HiveStorage.invoicesBoxName)) {
        return;
      }

      final box = Hive.box<InvoiceModel>(HiveStorage.invoicesBoxName);
      final invoices = box.values.toList();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      final user = _auth.currentUser;
      final userId = user?.uid;
      
      // Load subscription state for sync and notification gating
      final subscription = await const SubscriptionLocalDatasource().loadState();
      final isPro = subscription.isPro;

      bool flippedAny = false;

      for (final invoice in invoices) {
        // Only draft, sent, or viewed invoices can flip to overdue.
        // Paid and already overdue invoices are skipped.
        if (invoice.status == InvoiceStatus.paid || invoice.status == InvoiceStatus.overdue) {
          continue;
        }

        // Exact day comparison: ignore time
        final dueDate = DateTime(
          invoice.dueDate.year,
          invoice.dueDate.month,
          invoice.dueDate.day,
        );
        
        if (dueDate.isBefore(today)) {
          final updatedInvoice = invoice.copyWith(status: InvoiceStatus.overdue);
          
          // 1. Update Hive (Local Cache)
          await box.put(updatedInvoice.id, updatedInvoice);
          
          // 2. Sync to Cloud (if Pro)
          if (userId != null) {
            await _syncService.syncInvoiceToCloud(
              userId: userId,
              isPro: isPro,
              invoice: updatedInvoice,
            );
          }
          
          // 3. Trigger Notification (Gated by Pro inside the service)
          await NotificationService.showOverdueNotification(updatedInvoice);
          
          flippedAny = true;
          debugPrint('[OverdueFlip] Invoice ${updatedInvoice.id} flipped to overdue.');
        }
      }

      if (flippedAny) {
        debugPrint('[OverdueFlip] Finished flipping invoices.');
      }
    } catch (e, st) {
      debugPrint('[OverdueFlip] Error during flip: $e\n$st');
    }
  }
}
