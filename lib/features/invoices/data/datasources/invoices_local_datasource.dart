import 'dart:math';

import '../../domain/entities/invoice.dart';
import '../models/invoice_model.dart';

class InvoicesLocalDatasource {
  final List<InvoiceModel> _invoices = [
    InvoiceModel(
      id: 'inv-1',
      clientId: 'client-1',
      clientName: 'Northwind Studio',
      service: 'Brand identity package',
      amount: 1850,
      dueDate: DateTime.now().subtract(const Duration(days: 4)),
      status: InvoiceStatus.pending,
      createdAt: DateTime.now().subtract(const Duration(days: 21)),
    ),
    InvoiceModel(
      id: 'inv-2',
      clientId: 'client-2',
      clientName: 'Acme Retail',
      service: 'Monthly analytics report',
      amount: 920,
      dueDate: DateTime.now().add(const Duration(days: 6)),
      status: InvoiceStatus.pending,
      createdAt: DateTime.now().subtract(const Duration(days: 9)),
    ),
  ];

  final Map<int, List<InvoiceModel>> _pageCache = {};
  final Map<String, InvoiceModel> _invoiceCache = {};

  List<InvoiceModel> _normalizedInvoices() {
    final now = DateTime.now();
    return _invoices
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
    _invoices.insert(0, invoice);
    _invoiceCache[invoice.id] = invoice;
    _pageCache.clear();
    return invoice;
  }

  Future<InvoiceModel> updateInvoice(InvoiceModel invoice) async {
    await Future<void>.delayed(const Duration(milliseconds: 140));

    final index = _invoices.indexWhere((item) => item.id == invoice.id);
    if (index < 0) {
      throw Exception('Invoice not found.');
    }

    _invoices[index] = invoice;
    _invoiceCache[invoice.id] = invoice;
    _pageCache.clear();
    return invoice;
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
