/// Determina qué opción del menú corresponde realmente a la ruta visible.
/// Una coincidencia exacta prevalece sobre sus rutas padre; de lo contrario,
/// se toma la ruta padre más específica.
String? mostSpecificMenuPath(String currentPath, Iterable<String> menuPaths) {
  final current = _canonicalMenuPath(currentPath);
  String? selected;
  var selectedLength = -1;
  var exactMatchFound = false;

  for (final candidate in menuPaths) {
    final original = candidate.trim();
    if (original.isEmpty) continue;

    final path = _canonicalMenuPath(original);
    final exact = current == path;
    final child = path != '/home' && current.startsWith('$path/');

    if (!exact && !child) continue;
    if (exact) {
      if (!exactMatchFound || path.length > selectedLength) {
        exactMatchFound = true;
        selected = original;
        selectedLength = path.length;
      }
    } else if (!exactMatchFound && path.length > selectedLength) {
      selected = original;
      selectedLength = path.length;
    }
  }

  return selected;
}

String _canonicalMenuPath(String raw) {
  final value = raw.trim();
  final path = value.length > 1 && value.endsWith('/')
      ? value.substring(0, value.length - 1)
      : value;
  return switch (path) {
    '/historial_ventas' => '/mesero/historial',
    '/cierre_caja' => '/mesero/cierre-caja',
    '/administrar_mesas' => '/mesero',
    _ => path,
  };
}
