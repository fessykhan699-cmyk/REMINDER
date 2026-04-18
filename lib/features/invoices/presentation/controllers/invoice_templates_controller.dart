import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/storage/hive_storage.dart';
import '../../data/repositories/invoice_template_repository_impl.dart';
import '../../domain/entities/invoice_template.dart';
import '../../domain/repositories/invoice_template_repository.dart';
import '../../domain/entities/line_item.dart';

final invoiceTemplateRepositoryProvider = Provider<InvoiceTemplateRepository>((ref) {
  return InvoiceTemplateRepositoryImpl(HiveStorage.invoiceTemplatesBox);
});

final invoiceTemplatesControllerProvider =
    StateNotifierProvider<InvoiceTemplatesController, AsyncValue<List<InvoiceTemplate>>>((ref) {
  return InvoiceTemplatesController(ref.watch(invoiceTemplateRepositoryProvider));
});

class InvoiceTemplatesController extends StateNotifier<AsyncValue<List<InvoiceTemplate>>> {
  final InvoiceTemplateRepository _repository;

  InvoiceTemplatesController(this._repository) : super(const AsyncValue.loading()) {
    loadTemplates();
  }

  Future<void> loadTemplates() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.getTemplates());
  }

  Future<void> addTemplate({
    required String name,
    required String service,
    required double amount,
    String? notes,
    String? paymentLink,
    List<LineItem>? items,
  }) async {
    final template = InvoiceTemplate(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      service: service,
      amount: amount,
      notes: notes,
      paymentLink: paymentLink,
      items: items ?? [],
    );
    await _repository.saveTemplate(template);
    await loadTemplates();
  }

  Future<void> removeTemplate(String id) async {
    await _repository.deleteTemplate(id);
    await loadTemplates();
  }

  Future<void> saveTemplate(InvoiceTemplate template) async {
    await _repository.saveTemplate(template);
    await loadTemplates();
  }

  Future<void> deleteTemplate(String id) async {
    await _repository.deleteTemplate(id);
    await loadTemplates();
  }
}
