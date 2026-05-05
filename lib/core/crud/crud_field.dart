/// Tipo visual y de validación para campos dinámicos.
enum CrudFieldType { text, number, decimal, date, dateTime, boolean }

class CrudField {
  const CrudField({
    required this.name,
    required this.label,
    required this.type,
    this.required = true,
    this.readOnly = false,
  });

  final String name;
  final String label;
  final CrudFieldType type;
  final bool required;
  final bool readOnly;
}
