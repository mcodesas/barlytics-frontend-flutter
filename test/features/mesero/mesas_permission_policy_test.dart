import 'package:barlytics_frontend/features/mesero/domain/mesas_permission_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rol personalizado con Mesas puede crear y modificar descripción', () {
    const keys = {'mesas'};
    expect(MesasPermissionPolicy.canCreateOrEdit(
      menuKeys: keys, isCashier: false,
    ), isTrue);
    expect(MesasPermissionPolicy.canEditExisting(
      menuKeys: keys, isCashier: false, inactive: false,
    ), isTrue);
    expect(MesasPermissionPolicy.canDeleteOrChangeState(
      menuKeys: keys, isCashier: false,
    ), isFalse);
    expect(MesasPermissionPolicy.canEditExisting(
      menuKeys: keys, isCashier: false, inactive: true,
    ), isFalse);
  });

  test('Sin Mesas no se concede acceso de escritura', () {
    const keys = {'productos', 'historial_ventas'};
    expect(MesasPermissionPolicy.canCreateOrEdit(
      menuKeys: keys, isCashier: false,
    ), isFalse);
    expect(MesasPermissionPolicy.canEditExisting(
      menuKeys: keys, isCashier: false, inactive: false,
    ), isFalse);
  });

  test('Administrar mesas permite crear, editar e inactivar', () {
    const keys = {'administrar_mesas'};
    expect(MesasPermissionPolicy.canCreateOrEdit(
      menuKeys: keys, isCashier: false,
    ), isTrue);
    expect(MesasPermissionPolicy.canDeleteOrChangeState(
      menuKeys: keys, isCashier: false,
    ), isTrue);
    expect(MesasPermissionPolicy.canEditExisting(
      menuKeys: keys, isCashier: false, inactive: true,
    ), isTrue);
  });

  test('Cajero conserva permisos históricos', () {
    expect(MesasPermissionPolicy.canCreateOrEdit(
      menuKeys: const {}, isCashier: true,
    ), isTrue);
    expect(MesasPermissionPolicy.canDeleteOrChangeState(
      menuKeys: const {}, isCashier: true,
    ), isTrue);
  });
}
