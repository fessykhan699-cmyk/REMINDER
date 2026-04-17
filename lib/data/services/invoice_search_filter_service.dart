import 'package:flutter/foundation.dart';
import '../../features/invoices/domain/entities/invoice.dart';

class InvoiceSearchFilterService {
  static List<Invoice> applySearchAndFilter({
    required List<Invoice> invoices,
    required String query,
    required String? statusFilter,
    required DateTime? fromDate,
    required DateTime? toDate,
  }) {
    try {
      final normalizedQuery = query.trim().toLowerCase();
      final hasQuery = normalizedQuery.isNotEmpty;
      final hasStatus = statusFilter != null && statusFilter.isNotEmpty;

      return invoices.where((invoice) {
        // 1. Search Query Logic (AND with other filters)
        if (hasQuery) {
          final clientMatch = invoice.clientName.toLowerCase().contains(normalizedQuery);
          final numberMatch = invoice.invoiceNumber.toLowerCase().contains(normalizedQuery);
          
          bool itemMatch = false;
          if (invoice.items.isNotEmpty) {
            itemMatch = invoice.items.any((item) =>
                item.description.toLowerCase().contains(normalizedQuery));
          } else {
            // legacy service/description field fallback
            itemMatch = invoice.service.toLowerCase().contains(normalizedQuery);
          }

          if (!(clientMatch || numberMatch || itemMatch)) {
            return false;
          }
        }

        // 2. Status Filter logic
        if (hasStatus) {
          if (invoice.status.name.toLowerCase() != statusFilter.toLowerCase()) {
            return false;
          }
        }

        // 3. Date Range logic
        final invoiceDateNormalized = DateTime(
          invoice.createdAt.year,
          invoice.createdAt.month,
          invoice.createdAt.day,
        );

        if (fromDate != null) {
          final fromDateNormalized = DateTime(
            fromDate.year,
            fromDate.month,
            fromDate.day,
          );
          if (invoiceDateNormalized.isBefore(fromDateNormalized)) {
            return false;
          }
        }

        if (toDate != null) {
          final toDateNormalized = DateTime(
            toDate.year,
            toDate.month,
            toDate.day,
          );
          if (invoiceDateNormalized.isAfter(toDateNormalized)) {
            return false;
          }
        }

        return true;
      }).toList();
    } catch (e) {
      debugPrint('Error in applySearchAndFilter: $e');
      return invoices;
    }
  }

  static List<String> getAvailableStatuses(List<Invoice> invoices) {
    try {
      final statuses = invoices.map((i) => i.status.name).toSet().toList();
      statuses.sort();
      return statuses;
    } catch (e) {
      debugPrint('Error in getAvailableStatuses: $e');
      return [];
    }
  }
}
