import 'package:hive/hive.dart';
import '../../domain/entities/invoice_template.dart';
import '../../domain/repositories/invoice_template_repository.dart';
import '../models/invoice_template_model.dart';

class InvoiceTemplateRepositoryImpl implements InvoiceTemplateRepository {
  final Box<InvoiceTemplateModel> _box;

  InvoiceTemplateRepositoryImpl(this._box);

  @override
  Future<List<InvoiceTemplate>> getTemplates() async {
    await _seedDefaultTemplatesIfEmpty();
    return _box.values.toList();
  }

  Future<void> _seedDefaultTemplatesIfEmpty() async {
    try {
      if (_box.isNotEmpty) return;
      const seeds = [
        InvoiceTemplateModel(
          id: '__seed_standard__',
          name: 'Standard Service Invoice',
          service: 'Professional Service',
          amount: 0,
          notes: 'Payment due within 30 days. Thank you for your business.',
        ),
        InvoiceTemplateModel(
          id: '__seed_consulting__',
          name: 'Consulting Invoice',
          service: 'Consulting Services',
          amount: 0,
          notes:
              'Consulting services rendered as discussed. Payment due within 14 days.',
        ),
        InvoiceTemplateModel(
          id: '__seed_receipt__',
          name: 'Quick Receipt',
          service: 'Services Rendered',
          amount: 0,
          notes: 'Received with thanks.',
        ),
      ];
      for (final t in seeds) {
        await _box.put(t.id, t);
      }
    } catch (_) {}
  }

  @override
  Future<void> saveTemplate(InvoiceTemplate template) async {
    await _box.put(template.id, InvoiceTemplateModel.fromEntity(template));
  }

  @override
  Future<void> deleteTemplate(String id) async {
    await _box.delete(id);
  }
}
