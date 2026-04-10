# clientName Live Resolution — Design Spec

**Date:** 2026-04-10  
**Status:** Approved

## Problem

`Invoice.clientName` is stored at creation time. If the client's name is later edited, all existing invoices continue showing the old name — in the invoice list, invoice detail, reminder messages, and PDF exports. There is no mechanism to keep the stored name in sync.

## Goal

Make `invoice.clientName` always reflect the client's current name everywhere in the app, with zero UI changes and zero data migration, while preserving the stored name as a fallback for deleted clients.

## Approach

Resolve `clientName` at the repository layer inside `InvoicesLocalDatasource._normalizedInvoices()`. This method already maps over every invoice to resolve status — extend the same pass to overwrite `clientName` with the live value from the clients box. Every consumer (UI widgets, reminder builder, PDF export) automatically receives the live name without any changes.

## Architecture

### Files changed

| File | Change |
|------|--------|
| `lib/features/invoices/data/datasources/invoices_local_datasource.dart` | Accept `ClientsLocalDatasource` in constructor; resolve `clientName` in `_normalizedInvoices()` |
| `lib/features/invoices/presentation/controllers/invoices_controller.dart` | Pass `ClientsLocalDatasource` to `InvoicesLocalDatasource` provider |

### No files changed

- `Invoice` entity — `clientName` field stays; it is the Hive-persisted fallback
- `InvoiceModel` — no schema change; stored `clientName` remains in Hive as fallback
- All UI widgets — continue reading `invoice.clientName`; value is now always live
- `ReminderRepositoryImpl.buildPreviewMessage` — reads `invoice.clientName`; live automatically
- PDF export — reads `invoice.clientName`; live automatically

### Resolution logic

In `_normalizedInvoices()`:

```
1. Read all clients from HiveStorage.clientsBox (in-memory, synchronous)
2. Build Map<String, String>: clientId → client.name
3. For each invoice in the mapping pass:
   copyWith(
     clientName: clientIdToName[invoice.clientId] ?? invoice.clientName,
     status: ...,  // existing status resolution unchanged
   )
```

Fallback: if `clientId` is not in the map (client deleted), the stored `clientName` is used. Deleted-client invoices continue to display correctly.

### Performance

- Clients box read is in-memory Hive — no async I/O, no disk access
- Map build is O(n clients); lookup is O(1) per invoice
- Negligible overhead at any realistic data size (5–500 clients)

## Data Flow

```
InvoiceRepository.getInvoices()
  → InvoicesLocalDatasource.fetchInvoices()
  → _normalizedInvoices()
      → HiveStorage.clientsBox.values (synchronous, in-memory)
      → Map<clientId, name> built once per call
      → invoice.copyWith(clientName: liveNameOrFallback, status: resolved)
  → cached in _pageCache
  → returned to controller → UI / reminder builder / PDF
```

## Edge Cases

| Case | Behaviour |
|------|-----------|
| Client name updated | Next `getInvoices()` call (cache cleared on client update) returns live name |
| Client deleted | Stored `clientName` used as fallback — invoice still displays correctly |
| Invoice created for new client | `clientName` written at creation time; immediately resolved on next fetch |
| Client box empty | Map is empty; all invoices fall back to stored `clientName` |

## Cache invalidation

`_pageCache` is already cleared on every `createInvoice`, `updateInvoice`, and `deleteInvoice`. It must also be cleared when a client is updated. `ClientsLocalDatasource.updateClient` should notify `InvoicesLocalDatasource` to clear its cache, or `InvoicesLocalDatasource` can simply not cache across client updates.

The simplest approach: expose a `clearCache()` method on `InvoicesLocalDatasource` and call it from `ClientsController.updateClient()`.

## Out of Scope

- Hive data migration — stored `clientName` values are not updated; they remain as fallback only
- Writing the resolved name back to Hive — resolution is display-time only
- UI changes of any kind
