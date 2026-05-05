import 'crud_field.dart';

/// Configuración de un módulo CRUD generada desde la colección Postman.
class CrudModuleConfig<T> {
  const CrudModuleConfig({
    required this.key,
    required this.title,
    required this.basePath,
    required this.idField,
    required this.fields,
    required this.formFields,
    required this.fromJson,
    required this.toJson,
  });

  final String key;
  final String title;
  final String basePath;
  final String idField;
  final List<CrudField> fields;
  final List<CrudField> formFields;
  final T Function(Map<String, dynamic> json) fromJson;
  final Map<String, dynamic> Function(T model) toJson;
}
