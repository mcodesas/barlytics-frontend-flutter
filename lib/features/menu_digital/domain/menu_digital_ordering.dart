/// Orden de la carta aislado de la vista y del catálogo del POS.
/// Mantiene el orden por posición, sin alfabetizar los nombres del negocio.
class MenuDigitalOrdering {
  const MenuDigitalOrdering._();

  static String category(Map<String, dynamic> product) {
    final name = (product['tipo'] ?? '').toString().trim();
    return name.isEmpty ? 'Especialidades' : name;
  }

  static int? productId(Map<String, dynamic> item) {
    final value = item['id'];
    return value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
  }

  static List<String> categories(
    List<Map<String, dynamic>> products,
    List<String> requested,
  ) {
    final available = <String>{
      for (final item in products) category(item),
    };
    return [
      ...requested.where((name) => available.remove(name)),
      ...available,
    ];
  }

  /// Agrupa por categoría en el orden configurado y conserva el orden manual
  /// de cada producto. Los recién incorporados se agregan al final.
  static List<Map<String, dynamic>> arrange(
    List<Map<String, dynamic>> products, {
    List<int> productIds = const [],
    List<String> categoryOrder = const [],
  }) {
    final ranks = <int, int>{
      for (var i = 0; i < productIds.length; i++) productIds[i]: i,
    };
    final groups = categories(products, categoryOrder);
    final categoryRanks = <String, int>{
      for (var i = 0; i < groups.length; i++) groups[i]: i,
    };
    final originalOrder = <Map<String, dynamic>, int>{
      for (var i = 0; i < products.length; i++) products[i]: i,
    };
    return [...products]..sort((left, right) {
      final categoryComparison =
          (categoryRanks[category(left)] ?? groups.length)
              .compareTo(categoryRanks[category(right)] ?? groups.length);
      if (categoryComparison != 0) return categoryComparison;
      final leftRank = ranks[productId(left)] ?? (productIds.length +
          (originalOrder[left] ?? 0));
      final rightRank = ranks[productId(right)] ?? (productIds.length +
          (originalOrder[right] ?? 0));
      return leftRank.compareTo(rightRank);
    });
  }
}
