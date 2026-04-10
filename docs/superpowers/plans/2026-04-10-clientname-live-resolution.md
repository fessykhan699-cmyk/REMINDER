# clientName Live Resolution Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `invoice.clientName` always reflect the client's current name by resolving it at the repository layer, with fallback to the stored name for deleted clients.

**Architecture:** `InvoicesLocalDatasource` receives a `ClientsLocalDatasource` dependency. The existing `_normalizedInvoices()` method is extended to build a `Map<clientId, name>` from the in-memory clients box and apply it to each invoice during the mapping pass. A `clearCache()` method is exposed and called from `ClientsController.updateClient()` so name changes are reflected immediately.

**Tech Stack:** Flutter, Hive, Riverpod (`Provider`)

---

### Task 1: Add `ClientsLocalDatasource` dependency to `InvoicesLocalDatasource`

**Files:**
- Modify: `lib/features/invoices/data/datasources/invoices_local_datasource.dart`

- [ ] **Step 1: Add the import for `ClientsLocalDatasource` and `ClientModel`**

At the top of `invoices_local_datasource.dart`, add:

```dart
import '../../../../features/clients/data/datasources/clients_local_datasource.dart';
```

- [ ] **Step 2: Add constructor with `ClientsLocalDatasource` parameter**

Replace the implicit default constructor (the class currently has no constructor) by adding:

```dart
InvoicesLocalDatasource(this._clientsDatasource);

final ClientsLocalDatasource _clientsDatasource;
```

Place these at the top of the class body, before `static const InvoiceStatusService _statusService`.

- [ ] **Step 3: Extend `_normalizedInvoices()` to resolve `clientName`**

Replace the existing `_normalizedInvoices()` method:

```dart
List<InvoiceModel> _normalizedInvoices() {
  final now = DateTime.now();
  final invoices = _invoicesBox.values.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // Build a lookup map from live client data — O(n clients), O(1) per invoice
  final clientNameMap = {
    for (final client in _clientsDatasource.allClients())
      client.id: client.name,
  };

  return invoices
      .map(
        (invoice) => invoice.copyWith(
          status: _statusService.resolveStatus(invoice, now: now),
          paymentLink: invoice.normalizedPaymentLink,
          // Use live client name; fall back to stored name if client was deleted
          clientName: clientNameMap[invoice.clientId] ?? invoice.clientName,
        ),
      )
      .toList(growable: false);
}
```

- [ ] **Step 4: Add `clearCache()` method to `InvoicesLocalDatasource`**

Add this method after `deleteByClientId`:

```dart
void clearCache() {
  _pageCache.clear();
  _invoiceCache.clear();
}
```

- [ ] **Step 5: Run `flutter analyze lib/features/invoices/data/datasources/invoices_local_datasource.dart`**

```bash
flutter analyze lib/features/invoices/data/datasources/invoices_local_datasource.dart
```

Expected: errors about `allClients()` not existing yet on `ClientsLocalDatasource` — that's fine, it will be added in Task 2.

---

### Task 2: Add `allClients()` method to `ClientsLocalDatasource`

**Files:**
- Modify: `lib/features/clients/data/datasources/clients_local_datasource.dart`

- [ ] **Step 1: Add `allClients()` method**

Add this method to `ClientsLocalDatasource` after `getClientById`:

```dart
/// Returns all clients synchronously from the in-memory Hive box.
/// Used by InvoicesLocalDatasource to resolve live client names.
List<ClientModel> allClients() {
  return _clientsBox.values.toList(growable: false);
}
```

- [ ] **Step 2: Run `flutter analyze lib/features/clients/data/datasources/clients_local_datasource.dart`**

```bash
flutter analyze lib/features/clients/data/datasources/clients_local_datasource.dart
```

Expected: no issues.

- [ ] **Step 3: Commit Tasks 1 and 2**

```bash
git add lib/features/invoices/data/datasources/invoices_local_datasource.dart
git add lib/features/clients/data/datasources/clients_local_datasource.dart
git commit -m "$(cat <<'EOF'
feat: resolve live clientName in InvoicesLocalDatasource

InvoicesLocalDatasource now takes a ClientsLocalDatasource dependency.
_normalizedInvoices() builds a clientId→name map from the in-memory
clients box and applies it during the invoice mapping pass, falling
back to the stored clientName for deleted clients.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Wire `ClientsLocalDatasource` into `invoicesLocalDatasourceProvider`

**Files:**
- Modify: `lib/features/invoices/presentation/controllers/invoices_controller.dart`

- [ ] **Step 1: Add import for `clientsLocalDatasourceProvider`**

In `invoices_controller.dart`, add this import:

```dart
import '../../../clients/presentation/controllers/clients_controller.dart';
```

- [ ] **Step 2: Update `invoicesLocalDatasourceProvider` to pass the dependency**

Replace:

```dart
final invoicesLocalDatasourceProvider = Provider<InvoicesLocalDatasource>(
  (ref) => InvoicesLocalDatasource(),
);
```

With:

```dart
final invoicesLocalDatasourceProvider = Provider<InvoicesLocalDatasource>(
  (ref) => InvoicesLocalDatasource(
    ref.watch(clientsLocalDatasourceProvider),
  ),
);
```

- [ ] **Step 3: Run `flutter analyze lib/features/invoices/presentation/controllers/invoices_controller.dart`**

```bash
flutter analyze lib/features/invoices/presentation/controllers/invoices_controller.dart
```

Expected: no issues.

- [ ] **Step 4: Commit**

```bash
git add lib/features/invoices/presentation/controllers/invoices_controller.dart
git commit -m "$(cat <<'EOF'
feat: wire ClientsLocalDatasource into invoicesLocalDatasourceProvider

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Clear invoice cache when a client is updated

**Files:**
- Modify: `lib/features/clients/presentation/controllers/clients_controller.dart`

- [ ] **Step 1: Call `clearCache()` after a client is successfully updated**

In `ClientsController.updateClient()`, add a cache-clear call after the update succeeds. The current method looks like:

```dart
Future<Client> updateClient(Client client) async {
  final validated = _validatedClient(client);

  try {
    final updated = await ref
        .read(updateClientUseCaseProvider)
        .call(validated);
    final current = state.valueOrNull ?? const <Client>[];
    state = AsyncValue.data(_mergeClients(current, updated));
    ref.invalidate(clientDetailProvider(updated.id));
    return updated;
  } catch (error, stackTrace) {
    if (error is AppException) rethrow;
    debugPrint('Failed to save client ${client.id}: $error');
    debugPrintStack(stackTrace: stackTrace);
    throw const AppException('Failed to save client');
  }
}
```

Replace it with:

```dart
Future<Client> updateClient(Client client) async {
  final validated = _validatedClient(client);

  try {
    final updated = await ref
        .read(updateClientUseCaseProvider)
        .call(validated);
    final current = state.valueOrNull ?? const <Client>[];
    state = AsyncValue.data(_mergeClients(current, updated));
    ref.invalidate(clientDetailProvider(updated.id));
    // Clear invoice cache so clientName resolves to the new name on next fetch
    ref.read(invoicesLocalDatasourceProvider).clearCache();
    return updated;
  } catch (error, stackTrace) {
    if (error is AppException) rethrow;
    debugPrint('Failed to save client ${client.id}: $error');
    debugPrintStack(stackTrace: stackTrace);
    throw const AppException('Failed to save client');
  }
}
```

- [ ] **Step 2: Run `flutter analyze lib/features/clients/presentation/controllers/clients_controller.dart`**

```bash
flutter analyze lib/features/clients/presentation/controllers/clients_controller.dart
```

Expected: no issues.

- [ ] **Step 3: Run full app analyze**

```bash
flutter analyze
```

Expected: no issues.

- [ ] **Step 4: Manual verification**

1. Run the app: `flutter run`
2. Create a client named "Old Name"
3. Create an invoice for that client
4. Edit the client name to "New Name"
5. Navigate to the invoices list — the invoice should now show "New Name"
6. Check the reminder flow for that invoice — the preview message should say "Hi New Name"
7. Delete the client
8. Navigate to invoices — the invoice should still show "New Name" (last known name as fallback)

- [ ] **Step 5: Commit**

```bash
git add lib/features/clients/presentation/controllers/clients_controller.dart
git commit -m "$(cat <<'EOF'
feat: clear invoice cache when client name is updated

Ensures clientName on existing invoices reflects the new name
immediately after a client update, without requiring app restart.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review

**Spec coverage:**
- ✅ `InvoicesLocalDatasource` accepts `ClientsLocalDatasource` dependency
- ✅ `_normalizedInvoices()` builds `Map<clientId, name>` from live clients box
- ✅ Fallback to stored `clientName` when client not found (deleted)
- ✅ Resolution is synchronous (in-memory Hive box) — no async I/O
- ✅ `clearCache()` exposed and called on client update
- ✅ No UI changes required
- ✅ No Hive schema migration
- ✅ All consumers (UI, reminder builder, PDF) automatically get live name

**Placeholder scan:** None found. All code is complete.

**Type consistency:**
- `allClients()` returns `List<ClientModel>` — used in `_normalizedInvoices()` as `client.id` and `client.name`, both fields exist on `ClientModel`
- `clearCache()` defined in Task 1, called in Task 4 via `ref.read(invoicesLocalDatasourceProvider).clearCache()` — consistent
- `invoicesLocalDatasourceProvider` returns `InvoicesLocalDatasource` — `.clearCache()` is accessible directly
