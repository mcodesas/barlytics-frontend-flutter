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
