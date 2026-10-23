/// Filtrado de productos aptos para nuevos pedidos.
///
/// El reporte financiero conserva los productos inactivos para no perder
/// ventas históricas. Solo Próximo pedido y Pedido manual deben ocultarlos.
bool isPurchasableOrderProduct(Map<String, dynamic> row) {
  final active = row['catalogo_activo'];
  if (active == null) {
    // Compatibilidad mientras se despliegan juntos backend y frontend.
    // La confirmación del backend siempre vuelve a validar el estado real.
    return true;
  }
  if (active is bool) return active;
  if (active is num) return active != 0;
  final value = active.toString().trim().toLowerCase();
  return value == 'true' || value == 't' || value == '1';
}

List<Map<String, dynamic>> activePurchaseCatalog(
  Iterable<Map<String, dynamic>> rows,
) =>
    rows.where(isPurchasableOrderProduct).toList(growable: false);
