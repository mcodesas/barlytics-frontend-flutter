/// Tipo visual y de validación para campos dinámicos.
enum CrudFieldType { text, number, decimal, date, dateTime, boolean }

/// Configuración de una ayuda de búsqueda para campos relacionales.
///
/// Permite que campos como `paisId`, `ciudId`, `emprId` o `sucuId`
/// se rendericen como listas de selección consultadas desde el backend,
/// evitando que el usuario tenga que digitar identificadores técnicos.
class CrudLookupConfig {
  const CrudLookupConfig({
    required this.endpoint,
    required this.idField,
    required this.displayFields,
  });

  /// Endpoint REST que retorna la lista de opciones.
  final String endpoint;

  /// Campo del response que representa el identificador a enviar al backend.
  final String idField;

  /// Campos usados para construir el texto visible de cada opción.
  final List<String> displayFields;
}

/// Opción cargada desde una ayuda de búsqueda.
class CrudLookupOption {
  const CrudLookupOption({
    required this.id,
    required this.label,
    required this.raw,
  });

  final Object? id;
  final String label;
  final Map<String, dynamic> raw;
}

class CrudField {
  const CrudField({
    required this.name,
    required this.label,
    required this.type,
    this.required = true,
    this.readOnly = false,
    this.lookup,
  });

  final String name;
  final String label;
  final CrudFieldType type;
  final bool required;
  final bool readOnly;

  /// Configuración opcional para renderizar el campo como ayuda de búsqueda.
  final CrudLookupConfig? lookup;
}
