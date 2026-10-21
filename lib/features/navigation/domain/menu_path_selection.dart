/// Determina qué opción del menú corresponde realmente a la ruta visible.
/// Prioridad: ruta literal exacta, alias equivalente y finalmente ruta padre
/// más específica. Evita seleccionar /mesero al visitar /mesero/productos,
/// pero también distingue /administrar_mesas de /mesero.
String? mostSpecificMenuPath(String currentPath, Iterable<String> menuPaths) {
  final currentLiteral = _normalizePath(currentPath);
  final currentCanonical = _canonicalMenuPath(currentLiteral);
  String? selected;
  var bestPriority = 0;
  var bestLength = -1;

  for (final candidate in menuPaths) {
    final original = candidate.trim();
    if (original.isEmpty) continue;
    final candidateLiteral = _normalizePath(original);
    final canonical = _canonicalMenuPath(candidateLiteral);

    final priority = currentLiteral == candidateLiteral
        ? 3
        : currentCanonical == canonical
            ? 2
            : canonical != '/home' &&
                    currentCanonical.startsWith('$canonical/')
                ? 1
                : 0;
    if (priority == 0) continue;

    if (priority > bestPriority ||
        (priority == bestPriority && canonical.length > bestLength)) {
      bestPriority = priority;
      bestLength = canonical.length;
      selected = original;
    }
  }
  return selected;
}

String _normalizePath(String raw) {
  final path = raw.trim();
  return path.length > 1 && path.endsWith('/')
      ? path.substring(0, path.length - 1)
      : path;
}

String _canonicalMenuPath(String raw) {
  return switch (_normalizePath(raw)) {
    '/historial_ventas' => '/mesero/historial',
    '/cierre_caja' => '/mesero/cierre-caja',
    '/administrar_mesas' => '/mesero',
    final path => path,
  };
}
