import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/navigation/data/models/user_menu_item.dart';
import 'package:barlytics_frontend/features/navigation/domain/manager_navigation_filters.dart';

void main() {
  const home = UserMenuItem(
    keyName: 'home',
    title: 'Inicio',
    path: '/home',
    groupCode: 'INICIO',
    bottomCode: 'INICIO',
    bottomVisible: true,
  );
  const homeAlias = UserMenuItem(
    keyName: 'inicio',
    title: 'Inicio',
    path: '/inicio',
    bottomVisible: true,
  );
  const orders = UserMenuItem(
    keyName: 'comandas',
    title: 'Comandas',
    path: '/comandas',
    bottomCode: 'OPERACION',
    bottomVisible: true,
  );
  const sales = UserMenuItem(
    keyName: 'ventas',
    title: 'Ventas',
    path: '/ventas',
    bottomCode: 'VENTAS',
    bottomVisible: true,
  );
  const migratedHome = UserMenuItem(
    keyName: 'pagina_principal',
    title: 'Principal',
    path: '/inicio-antiguo',
    bottomCode: 'INICIO',
    bottomVisible: true,
  );

  test('Inicio sólo existe como acceso estructural y no como segundo grupo', () {
    final bottom = managerBottomCandidates([
      home, homeAlias, orders, sales, migratedHome,
    ]);
    expect(bottom.map((item) => item.title), ['Comandas', 'Ventas']);
    expect(bottom.any((item) => item.bottomCode == 'INICIO'), isFalse);
  });

  test('Inicio no aparece dentro de la hoja Más opciones', () {
    final more = managerMoreCandidates([home, homeAlias, orders]);
    expect(more.map((item) => item.title), ['Comandas']);
  });

  test('menús válidos no se filtran por su título accidentalmente', () {
    const valid = UserMenuItem(
      keyName: 'panel_inicio_turno',
      title: 'Inicio de turno',
      path: '/turno',
      bottomCode: 'CAJA',
      bottomVisible: true,
    );
    expect(isStructuralHomeBottomEntry(valid), isFalse);
    expect(managerBottomCandidates([valid]), [valid]);
  });
}
