import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/services/invoice_search_filter_service.dart';
import '../controllers/invoices_controller.dart';
import '../../domain/entities/invoice.dart';

final invoiceSearchQueryProvider = StateProvider<String>((ref) => "");

final invoiceStatusFilterProvider = StateProvider<String?>((ref) => null);

final invoiceFromDateFilterProvider = StateProvider<DateTime?>((ref) => null);

final invoiceToDatFilterProvider = StateProvider<DateTime?>((ref) => null);

final filteredInvoicesProvider = Provider<List<Invoice>>((ref) {
  final invoicesAsync = ref.watch(invoicesControllerProvider);
  final query = ref.watch(invoiceSearchQueryProvider);
  final status = ref.watch(invoiceStatusFilterProvider);
  final fromDate = ref.watch(invoiceFromDateFilterProvider);
  final toDate = ref.watch(invoiceToDatFilterProvider);

  final invoices = invoicesAsync.valueOrNull ?? [];

  return InvoiceSearchFilterService.applySearchAndFilter(
    invoices: invoices,
    query: query,
    statusFilter: status,
    fromDate: fromDate,
    toDate: toDate,
  );
});
