import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/navigation/data/models/user_menu_item.dart';
import 'package:barlytics_frontend/features/navigation/presentation/providers/user_assigned_roles_provider.dart';
import 'package:barlytics_frontend/features/navigation/presentation/providers/user_menu_provider.dart';

UserMenuItem module(String key, Map<int, int> positions) => UserMenuItem(
  keyName: key,
  title: key,
  path: '/$key',
  roleIds: const [11, 12],
  defaultOrderByRole: positions,
  groupOrder: 10,
  menuOrder: 10,
);

void main() {
  test('Dos roles usan prioridades diferentes sin alterarse', () {
    final modules = [
      module('inventario', const {11: 0, 12: 2}),
      module('ventas', const {11: 2, 12: 0}),
      module('caja', const {11: 1, 12: 1}),
    ];

    final role11 = orderMenusForSelectedDefaultRoles(
      modules, {systemRoleSelectionKey(11)});
    expect(role11.map((e) => e.keyName).toList(),
        ['inventario', 'caja', 'ventas']);

    final role12 = orderMenusForSelectedDefaultRoles(
      modules, {systemRoleSelectionKey(12)});
    expect(role12.map((e) => e.keyName).toList(),
        ['ventas', 'caja', 'inventario']);
  });

  test('Menús sin prioridad configurada aparecen después de los priorizados', () {
    final items = [
      module('otra_opcion', const {}),
      module('roles', const {11: 0}),
    ];
    final sorted = orderMenusForSelectedDefaultRoles(
      items, {systemRoleSelectionKey(11)});
    expect(sorted.first.keyName, 'roles');
    expect(sorted.last.keyName, 'otra_opcion');
  });

  test('Sin rol seleccionado conserva orden original', () {
    final items = [
      module('caja', const {11: 3}),
      module('ventas', const {11: 1}),
    ];
    expect(orderMenusForSelectedDefaultRoles(items, null), items);
  });

  test('Parses priority map from authenticated-menu contract', () {
    final item = UserMenuItem.fromJson({
      'parametro': 'inventario',
      'nombre': 'Inventario',
      'ordenPredefinido': 0,
      'ordenPredefinidoPorRol': {'11': 0, '12': 2},
      'grupoOrden': 20,
      'menuOrden': 30,
    });
    expect(item.defaultRoleOrder, 0);
    expect(item.defaultOrderByRole[11], 0);
    expect(item.defaultOrderByRole[12], 2);
  });
}
