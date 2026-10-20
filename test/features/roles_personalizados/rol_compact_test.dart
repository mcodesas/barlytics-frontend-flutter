import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/roles_personalizados/data/models/rol_personalizado_model.dart';

void main() {
  test('interpreta listado compacto sin objetos de menú duplicados', () {
    final role = RolPersonalizadoModel.fromJson({
      'roleId': 100,
      'emprId': 10,
      'sucuId': null,
      'roleNombre': 'Caja personalizada',
      'roleDescripcion': 'Permisos de caja',
      'roleEstado': 1,
      'alcance': 'EMPRESA',
      'usuariosAsignados': 3,
      'menuIds': [147, 119, 210],
    });

    expect(role.roleId, 100);
    expect(role.menuIds, [147, 119, 210]);
    expect(role.menus, isEmpty);
    expect(role.usuariosAsignados, 3);
    expect(role.active, isTrue);
  });
}
