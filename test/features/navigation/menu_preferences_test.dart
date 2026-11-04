import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/navigation/data/models/user_menu_item.dart';
import 'package:barlytics_frontend/features/navigation/presentation/providers/menu_preferences_provider.dart';

void main() {
  const sale = UserMenuItem(
      keyName: 'ventas', title: 'Ventas', path: '/ventas',
      menuId: 7, groupCode: 'OPERACION', menuOrder: 2);
  const reports = UserMenuItem(
      keyName: 'reportes', title: 'Reportes', path: '/reportes',
      menuId: 8, groupCode: 'REPORTES', menuOrder: 1);

  test('No modifica el orden original mientras no haya preferencias', () {
    final result = personalizeAuthorizedMenu(
      [sale, reports], const MenuPreferences());
    expect(result.map((e) => e.keyName).toList(), ['ventas', 'reportes']);
    expect(result.where((e) => e.isFavorite), isEmpty);
  });

  test('Los favoritos se ordenan según la configuración del usuario', () {
    final preferences = MenuPreferences(entries: {
      7: const MenuPreferenceEntry(menuId: 7, order: 1, favorite: false),
      8: const MenuPreferenceEntry(menuId: 8, order: 0, favorite: true),
    });
    final result = personalizeAuthorizedMenu([sale, reports], preferences);
    expect(result.map((e) => e.keyName).toList(), ['reportes', 'ventas']);
    expect(result.first.isFavorite, isTrue);
    expect(result.last.isFavorite, isFalse);
  });

  test('No agrega módulos no autorizados aunque tengan preferencia', () {
    final preferences = MenuPreferences(entries: {
      99: const MenuPreferenceEntry(menuId: 99, order: 0, favorite: true),
    });
    final result = personalizeAuthorizedMenu([sale], preferences);
    expect(result.length, 1);
    expect(result.single.keyName, 'ventas');
    expect(result.single.isFavorite, isFalse);
  });

  test('Filtra contenido y mantiene las preferencias por menuId', () {
    final preferences = MenuPreferences.fromJson({
      'mostrarFavoritos': 'INICIO',
      'items': [
        {'menuId': 8, 'orden': 0, 'favorito': true},
        {'menuId': 7, 'orden': 1, 'favorito': false},
      ],
    });
    expect(preferences.showInMenu, isFalse);
    expect(preferences.showOnHome, isTrue);
    final onlySalesRole = personalizeAuthorizedMenu([sale], preferences);
    expect(onlySalesRole.map((e) => e.keyName).toList(), ['ventas']);
    expect(onlySalesRole.single.isFavorite, isFalse);
  });
}
