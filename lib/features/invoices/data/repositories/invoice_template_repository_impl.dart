import 'package:hive/hive.dart';
import '../../domain/entities/invoice_template.dart';
import '../../domain/repositories/invoice_template_repository.dart';
import '../models/invoice_template_model.dart';

class InvoiceTemplateRepositoryImpl implements InvoiceTemplateRepository {
  final Box<InvoiceTemplateModel> _box;

  InvoiceTemplateRepositoryImpl(this._box);

  @override
  Future<List<InvoiceTemplate>> getTemplates() async {
    return _box.values.toList();
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
