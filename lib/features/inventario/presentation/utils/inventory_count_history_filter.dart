/// Coincidencia del producto efectivamente registrado en una jornada.
///
/// El filtro se aplica a cada fila del conteo (no solamente a la tarjeta de
/// la fecha), por lo que la vista muestra las cantidades del producto buscado.
bool matchesCountHistoryRow({
  required int productId,
  required int countId,
  required String productName,
  int? selectedProductId,
  String query = '',
}) {
  if (selectedProductId != null && selectedProductId != productId) {
    return false;
  }
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return true;
  return productName.toLowerCase().contains(normalized) ||
      '$countId'.contains(normalized);
}

/// La fecha elegida corresponde al día civil de la jornada y no depende de
/// la hora en que se registraron los productos.
bool matchesCountHistoryDay({
  required DateTime date,
  String? selectedDay,
}) {
  if (selectedDay == null) return true;
  final key = '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
  return key == selectedDay;
}
