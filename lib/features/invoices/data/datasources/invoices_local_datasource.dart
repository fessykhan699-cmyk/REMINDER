import 'dart:math';

import 'package:hive/hive.dart';

import '../../../../core/storage/hive_storage.dart';
import '../../domain/entities/invoice.dart';
import '../models/invoice_model.dart';

class InvoicesLocalDatasource {
  final Box<InvoiceModel> _invoicesBox = Hive.box<InvoiceModel>(
    HiveStorage.invoicesBoxName,
  );

  final Map<int, List<InvoiceModel>> _pageCache = {};
  final Map<String, InvoiceModel> _invoiceCache = {};

  List<InvoiceModel> _normalizedInvoices() {
    final now = DateTime.now();
    final invoices = _invoicesBox.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return invoices
        .map(
          (invoice) =>
              invoice.status == InvoiceStatus.pending &&
                  invoice.dueDate.isBefore(now)
              ? invoice.copyWith(status: InvoiceStatus.overdue)
              : invoice,
        )
        .toList(growable: false);
  }

  Future<List<InvoiceModel>> fetchInvoices({
    int page = 1,
    int pageSize = 20,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _pageCache.containsKey(page)) {
      return _pageCache[page]!;
    }

    await Future<void>.delayed(const Duration(milliseconds: 240));

    final source = _normalizedInvoices();
    final start = (page - 1) * pageSize;
    if (start >= source.length) {
      _pageCache[page] = const [];
      return const [];
    }

    final end = min(start + pageSize, source.length);
    final pageData = List<InvoiceModel>.unmodifiable(
      source.sublist(start, end),
    );

    for (final item in pageData) {
      _invoiceCache[item.id] = item;
    }

    _pageCache[page] = pageData;
    return pageData;
  }

  Future<InvoiceModel> createInvoice(InvoiceModel invoice) async {
    await Future<void>.delayed(const Duration(milliseconds: 140));
    await _invoicesBox.put(invoice.id, invoice);
    _invoiceCache[invoice.id] = invoice;
    _pageCache.clear();
    return invoice;
  }

  Future<InvoiceModel> updateInvoice(InvoiceModel invoice) async {
    await Future<void>.delayed(const Duration(milliseconds: 140));

    if (!_invoicesBox.containsKey(invoice.id)) {
      throw Exception('Invoice not found.');
    }

    await _invoicesBox.put(invoice.id, invoice);
    _invoiceCache[invoice.id] = invoice;
    _pageCache.clear();
    return invoice;
  }

  Future<void> deleteInvoice(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));

    if (!_invoicesBox.containsKey(id)) {
      throw Exception('Invoice not found.');
    }

    await _invoicesBox.delete(id);
    _invoiceCache.remove(id);
    _pageCache.clear();
  }

  Future<InvoiceModel?> getInvoiceById(String id) async {
    final cached = _invoiceCache[id];
    if (cached != null) {
      return cached;
    }

    await Future<void>.delayed(const Duration(milliseconds: 100));

    for (final invoice in _normalizedInvoices()) {
      if (invoice.id == id) {
        _invoiceCache[id] = invoice;
        return invoice;
      }
    }

    return null;
  }
}
