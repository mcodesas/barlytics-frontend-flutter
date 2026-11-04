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
