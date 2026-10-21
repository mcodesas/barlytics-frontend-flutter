/// Resuelve proveedores configurados por producto, con prioridad para
/// el proveedor predeterminado. La pertenencia del producto al catálogo del
/// proveedor también cuenta cuando nadie configuró un predeterminado.
class OrderDestinationResolver {
  const OrderDestinationResolver._();

  static int? _id(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static Set<int> associatedDestinations(
    int productId,
    List<Map<String, dynamic>> destinations,
  ) {
    final linked = <int>{};
    for (final destination in destinations) {
      final id = _id(destination['id']);
      if (id == null) continue;
      final raw = destination['productoIds'];
      if (raw is List && raw.any((value) => _id(value) == productId)) {
        linked.add(id);
      }
      final defaults = destination['productoIdsPredeterminados'];
      if (defaults is List &&
          defaults.any((value) => _id(value) == productId)) {
        linked.add(id);
      }
    }
    return linked;
  }

  static int? resolve({
    required int productId,
    required List<Map<String, dynamic>> destinations,
    int? selected,
  }) {
    final candidates = associatedDestinations(productId, destinations);
    if (selected != null &&
        destinations.any((destination) => _id(destination['id']) == selected)) {
      return selected;
    }
    for (final destination in destinations) {
      final id = _id(destination['id']);
      final raw = destination['productoIdsPredeterminados'];
      if (id != null &&
          raw is List &&
          raw.any((value) => _id(value) == productId)) {
        return id;
      }
    }
    // Si existe un único proveedor asociado, no usar WhatsApp general.
    return candidates.length == 1 ? candidates.single : null;
  }

  static bool needsChoice({
    required int productId,
    required List<Map<String, dynamic>> destinations,
    int? selected,
  }) {
    return associatedDestinations(productId, destinations).length > 1 &&
        resolve(productId: productId, destinations: destinations, selected: selected) == null;
  }
}
