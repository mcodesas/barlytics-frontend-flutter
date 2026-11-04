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
