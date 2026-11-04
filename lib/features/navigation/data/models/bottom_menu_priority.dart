import '../models/user_menu_item.dart';

/// Los favoritos personales tienen prioridad en la barra inferior.
/// Se recibe solamente el menú ya autorizado por el backend y filtrado
/// por rol: nunca se crean nuevos destinos por una preferencia guardada.
List<UserMenuItem> prioritizeBottomMenuItems(
  List<UserMenuItem> allowed, {
  required bool showFavoritesInMenu,
}) {
  final originalIndex = <UserMenuItem, int>{
    for (var i = 0; i < allowed.length; i++) allowed[i]: i,
  };
  final favorites = showFavoritesInMenu
      ? allowed.where((item) => item.isFavorite && item.path.isNotEmpty).toList()
      : <UserMenuItem>[];
  favorites.sort((a, b) {
    final left = a.personalOrder ?? 999999;
    final right = b.personalOrder ?? 999999;
    return left == right
        ? originalIndex[a]!.compareTo(originalIndex[b]!)
        : left.compareTo(right);
  });
  final favoriteSet = favorites.toSet();
  return [
    ...favorites,
    ...allowed.where((item) => !favoriteSet.contains(item)),
  ];
}

  
/// Mueve un módulo a una posición humana (1 = primera fila) sin depender
/// del arrastre. No muta la colección original.
List<T> moveMenuItemToPosition<T>(
  List<T> items, {
  required int fromIndex,
  required int position,
}) {
  if (fromIndex < 0 || fromIndex >= items.length ||
      position < 1 || position > items.length) {
    return List<T>.of(items);
  }
  final reordered = List<T>.of(items);
  final item = reordered.removeAt(fromIndex);
  reordered.insert(position - 1, item);
  return reordered;
}


/// Mueve el módulo identificado por su ID real, no por un índice de widget
/// que podría haber cambiado durante una reconstrucción de la lista.
List<UserMenuItem> moveMenuItemByIdToPosition(
  List<UserMenuItem> items, {
  required int menuId,
  required int position,
}) {
  final fromIndex = items.indexWhere((item) => item.menuId == menuId);
  return moveMenuItemToPosition(
    items, fromIndex: fromIndex, position: position);
}

/// Ordenamiento del modal "Más": favoritos primero y módulos restantes
/// agrupados sin repetir rutas. Recibe únicamente opciones ya autorizadas.
class MoreMenuSections {
  const MoreMenuSections({required this.favorites, required this.remaining});

  final List<UserMenuItem> favorites;
  final List<UserMenuItem> remaining;

  bool get isEmpty => favorites.isEmpty && remaining.isEmpty;
}

/// Al buscar, la lista de entrada ya contiene únicamente coincidencias.
/// La deduplicación se hace por ruta real, también entre categorías.
MoreMenuSections splitMoreMenuFavorites(
  List<UserMenuItem> permittedItems, {
  required bool showFavoritesInMenu,
}) {
  final unique = <String, UserMenuItem>{};
  for (final item in permittedItems) {
    final path = item.path.trim();
    if (path.isEmpty) continue;
    final previous = unique[path];
    if (previous == null || (!previous.isFavorite && item.isFavorite)) {
      unique[path] = item;
    }
  }
  final ordered = prioritizeBottomMenuItems(
    unique.values.toList(growable: false),
    showFavoritesInMenu: showFavoritesInMenu,
  );
  final favorites = <UserMenuItem>[];
  final remaining = <UserMenuItem>[];
  for (final item in ordered) {
    if (showFavoritesInMenu && item.isFavorite) {
      favorites.add(item);
    } else {
      remaining.add(item);
    }
  }
  return MoreMenuSections(favorites: favorites, remaining: remaining);
}
