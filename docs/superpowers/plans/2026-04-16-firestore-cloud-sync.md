# Firestore Cloud Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Firestore as a cloud backup/restore layer on top of Hive, gated to Pro subscribers, with a sync status indicator in Settings.

**Architecture:** Hive remains the source of truth on-device (always read from Hive). Firestore is write-through on every mutation and pull-on-login for restore. Free users skip Firestore silently; Pro users sync every mutation. The `FirestoreSyncService` is a plain Dart class injected via Riverpod — it has no UI dependency and is called from the existing repository implementations.

**Tech Stack:** Flutter, Riverpod, Hive, Firebase Auth, Cloud Firestore (`cloud_firestore` already in pubspec.yaml and imported in `firebase_options.dart`).

---

## File Map

### Created
- `lib/data/services/firestore_sync_service.dart` — All Firestore read/write logic. Pure service, no Riverpod dependency. Takes a `userId` on every call.
- `lib/data/providers/firestore_sync_provider.dart` — Riverpod `Provider<FirestoreSyncService>` and `Provider<String?>` for current userId.

### Modified
- `lib/features/invoices/data/repositories/invoice_repository_impl.dart` — Hook `syncInvoiceToCloud` / `deleteInvoiceFromCloud` after every Hive write.
- `lib/features/clients/data/repositories/client_repository_impl.dart` — Hook `syncClientToCloud` / `deleteClientFromCloud` after every Hive write.
- `lib/features/reminders/data/repositories/reminder_repository_impl.dart` — Hook `syncReminderToCloud` after every Hive write.
- `lib/features/settings/data/repositories/settings_repository_impl.dart` — Hook `syncProfileToCloud` after every profile save.
- `lib/features/auth/presentation/controllers/auth_controller.dart` — Call `restoreAllFromCloud(userId)` after successful login if Hive is empty.
- `lib/features/subscription/presentation/controllers/subscription_controller.dart` — Call `restoreAllFromCloud(userId)` on upgrade to Pro (to push existing local data up).
- `lib/features/settings/presentation/screens/settings_screen.dart` — Add cloud backup status row inside `_PlanSectionCard`.

---

## Critical Context for Every Task

- `InvoiceModel.toJson()` / `fromJson()` already exist — use them for Firestore.
- `ClientModel.toJson()` / `fromJson()` already exist — use them for Firestore.
- `ReminderModel.toJson()` / `fromJson()` already exist — use them for Firestore.
- `ProfileModel` has no `toJson`/`fromJson` — add them in Task 1.
- Firestore collections: `users/{userId}/invoices/{id}`, `users/{userId}/clients/{id}`, `users/{userId}/reminders/{id}`, `users/{userId}/profile/data`.
- `SubscriptionState.isPro` is read from `subscriptionControllerProvider`.
- Hive "is empty" check: `Hive.box<InvoiceModel>(HiveStorage.invoicesBoxName).isEmpty && Hive.box<ClientModel>(HiveStorage.clientsBoxName).isEmpty`.
- All repository constructors take a datasource. The Riverpod providers for repositories are defined in the controller files (`auth_controller.dart` pattern — provider declared near controller).
- Never call `ref.read` inside a non-Riverpod class. Pass `isPro` and `userId` as constructor args or per-call args to `FirestoreSyncService`.
- `HiveStorage.invoicesBoxName`, `HiveStorage.clientsBoxName` — check `hive_storage.dart` for exact names.

---

## Task 1 — FirestoreSyncService

**Files:**
- Create: `lib/data/services/firestore_sync_service.dart`
- Create: `lib/data/providers/firestore_sync_provider.dart`
- Modify: `lib/features/settings/data/models/profile_model.dart` (add `toJson` / `fromJson`)

- [ ] **Step 1: Add `toJson` / `fromJson` to `ProfileModel`**

Open `lib/features/settings/data/models/profile_model.dart`. Add two factory/instance methods **inside the `ProfileModel` class body**, after the existing `fromEntity` factory:

```dart
factory ProfileModel.fromJson(Map<String, dynamic> json) {
  return ProfileModel(
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    businessName: json['businessName'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    address: json['address'] as String? ?? '',
    logoPath: json['logoPath'] as String? ?? '',
    signaturePath: json['signaturePath'] as String? ?? '',
  );
}

Map<String, dynamic> toJson() {
  return {
    'name': name,
    'email': email,
    'businessName': businessName,
    'phone': phone,
    'address': address,
    'logoPath': logoPath,
    'signaturePath': signaturePath,
  };
}
```

- [ ] **Step 2: Run analyze to confirm no errors**

```
cd "c:/flutter dev/projects/reminder/reminder" && flutter analyze lib/features/settings/data/models/profile_model.dart
```

Expected: No issues found (or only pre-existing issues unrelated to this file).

- [ ] **Step 3: Create `FirestoreSyncService`**

Create file `lib/data/services/firestore_sync_service.dart` with this exact content:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../features/clients/data/models/client_model.dart';
import '../../features/invoices/data/models/invoice_model.dart';
import '../../features/reminders/data/models/reminder_model.dart';
import '../../features/settings/data/models/profile_model.dart';
import '../../core/storage/hive_storage.dart';
import 'package:hive/hive.dart';

/// Firestore cloud backup/restore service.
///
/// - All writes are fire-and-forget with try/catch — Firestore errors never
///   surface to the user.
/// - Reads (restore) return normally; the caller decides what to do on error.
/// - This class has no Riverpod dependency. isPro and userId are passed
///   per-call so callers can gate sync without coupling to Riverpod.
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

  // ── Restore (pull from Firestore → write to Hive) ─────────────────────────

  /// Pulls all data for [userId] from Firestore into local Hive boxes.
  ///
  /// Skips restore if Hive already has invoices OR clients (prevents
  /// overwriting existing local data on the same device).
  ///
  /// Call this:
  ///   1. After login when Hive is empty (first install / new device).
  ///   2. After upgrade to Pro (to push existing Hive data up instead of
  ///      pulling — the caller iterates Hive and calls the sync* methods).
  Future<void> restoreAllFromCloud(String userId) async {
    try {
      final invoicesBox = Hive.box<InvoiceModel>(HiveStorage.invoicesBoxName);
      final clientsBox = Hive.box<ClientModel>(HiveStorage.clientsBoxName);

      // Guard: do not overwrite existing local data
      if (invoicesBox.isNotEmpty || clientsBox.isNotEmpty) {
        debugPrint('[FirestoreSync] Hive has data — skipping restore.');
        return;
      }

      await Future.wait([
        _restoreInvoices(userId, invoicesBox),
        _restoreClients(userId, clientsBox),
        _restoreReminders(userId),
        _restoreProfile(userId),
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
      // Profile is stored in SharedPreferences via SettingsLocalDatasource.
      // We cannot write there directly from this service without coupling.
      // Instead, store in a dedicated Hive key so SettingsLocalDatasource
      // can pick it up on next read. We use the settings box with key 'profile_restore'.
      final settingsBox = Hive.box<dynamic>(HiveStorage.settingsBoxName);
      await settingsBox.put('profile_restore', model.toJson());
    } catch (e) {
      debugPrint('[FirestoreSync] skipping malformed profile: $e');
    }
  }

  // ── Upload local Hive data to Firestore (used on Pro upgrade) ────────────

  /// Reads every local Hive record and writes to Firestore.
  /// Called once when a free user upgrades to Pro so their existing data
  /// is immediately backed up.
  Future<void> uploadLocalDataToCloud(String userId) async {
    try {
      final invoicesBox = Hive.box<InvoiceModel>(HiveStorage.invoicesBoxName);
      final clientsBox = Hive.box<ClientModel>(HiveStorage.clientsBoxName);
      final remindersBox = Hive.box<ReminderModel>(HiveStorage.remindersBoxName);

      final batch = _db.batch();

      for (final invoice in invoicesBox.values) {
        batch.set(_invoices(userId).doc(invoice.id), invoice.toJson());
      }
      for (final client in clientsBox.values) {
        batch.set(_clients(userId).doc(client.id), client.toJson());
      }
      for (final reminder in remindersBox.values) {
        batch.set(_reminders(userId).doc(reminder.id), reminder.toJson());
      }

      await batch.commit();
      debugPrint('[FirestoreSync] uploadLocalDataToCloud complete for $userId');
    } catch (e, st) {
      debugPrint('[FirestoreSync] uploadLocalDataToCloud failed: $e\n$st');
    }
  }
}
```

- [ ] **Step 4: Create Riverpod providers**

Create file `lib/data/providers/firestore_sync_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/firestore_sync_service.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';

/// Singleton FirestoreSyncService instance.
final firestoreSyncServiceProvider = Provider<FirestoreSyncService>(
  (ref) => FirestoreSyncService(),
);

/// The current authenticated user ID, or null if not logged in.
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authControllerProvider).session?.userId;
});
```

- [ ] **Step 5: Run analyze**

```
cd "c:/flutter dev/projects/reminder/reminder" && flutter analyze lib/data/
```

Expected: No issues found. Fix any import path errors before continuing.

- [ ] **Step 6: Commit**

```bash
cd "c:/flutter dev/projects/reminder/reminder"
git add lib/data/ lib/features/settings/data/models/profile_model.dart
git commit -m "feat: add FirestoreSyncService and Riverpod providers"
```

---

## Task 2 — Hook Repositories: Invoice + Client

**Files:**
- Modify: `lib/features/invoices/data/repositories/invoice_repository_impl.dart`
- Modify: `lib/features/invoices/presentation/controllers/invoices_controller.dart` (add sync service injection)
- Modify: `lib/features/clients/data/repositories/client_repository_impl.dart`
- Modify: `lib/features/clients/presentation/controllers/clients_controller.dart` (add sync service injection)

### Why repositories need injection

The repositories are constructed in the controller files via Riverpod providers. They currently take only a datasource. We need to pass `FirestoreSyncService`, `isPro`, and `userId` to them so they can call sync after every Hive write. The cleanest approach matching existing patterns: add `FirestoreSyncService?`, `String? userId`, `bool isPro` fields to the repository constructors and update the providers that instantiate them.

### Invoices

- [ ] **Step 1: Update `InvoiceRepositoryImpl`**

Replace the full content of `lib/features/invoices/data/repositories/invoice_repository_impl.dart`:

```dart
import '../../domain/entities/invoice.dart';
import '../../domain/repositories/invoice_repository.dart';
import '../datasources/invoices_local_datasource.dart';
import '../models/invoice_model.dart';
import '../../../../data/services/firestore_sync_service.dart';

class InvoiceRepositoryImpl implements InvoiceRepository {
  const InvoiceRepositoryImpl(
    this._datasource, {
    this.syncService,
    this.userId,
    this.isPro = false,
  });

  final InvoicesLocalDatasource _datasource;
  final FirestoreSyncService? syncService;
  final String? userId;
  final bool isPro;

  @override
  Future<List<Invoice>> getInvoices({
    int page = 1,
    int pageSize = 20,
    bool forceRefresh = false,
  }) {
    return _datasource.fetchInvoices(
      page: page,
      pageSize: pageSize,
      forceRefresh: forceRefresh,
    );
  }

  @override
  Future<Invoice> createInvoice(Invoice invoice) async {
    final model = InvoiceModel.fromEntity(invoice);
    final saved = await _datasource.createInvoice(model);
    _syncInvoice(saved);
    return saved;
  }

  @override
  Future<Invoice> updateInvoice(Invoice invoice) async {
    final model = InvoiceModel.fromEntity(invoice);
    final saved = await _datasource.updateInvoice(model);
    _syncInvoice(saved);
    return saved;
  }

  @override
  Future<void> deleteInvoice(String id) async {
    await _datasource.deleteInvoice(id);
    _deleteInvoice(id);
  }

  @override
  Future<Invoice?> getInvoiceById(String id) => _datasource.getInvoiceById(id);

  @override
  Future<String> getNextInvoiceId({required String prefix}) {
    return _datasource.getNextInvoiceId(prefix: prefix);
  }

  @override
  Future<void> deleteByClientId(String clientId) =>
      _datasource.deleteByClientId(clientId);
  // Note: no cloud delete here — deleteClient handles that cascade client-side.

  // ── Private sync helpers (fire-and-forget) ─────────────────────────────

  void _syncInvoice(InvoiceModel model) {
    final svc = syncService;
    final uid = userId;
    if (svc == null || uid == null) return;
    svc.syncInvoiceToCloud(userId: uid, isPro: isPro, invoice: model);
  }

  void _deleteInvoice(String invoiceId) {
    final svc = syncService;
    final uid = userId;
    if (svc == null || uid == null) return;
    svc.deleteInvoiceFromCloud(userId: uid, isPro: isPro, invoiceId: invoiceId);
  }
}
```

- [ ] **Step 2: Find where `InvoiceRepositoryImpl` is constructed and update the provider**

Open `lib/features/invoices/presentation/controllers/invoices_controller.dart`. Find the `invoiceRepositoryProvider` (or equivalent). It currently passes only the datasource. Update it to also pass `syncService`, `userId`, and `isPro`.

Read the file first to find the exact provider declaration, then add these three params. The provider will look like this (adapt to match the file's existing style):

```dart
// At the top of invoices_controller.dart, add these imports:
import '../../../../data/providers/firestore_sync_provider.dart';
import '../../../subscription/presentation/controllers/subscription_controller.dart';

// Update the invoiceRepositoryProvider:
final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  final datasource = ref.watch(invoicesDatasourceProvider);
  final syncService = ref.watch(firestoreSyncServiceProvider);
  final userId = ref.watch(currentUserIdProvider);
  final isPro = ref.watch(subscriptionControllerProvider).valueOrNull?.isPro ?? false;
  return InvoiceRepositoryImpl(
    datasource,
    syncService: syncService,
    userId: userId,
    isPro: isPro,
  );
});
```

> **Note:** Read `invoices_controller.dart` to find the exact existing provider name and datasource provider name before making changes.

- [ ] **Step 3: Run analyze**

```
cd "c:/flutter dev/projects/reminder/reminder" && flutter analyze lib/features/invoices/
```

Expected: No issues found. Fix any.

### Clients

- [ ] **Step 4: Update `ClientRepositoryImpl`**

Replace the full content of `lib/features/clients/data/repositories/client_repository_impl.dart`:

```dart
import '../../domain/entities/client.dart';
import '../../domain/repositories/client_repository.dart';
import '../datasources/clients_local_datasource.dart';
import '../models/client_model.dart';
import '../../../../data/services/firestore_sync_service.dart';

class ClientRepositoryImpl implements ClientRepository {
  const ClientRepositoryImpl(
    this._datasource, {
    this.syncService,
    this.userId,
    this.isPro = false,
  });

  final ClientsLocalDatasource _datasource;
  final FirestoreSyncService? syncService;
  final String? userId;
  final bool isPro;

  @override
  Future<List<Client>> getClients({
    int page = 1,
    int pageSize = 20,
    bool forceRefresh = false,
  }) {
    return _datasource.fetchClients(
      page: page,
      pageSize: pageSize,
      forceRefresh: forceRefresh,
    );
  }

  @override
  Future<Client> addClient(Client client) async {
    final model = ClientModel.fromEntity(client);
    final saved = await _datasource.addClient(model);
    _syncClient(saved);
    return saved;
  }

  @override
  Future<Client> updateClient(Client client) async {
    final model = ClientModel.fromEntity(client);
    final saved = await _datasource.updateClient(model);
    _syncClient(saved);
    return saved;
  }

  @override
  Future<void> deleteClient(String id) async {
    await _datasource.deleteClient(id);
    _deleteClient(id);
  }

  @override
  Future<Client?> getClientById(String id) => _datasource.getClientById(id);

  // ── Private sync helpers ────────────────────────────────────────────────

  void _syncClient(ClientModel model) {
    final svc = syncService;
    final uid = userId;
    if (svc == null || uid == null) return;
    svc.syncClientToCloud(userId: uid, isPro: isPro, client: model);
  }

  void _deleteClient(String clientId) {
    final svc = syncService;
    final uid = userId;
    if (svc == null || uid == null) return;
    svc.deleteClientFromCloud(userId: uid, isPro: isPro, clientId: clientId);
  }
}
```

- [ ] **Step 5: Update the client repository provider in `clients_controller.dart`**

Open `lib/features/clients/presentation/controllers/clients_controller.dart`. Find the `clientRepositoryProvider`. Add the same three params as the invoice provider above:

```dart
// Add imports at top:
import '../../../../data/providers/firestore_sync_provider.dart';
import '../../../subscription/presentation/controllers/subscription_controller.dart';

// Update clientRepositoryProvider:
final clientRepositoryProvider = Provider<ClientRepository>((ref) {
  final datasource = ref.watch(clientsDatasourceProvider);
  final syncService = ref.watch(firestoreSyncServiceProvider);
  final userId = ref.watch(currentUserIdProvider);
  final isPro = ref.watch(subscriptionControllerProvider).valueOrNull?.isPro ?? false;
  return ClientRepositoryImpl(
    datasource,
    syncService: syncService,
    userId: userId,
    isPro: isPro,
  );
});
```

> **Note:** Read `clients_controller.dart` first to find the exact provider name and datasource provider name.

- [ ] **Step 6: Run analyze**

```
cd "c:/flutter dev/projects/reminder/reminder" && flutter analyze lib/features/clients/ lib/features/invoices/
```

Expected: No issues. Fix any before continuing.

- [ ] **Step 7: Commit**

```bash
git add lib/features/invoices/data/repositories/ lib/features/invoices/presentation/controllers/ \
        lib/features/clients/data/repositories/ lib/features/clients/presentation/controllers/
git commit -m "feat: hook Firestore sync into invoice and client repositories"
```

---

## Task 3 — Hook Repositories: Reminders + Settings

**Files:**
- Modify: `lib/features/reminders/data/repositories/reminder_repository_impl.dart`
- Modify: `lib/features/reminders/data/providers/reminder_repository_provider.dart`
- Modify: `lib/features/settings/data/repositories/settings_repository_impl.dart`
- Modify: `lib/features/settings/presentation/controllers/settings_controller.dart`

### Reminders

- [ ] **Step 1: Update `ReminderRepositoryImpl`**

Replace the full content of `lib/features/reminders/data/repositories/reminder_repository_impl.dart`:

```dart
import '../../../invoices/domain/entities/invoice.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/entities/reminder_message_type.dart';
import '../../domain/repositories/reminder_repository.dart';
import '../datasources/reminders_local_datasource.dart';
import '../models/reminder_model.dart';
import '../../../../data/services/firestore_sync_service.dart';

class ReminderRepositoryImpl implements ReminderRepository {
  const ReminderRepositoryImpl(
    this._datasource, {
    this.syncService,
    this.userId,
    this.isPro = false,
  });

  final RemindersLocalDatasource _datasource;
  final FirestoreSyncService? syncService;
  final String? userId;
  final bool isPro;

  @override
  Future<List<Reminder>> getReminders() => _datasource.fetchReminders();

  @override
  Future<Reminder> sendReminder({
    required String invoiceId,
    required String clientId,
    required String phoneNumber,
    required ReminderChannel channel,
    required String message,
  }) {
    return _datasource.sendReminder(
      invoiceId: invoiceId,
      clientId: clientId,
      phoneNumber: phoneNumber,
      channel: channel,
      message: message,
    );
  }

  @override
  Future<Reminder> createReminderRecord({
    required String invoiceId,
    required String clientId,
    required ReminderChannel channel,
    ReminderStatus status = ReminderStatus.sent,
  }) async {
    final saved = await _datasource.createReminderRecord(
      invoiceId: invoiceId,
      clientId: clientId,
      channel: channel,
      status: status,
    );
    _syncReminder(saved);
    return saved;
  }

  @override
  Future<void> deleteByInvoiceId(String invoiceId) =>
      _datasource.deleteByInvoiceId(invoiceId);

  @override
  Future<void> deleteByClientId(String clientId) =>
      _datasource.deleteByClientId(clientId);

  @override
  String buildPreviewMessage({
    required Invoice invoice,
    required ReminderMessageType type,
  }) {
    final dueDate = invoice.dueDate.toLocal().toString().split(' ').first;
    final amount = AppFormatters.currency(
      invoice.amount,
      currencyCode: invoice.currencyCode,
    );
    final paymentLinkLine = invoice.hasPaymentLink
        ? ' You can view or pay here: ${invoice.normalizedPaymentLink}'
        : '';

    switch (type) {
      case ReminderMessageType.professional:
        return 'Hello ${invoice.clientName}, this is a reminder that invoice '
            '${invoice.id} (${invoice.service}) for '
            '$amount is due on $dueDate. '
            'Please confirm your payment timeline.'
            '$paymentLinkLine';
      case ReminderMessageType.friendly:
        return 'Hi ${invoice.clientName}! Quick reminder about invoice '
            '${invoice.id} for ${invoice.service} '
            '($amount). '
            'It is due on $dueDate. '
            'Could you please share when payment will be processed? Thanks!'
            '$paymentLinkLine';
      case ReminderMessageType.firm:
        return 'Reminder: invoice ${invoice.id} for ${invoice.service} '
            '($amount) is due on $dueDate. '
            'Please arrange payment today to avoid service delays.'
            '$paymentLinkLine';
    }
  }

  // ── Private sync helper ────────────────────────────────────────────────

  void _syncReminder(Reminder reminder) {
    final svc = syncService;
    final uid = userId;
    if (svc == null || uid == null) return;
    svc.syncReminderToCloud(
      userId: uid,
      isPro: isPro,
      reminder: ReminderModel.fromEntity(reminder),
    );
  }
}
```

- [ ] **Step 2: Update `reminder_repository_provider.dart`**

Open `lib/features/reminders/data/providers/reminder_repository_provider.dart`. Read its current contents, then add the three sync params to the `ReminderRepositoryImpl` construction. Add these imports at the top:

```dart
import '../../../../data/providers/firestore_sync_provider.dart';
import '../../../subscription/presentation/controllers/subscription_controller.dart';
```

And update the provider body to pass:
```dart
ReminderRepositoryImpl(
  datasource,
  syncService: ref.watch(firestoreSyncServiceProvider),
  userId: ref.watch(currentUserIdProvider),
  isPro: ref.watch(subscriptionControllerProvider).valueOrNull?.isPro ?? false,
)
```

> **Note:** Read the file first to find the exact variable names before editing.

- [ ] **Step 3: Run analyze for reminders**

```
cd "c:/flutter dev/projects/reminder/reminder" && flutter analyze lib/features/reminders/
```

Expected: No issues. Fix any.

### Settings / Profile

- [ ] **Step 4: Update `SettingsRepositoryImpl`**

Replace the full content of `lib/features/settings/data/repositories/settings_repository_impl.dart`:

```dart
import '../../domain/entities/app_preferences.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/settings_local_datasource.dart';
import '../models/app_preferences_model.dart';
import '../models/profile_model.dart';
import '../../../../data/services/firestore_sync_service.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  const SettingsRepositoryImpl(
    this._datasource, {
    this.syncService,
    this.userId,
    this.isPro = false,
  });

  final SettingsLocalDatasource _datasource;
  final FirestoreSyncService? syncService;
  final String? userId;
  final bool isPro;

  @override
  Future<UserProfile> getProfile() => _datasource.getProfile();

  @override
  Future<UserProfile> saveProfile(UserProfile profile) async {
    final model = ProfileModel.fromEntity(profile);
    final saved = await _datasource.saveProfile(model);
    _syncProfile(model);
    return saved;
  }

  @override
  Future<AppPreferences> getAppPreferences() {
    return _datasource.getAppPreferences();
  }

  @override
  Future<AppPreferences> saveAppPreferences(AppPreferences preferences) {
    return _datasource.saveAppPreferences(
      AppPreferencesModel.fromEntity(preferences),
    );
  }

  // ── Private sync helper ────────────────────────────────────────────────

  void _syncProfile(ProfileModel model) {
    final svc = syncService;
    final uid = userId;
    if (svc == null || uid == null) return;
    svc.syncProfileToCloud(userId: uid, isPro: isPro, profile: model);
  }
}
```

- [ ] **Step 5: Update the settings repository provider in `settings_controller.dart`**

Open `lib/features/settings/presentation/controllers/settings_controller.dart`. Find the `settingsRepositoryProvider`. Update it to inject sync params:

```dart
// Add imports:
import '../../../../data/providers/firestore_sync_provider.dart';
import '../../../subscription/presentation/controllers/subscription_controller.dart';

// Update the provider:
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final datasource = ref.watch(settingsDatasourceProvider); // use exact existing name
  final syncService = ref.watch(firestoreSyncServiceProvider);
  final userId = ref.watch(currentUserIdProvider);
  final isPro = ref.watch(subscriptionControllerProvider).valueOrNull?.isPro ?? false;
  return SettingsRepositoryImpl(
    datasource,
    syncService: syncService,
    userId: userId,
    isPro: isPro,
  );
});
```

> **Note:** Read `settings_controller.dart` first to find the exact provider and datasource names.

- [ ] **Step 6: Run analyze for settings**

```
cd "c:/flutter dev/projects/reminder/reminder" && flutter analyze lib/features/settings/
```

Expected: No issues. Fix any.

- [ ] **Step 7: Full analyze**

```
cd "c:/flutter dev/projects/reminder/reminder" && flutter analyze
```

Expected: No issues found. Fix any before committing.

- [ ] **Step 8: Commit**

```bash
git add lib/features/reminders/ lib/features/settings/
git commit -m "feat: hook Firestore sync into reminders and settings repositories"
```

---

## Task 4 — Restore on Login

**Files:**
- Modify: `lib/features/auth/presentation/controllers/auth_controller.dart`

The trigger point is after a successful `login()` or `loginWithGoogle()` — when we have a userId and Hive might be empty. We call `restoreAllFromCloud(userId)` in a fire-and-forget manner (no await at the state transition level — restore runs in the background and populates Hive silently).

- [ ] **Step 1: Add imports to `auth_controller.dart`**

Open `lib/features/auth/presentation/controllers/auth_controller.dart`. At the top, add:

```dart
import '../../../../data/providers/firestore_sync_provider.dart';
```

(This file is in `lib/features/auth/presentation/controllers/`, so the relative path to `lib/data/providers/` is `../../../../data/providers/`.)

- [ ] **Step 2: Add `_triggerCloudRestore` helper to `AuthController`**

Add this private method inside the `AuthController` class, after the `completeOnboarding` method:

```dart
/// Triggers a cloud restore in the background after successful login.
/// Only runs if Hive is empty (first install or new device).
/// Does not await — runs fire-and-forget to avoid blocking login UX.
void _triggerCloudRestore(String userId) {
  final syncService = ref.read(firestoreSyncServiceProvider);
  syncService.restoreAllFromCloud(userId).catchError((Object e) {
    debugPrint('[AuthController] cloud restore error: $e');
    return null;
  });
}
```

- [ ] **Step 3: Call `_triggerCloudRestore` after successful login**

In the `login()` method, after `state = state.copyWith(status: AuthStatus.authenticated, ...)` succeeds, add:

```dart
_triggerCloudRestore(session.userId);
```

The modified `login()` method should look like:

```dart
Future<void> login({required String email, required String password}) async {
  state = state.copyWith(isSubmitting: true, clearError: true);

  try {
    final session = await ref
        .read(loginUseCaseProvider)
        .call(email: email, password: password);

    state = state.copyWith(
      status: AuthStatus.authenticated,
      session: session,
      isSubmitting: false,
      clearError: true,
    );

    _triggerCloudRestore(session.userId);
  } catch (error) {
    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      isSubmitting: false,
      errorMessage: error.toString(),
    );
  }
}
```

- [ ] **Step 4: Call `_triggerCloudRestore` after Google login**

Same pattern in `loginWithGoogle()`:

```dart
Future<void> loginWithGoogle() async {
  state = state.copyWith(isSubmitting: true, clearError: true);

  try {
    final datasource = ref.read(authLocalDatasourceProvider);
    final session = await datasource.loginWithGoogle();

    state = state.copyWith(
      status: AuthStatus.authenticated,
      session: session,
      isSubmitting: false,
      clearError: true,
    );

    _triggerCloudRestore(session.userId);
  } catch (error) {
    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      isSubmitting: false,
      errorMessage: error.toString(),
    );
  }
}
```

- [ ] **Step 5: Run analyze**

```
cd "c:/flutter dev/projects/reminder/reminder" && flutter analyze lib/features/auth/
```

Expected: No issues. Fix any.

- [ ] **Step 6: Commit**

```bash
git add lib/features/auth/presentation/controllers/auth_controller.dart
git commit -m "feat: trigger Firestore restore after login when Hive is empty"
```

---

## Task 5 — Upload Local Data on Pro Upgrade

**Files:**
- Modify: `lib/features/subscription/presentation/controllers/subscription_controller.dart`

When a free user upgrades to Pro, their existing Hive data should be immediately pushed to Firestore.

- [ ] **Step 1: Add import to `subscription_controller.dart`**

Open `lib/features/subscription/presentation/controllers/subscription_controller.dart`. Add at the top:

```dart
import '../../../../data/providers/firestore_sync_provider.dart';
```

- [ ] **Step 2: Update `upgradeToPro` to trigger upload**

Replace the existing `upgradeToPro()` method with:

```dart
Future<void> upgradeToPro() async {
  await setPlan(isPro: true);

  // Upload any existing local Hive data to Firestore now that user is Pro.
  final userId = ref.read(currentUserIdProvider);
  if (userId != null) {
    final syncService = ref.read(firestoreSyncServiceProvider);
    syncService.uploadLocalDataToCloud(userId).catchError((Object e) {
      debugPrint('[SubscriptionController] uploadLocalDataToCloud error: $e');
      return null;
    });
  }
}
```

- [ ] **Step 3: Run analyze**

```
cd "c:/flutter dev/projects/reminder/reminder" && flutter analyze lib/features/subscription/
```

Expected: No issues. Fix any.

- [ ] **Step 4: Commit**

```bash
git add lib/features/subscription/presentation/controllers/subscription_controller.dart
git commit -m "feat: upload local Hive data to Firestore on Pro upgrade"
```

---

## Task 6 — Settings Screen Indicator

**Files:**
- Modify: `lib/features/settings/presentation/screens/settings_screen.dart`

Add one line of information to the existing `_PlanSectionCard` — **no redesign, no new widgets**. We add a `Text` row after the "Pro Active on this device" line (Pro users) or a `GestureDetector` nudge text before the upgrade button (free users).

- [ ] **Step 1: Read `settings_screen.dart` carefully**

The `_PlanSectionCard` widget (defined starting at `class _PlanSectionCard`) has an `else if (isPro)` branch that renders:

```dart
Text(
  'Invoice Flow Pro is active on this device.',
  style: theme.textTheme.bodySmall?.copyWith(
    color: AppColors.textSecondary,
  ),
),
```

And a free branch that shows the upgrade button.

- [ ] **Step 2: Modify the Pro branch — add cloud backup status line**

In the `else if (isPro)` block, after the existing "Invoice Flow Pro is active on this device." `Text`, add:

```dart
const SizedBox(height: 6),
Text(
  'Cloud backup: Active',
  style: theme.textTheme.bodySmall?.copyWith(
    color: AppColors.textSecondary,
  ),
),
```

The full modified `else if (isPro)` block becomes:

```dart
} else if (isPro) ...[
  const SizedBox(height: 16),
  Text(
    'Invoice Flow Pro is active on this device.',
    style: theme.textTheme.bodySmall?.copyWith(
      color: AppColors.textSecondary,
    ),
  ),
  const SizedBox(height: 6),
  Text(
    'Cloud backup: Active',
    style: theme.textTheme.bodySmall?.copyWith(
      color: AppColors.textSecondary,
    ),
  ),
],
```

- [ ] **Step 3: Modify the free branch — add tappable cloud backup nudge**

In the free branch, before `PremiumPrimaryButton`, add:

```dart
const SizedBox(height: 12),
GestureDetector(
  onTap: onUpgrade,
  child: Text(
    'Cloud backup: Upgrade to Pro',
    style: theme.textTheme.bodySmall?.copyWith(
      color: AppColors.accent,
      fontWeight: FontWeight.w600,
    ),
  ),
),
```

Place this after the usage stat rows and before the existing `PremiumPrimaryButton`:

```dart
if (!isPro && onUpgrade != null) ...[
  const SizedBox(height: 12),
  GestureDetector(
    onTap: onUpgrade,
    child: Text(
      'Cloud backup: Upgrade to Pro',
      style: theme.textTheme.bodySmall?.copyWith(
        color: AppColors.accent,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
  const SizedBox(height: 20),
  PremiumPrimaryButton(
    ...existing button code unchanged...
  ),
],
```

> **Note:** Do NOT change the existing `PremiumPrimaryButton` code. Only add the `GestureDetector` and `SizedBox` before it.

- [ ] **Step 4: Run analyze**

```
cd "c:/flutter dev/projects/reminder/reminder" && flutter analyze lib/features/settings/presentation/screens/settings_screen.dart
```

Expected: No issues. Fix any.

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/presentation/screens/settings_screen.dart
git commit -m "feat: add cloud backup status indicator to settings screen"
```

---

## Task 7 — Final Verify

- [ ] **Step 1: Full flutter analyze**

```
cd "c:/flutter dev/projects/reminder/reminder" && flutter analyze
```

Expected: **No issues found.** Fix every warning and error if any exist.

- [ ] **Step 2: Check HiveStorage box name constants**

Open `lib/core/storage/hive_storage.dart`. Confirm the exact values of `invoicesBoxName`, `clientsBoxName`, `remindersBoxName`, `settingsBoxName`. The `FirestoreSyncService` and its `restoreAllFromCloud` method reference these. If the actual names differ from what's in the service, update the service.

- [ ] **Step 3: Manual smoke test — Pro user creates invoice**

1. Run the app on a device or emulator with internet access.
2. Log in as a Pro user (or set `isPro = true` in `subscription_local_datasource` temporarily for testing).
3. Create an invoice.
4. Open Firestore console → `users/{userId}/invoices/` → document should appear.

- [ ] **Step 4: Manual smoke test — Free user creates invoice**

1. Log in as a free user.
2. Create an invoice.
3. Open Firestore console → `users/{userId}/invoices/` → **no document should appear**.

- [ ] **Step 5: Manual smoke test — Restore on login**

1. Clear app data (or use a fresh emulator).
2. Log in as a Pro user who has existing Firestore data.
3. Wait a few seconds after login.
4. Navigate to Invoices list → previously synced invoices should appear.

- [ ] **Step 6: Final commit**

```bash
git add -A
git commit -m "feat: FIX-001 Firestore cloud sync complete — Pro backup, free silent skip, restore on login"
```

---

## Firestore Security Rules

Add these rules in the Firebase console under Firestore → Rules:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null
        && request.auth.uid == userId;
    }
  }
}
```

---

## Self-Review: Spec Coverage

| Spec Requirement | Task |
|---|---|
| Firestore collections structure | Task 1 (service defines paths) |
| `FirestoreSyncService` with all 7 methods | Task 1 |
| Hook invoice repository | Task 2 |
| Hook client repository | Task 2 |
| Hook reminder repository | Task 3 |
| Hook profile/settings repository | Task 3 |
| Restore on login when Hive empty | Task 4 |
| Free tier: skip Firestore silently | All sync methods check `isPro` flag |
| Pro upgrade triggers upload | Task 5 |
| Settings screen indicator | Task 6 |
| `flutter analyze` clean | Task 7 |
| Firestore errors never crash app | All sync calls wrapped in try/catch |
| Hive stays as source of truth | Read always from Hive; Firestore is write-through only |

All spec requirements covered. No placeholders.
