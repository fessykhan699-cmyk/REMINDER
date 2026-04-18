import '../entities/invoice_template.dart';

abstract class InvoiceTemplateRepository {
  Future<List<InvoiceTemplate>> getTemplates();
  Future<void> saveTemplate(InvoiceTemplate template);
  Future<void> deleteTemplate(String id);
}
