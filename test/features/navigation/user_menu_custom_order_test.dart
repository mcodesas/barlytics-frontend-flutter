import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/navigation/data/models/user_menu_item.dart';
import 'package:barlytics_frontend/features/navigation/presentation/providers/user_menu_provider.dart';

void main() {
  test('Inicio conserva el primer lugar configurado desde PostgreSQL', () {
    const items = <UserMenuItem>[
      UserMenuItem(keyName: 'productos', title: 'Productos',
          path: '/productos', customOrder: 2),
      UserMenuItem(keyName: 'mesero', title: 'Vender / Mesas',
          path: '/mesero', customOrder: 1),
      UserMenuItem(keyName: 'home', title: 'Inicio',
          path: '/home', customOrder: 0),
    ];

    final ordered = orderMenusForCustomRole(items);
    expect(ordered.map((item) => item.keyName).toList(),
        ['home', 'mesero', 'productos']);
  });

  test('El modelo convierte los roles y su orden desde la respuesta HTTP', () {
    final item = UserMenuItem.fromJson({
      'menuId': 100,
      'nombre': 'Inicio',
      'parametro': 'home',
      'roles': ['Cajero - Mesero - conteo'],
      'tiposRoles': ['PERSONALIZADO'],
      'ordenPersonalizado': 0,
    });

    expect(item.customOrder, 0);
    expect(item.roleTypes, contains('PERSONALIZADO'));
    expect(item.copyWith(title: 'Inicio').customOrder, 0);
  });
}
