import 'dart:math';

import 'package:hive/hive.dart';

import '../../../../core/storage/hive_storage.dart';
import '../../../../shared/services/invoice_status_service.dart';
import '../models/invoice_model.dart';

class InvoicesLocalDatasource {
  static const InvoiceStatusService _statusService = InvoiceStatusService();
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
          (invoice) => invoice.copyWith(
            status: _statusService.resolveStatus(invoice, now: now),
            paymentLink: invoice.normalizedPaymentLink,
          ),
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

  Future<String> getNextInvoiceId({required String prefix}) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));

    final normalizedPrefix = prefix.trim().toUpperCase();
    final escapedPrefix = RegExp.escape(normalizedPrefix);
    final pattern = RegExp('^$escapedPrefix-(\\d+)\$', caseSensitive: false);

    var highestNumber = 0;
    for (final invoice in _invoicesBox.values) {
      final match = pattern.firstMatch(invoice.id.trim());
      final number = int.tryParse(match?.group(1) ?? '');
      if (number != null && number > highestNumber) {
        highestNumber = number;
      }
    }

    final nextNumber = highestNumber + 1;
    final paddedNumber = nextNumber.toString().padLeft(3, '0');
    return '$normalizedPrefix-$paddedNumber';
  }
}
