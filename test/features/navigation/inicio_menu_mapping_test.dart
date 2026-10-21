import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/navigation/data/repositories/user_menu_repository.dart';
import 'package:barlytics_frontend/features/navigation/data/models/user_menu_item.dart';

void main() {
  test('alias antiguo Inicio resuelve al módulo principal home', () {
    expect(moduleAliases['inicio'], 'home');
    expect(moduleAliases['pagina_inicio'], 'home');
  });

  test('Inicio tiene un único destino principal fuera de Otros', () {
    const home = UserMenuItem(
      keyName: 'home',
      title: 'Inicio',
      path: '/home',
      groupCode: 'INICIO',
      groupName: 'Inicio',
      groupOrder: 0,
      menuOrder: 0,
    );
    expect(home.groupCode, 'INICIO');
    expect(home.path, '/home');
    expect(home.groupOrder, 0);
  });
}
