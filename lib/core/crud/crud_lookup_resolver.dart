import '../network/api_client.dart';
import 'crud_field.dart';

/// Resuelve etiquetas legibles para campos relacionales.
///
/// Las tablas no deben mostrar únicamente IDs técnicos como `paisId`,
/// `ciudId` o `emprId`. Esta clase consulta una sola vez cada catálogo
/// requerido por la pantalla y construye un mapa local id -> etiqueta.
/// Así evitamos peticiones por cada fila y mantenemos una UI empresarial.
class CrudLookupResolver {
  CrudLookupResolver(this._apiClient);

  final ApiClient _apiClient;

  /// Carga las etiquetas de todos los campos que tengan ayuda de búsqueda.
  ///
  /// Retorna un mapa por nombre de campo. Ejemplo:
  /// `{ 'paisId': { '1': 'Colombia - CO' } }`.
  Future<Map<String, Map<String, String>>> resolveLabels(List<CrudField> fields) async {
    final result = <String, Map<String, String>>{};
    final cache = <String, Future<Map<String, String>>>{};

    for (final field in fields) {
      final lookup = field.lookup;
      if (lookup == null) continue;

      final cacheKey = '${lookup.endpoint}|${lookup.idField}|${lookup.displayFields.join(',')}';
      final future = cache.putIfAbsent(cacheKey, () => _loadLookup(lookup));
      result[field.name] = await future;
    }

    return result;
  }

  Future<Map<String, String>> _loadLookup(CrudLookupConfig lookup) async {
    try {
      final response = await _apiClient.get<List<Map<String, dynamic>>>(
        lookup.endpoint,
        (json) => (json as List? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(),
      );

      final labels = <String, String>{};
      for (final item in response.data ?? const <Map<String, dynamic>>[]) {
        final id = item[lookup.idField];
        if (id == null) continue;

        final text = lookup.displayFields
            .where((field) => !field.toLowerCase().endsWith('id'))
            .map((field) => item[field])
            .where((value) => value != null && value.toString().trim().isNotEmpty)
            .map((value) => value.toString().trim())
            .join(' - ');

        // Nunca imprimimos el ID técnico. Si no hay campos legibles, dejamos
        // el valor vacío para que la UI muestre un guion o mensaje neutro.
        labels[id.toString()] = text;
      }
      return labels;
    } catch (_) {
      // Si un catálogo falla, no bloqueamos la pantalla principal.
      // Se muestra el ID como respaldo y el usuario puede reintentar refrescando.
      return <String, String>{};
    }
  }
}

/// Devuelve el valor visible de un campo en listas y detalles.
String crudDisplayValue(
  CrudField field,
  Object? rawValue,
  Map<String, Map<String, String>> lookupLabels,
) {
  if (rawValue == null || rawValue.toString().trim().isEmpty) {
    return '-';
  }

  final lookup = field.lookup;
  if (lookup == null) {
    return rawValue.toString();
  }

  final label = lookupLabels[field.name]?[rawValue.toString()];
  if (label != null && label.trim().isNotEmpty) return label.trim();

  // Si no se pudo resolver la ayuda, no mostramos el ID numérico al usuario.
  return '-';
}
