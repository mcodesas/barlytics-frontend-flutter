import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/navigation/data/models/user_menu_item.dart';
import 'package:barlytics_frontend/features/navigation/data/models/bottom_menu_priority.dart';

void main() {
  const sales = UserMenuItem(
    keyName: 'ventas', title: 'Ventas', path: '/ventas',
    menuId: 10, personalOrder: 3, isFavorite: false);
  const report = UserMenuItem(
    keyName: 'reportes', title: 'Reportes', path: '/reportes',
    menuId: 11, personalOrder: 2, isFavorite: true);
  const inventory = UserMenuItem(
    keyName: 'inventario', title: 'Inventario', path: '/inventario',
    menuId: 12, personalOrder: 0, isFavorite: true);
  const others = UserMenuItem(
    keyName: 'pedidos_compra', title: 'Pedidos',
    path: '/pedidos-compra', menuId: 13, personalOrder: 1);

  test('Favs aparecen antes de módulos normales, con orden personal', () {
    final list = prioritizeBottomMenuItems(
      [sales, report, others, inventory], showFavoritesInMenu: true);
    expect(list.map((v) => v.menuId).toList(), [12, 11, 10, 13]);
  });

  test('Solo Inicio mantiene el orden normal de la barra', () {
    final list = prioritizeBottomMenuItems(
      [sales, report, others, inventory], showFavoritesInMenu: false);
    expect(list.map((v) => v.menuId).toList(), [10, 11, 13, 12]);
  });

  test('Nunca introduce menús no autorizados', () {
    final list = prioritizeBottomMenuItems(
      [sales, inventory], showFavoritesInMenu: true);
    expect(list.map((v) => v.menuId).toList(), [12, 10]);
    expect(list.any((v) => v.menuId == 11), false);
  });

  test('En Más los favoritos aparecen primero y no se repiten en categorías', () {
    final menu = splitMoreMenuFavorites(
      [sales, report, inventory, report, others],
      showFavoritesInMenu: true,
    );
    expect(menu.favorites.map((m) => m.menuId), [12, 11]);
    expect(menu.remaining.map((m) => m.menuId), [10, 13]);
    expect([...menu.favorites, ...menu.remaining]
        .map((m) => m.path).toSet().length, 4);
  });

  test('Favoritos de Solo inicio siguen como módulos normales en Más', () {
    final menu = splitMoreMenuFavorites(
      [sales, report, inventory],
      showFavoritesInMenu: false,
    );
    expect(menu.favorites, isEmpty);
    expect(menu.remaining.map((m) => m.menuId), [10, 11, 12]);
  });

  test('La búsqueda conserva el favorito aunque la categoría no coincida', () {
    final menu = splitMoreMenuFavorites([report],
      showFavoritesInMenu: true);
    expect(menu.favorites.single.title, 'Reportes');
    expect(menu.remaining, isEmpty);
  });

  test('Posición 1 mueve un módulo al principio sin arrastrar', () {
    final result = moveMenuItemToPosition(
      ['ventas', 'inventario', 'reportes', 'pedidos'],
      fromIndex: 3, position: 1);
    expect(result, ['pedidos', 'ventas', 'inventario', 'reportes']);
  });

  test('Posición final desplaza un módulo al último lugar', () {
    final result = moveMenuItemToPosition(
      ['ventas', 'inventario', 'reportes'],
      fromIndex: 0, position: 3);
    expect(result, ['inventario', 'reportes', 'ventas']);
  });

  test('Número 1 coloca la opción indicada arriba aunque los índices cambien', () {
    final moved = moveMenuItemByIdToPosition(
      [sales, report, inventory, others], menuId: 13, position: 1);
    expect(moved.map((v) => v.menuId).toList(), [13, 10, 11, 12]);

    final movedAgain = moveMenuItemByIdToPosition(
      moved, menuId: 12, position: 2);
    expect(movedAgain.map((v) => v.menuId).toList(), [13, 12, 10, 11]);
    expect(movedAgain.map((v) => v.menuId).toSet().length, 4);
  });

  test('La posición por ID no modifica la lista ante ID desconocido', () {
    const original = [sales, report, inventory, others];
    final result = moveMenuItemByIdToPosition(
        original, menuId: 9999, position: 1);
    expect(result, original);
  });

  test('Posiciones inválidas nunca pierden ni duplican módulos', () {
    const list = ['ventas', 'inventario', 'reportes'];
    expect(moveMenuItemToPosition(list, fromIndex: 1, position: 0), list);
    expect(moveMenuItemToPosition(list, fromIndex: 1, position: 4), list);
    expect(moveMenuItemToPosition(list, fromIndex: 9, position: 1), list);
  });
}
