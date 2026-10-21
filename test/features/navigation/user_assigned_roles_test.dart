import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/navigation/data/models/user_menu_item.dart';
import 'package:barlytics_frontend/features/navigation/presentation/providers/user_assigned_roles_provider.dart';
import 'package:barlytics_frontend/features/navigation/presentation/providers/user_menu_provider.dart';

void main() {
  test('selector muestra nombres reales, nunca el tipo genérico', () {
    final caja = UserAssignedRole.fromJson({
      'roleId': 51,
      'roleNombre': 'Caja y Mesas',
      'roleTipo': 'PERSONALIZADO',
    });
    final cocina = UserAssignedRole.fromJson({
      'roleId': 52,
      'roleNombre': 'Cocina nocturna',
      'roleTipo': 'PERSONALIZADO',
    });
    expect(caja.name, 'Caja y Mesas');
    expect(cocina.name, 'Cocina nocturna');
    expect(caja.selectionKey, customRoleSelectionKey(51));
    expect(cocina.selectionKey, customRoleSelectionKey(52));
    expect(caja.selectionKey, isNot(cocina.selectionKey));
    expect(customRoleIdFromSelection(caja.selectionKey), 51);
    final cajero = UserAssignedRole.fromJson({
      'roleId': 31, 'roleNombre': 'CAJERO', 'roleTipo': 'PREDEFINIDO',
    });
    expect(cajero.selectionKey, systemRoleSelectionKey(31));
  });

  test('cada rol personalizado ve solo sus permisos por ID', () {
    const menus = <UserMenuItem>[
      UserMenuItem(keyName: 'home', title: 'Inicio', path: '/home',
          roleIds: [51, 52],
          customOrderByRole: {51: 0, 52: 2}),
      UserMenuItem(keyName: 'mesero_productos', title: 'Listar productos',
          path: '/mesero/productos', roles: ['CAJERO'], roleIds: [51, 31],
          customOrderByRole: {51: 1}),
      UserMenuItem(keyName: 'comandas', title: 'Comandas', path: '/comandas',
          roleIds: [52], customOrderByRole: {52: 0}),
    ];

    final caja = filterMenusBySelectedRoles(menus, {customRoleSelectionKey(51)});
    expect(caja.map((item) => item.keyName), ['home', 'mesero_productos']);
    final cocina = filterMenusBySelectedRoles(menus, {customRoleSelectionKey(52)});
    expect(cocina.map((item) => item.keyName), ['home', 'comandas']);

    expect(orderMenusForCustomRole(cocina, roleId: 52)
        .map((item) => item.keyName), ['comandas', 'home']);

    final cajero = filterMenusBySelectedRoles(menus, {systemRoleSelectionKey(31)});
    expect(cajero.map((item) => item.keyName), ['mesero_productos']);
    final todos = filterMenusBySelectedRoles(menus, null);
    expect(todos.length, 3);
  });

  test('parsea IDs y orden por rol desde el JSON del backend', () {
    final menu = UserMenuItem.fromJson({
      'menuId': 9,
      'nombre': 'Listar productos',
      'parametro': 'mesero_productos',
      'roleIds': [31, 51],
      'ordenPorRol': {'51': 0},
      'tiposRoles': ['PREDEFINIDO', 'PERSONALIZADO'],
      'ordenPersonalizado': 0,
    });
    expect(menu.roleIds, [31, 51]);
    expect(menu.customOrderByRole[51], 0);
  });
}
