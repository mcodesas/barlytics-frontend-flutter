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
    this.allowCreate = true,
    this.allowDelete = true,
  });

  final String key;
  final String title;
  final String basePath;
  final String idField;
  final List<CrudField> fields;
  final List<CrudField> formFields;
  final T Function(Map<String, dynamic> json) fromJson;
  final Map<String, dynamic> Function(T model) toJson;

  /// Permite ocultar la creación cuando el módulo corresponde a un catálogo
  /// global y el usuario solo debe parametrizar registros existentes.
  final bool allowCreate;

  /// Permite ocultar la eliminación cuando la acción correcta es activar o
  /// inactivar desde el formulario de edición.
  final bool allowDelete;
}
