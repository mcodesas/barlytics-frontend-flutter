/// Normaliza estructuras JSON antes de enviarlas al backend.
///
/// Dart serializa un `double` entero como `1.0`. Para campos Java `BigDecimal`
/// validados con `@Digits(fraction = 0)`, Bean Validation considera que `1.0`
/// tiene una cifra fraccionaria y lo rechaza aunque su valor matemático sea
/// entero. Esta función convierte únicamente doubles finitos y exactamente
/// enteros a `int`, de forma recursiva, sin alterar valores realmente
/// fraccionarios.
Object? normalizeJsonPayload(Object? value) {
  if (value is double) {
    if (!value.isFinite) return value;
    if (value == value.truncateToDouble()) {
      return value.toInt();
    }
    return value;
  }

  if (value is List) {
    return value.map<Object?>((item) => normalizeJsonPayload(item)).toList(growable: false);
  }

  if (value is Map) {
    return value.map<Object?, Object?>(
      (key, item) => MapEntry<Object?, Object?>(key, normalizeJsonPayload(item)),
    );
  }

  return value;
}

Map<String, dynamic>? normalizeJsonMap(Map<String, dynamic>? value) {
  if (value == null) return null;
  final normalized = normalizeJsonPayload(value);
  return Map<String, dynamic>.from(normalized! as Map);
}
