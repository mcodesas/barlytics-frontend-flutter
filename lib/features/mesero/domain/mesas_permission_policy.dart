/// Permisos de mesas según la opción autorizada del rol activo.
///
/// `mesas`: atención, creación y edición de mesas, sin operaciones destructivas.
/// `administrar_mesas`: además puede eliminar/inactivar y cambiar estado.
/// Cajero: mantiene todos los permisos históricos de administración.
class MesasPermissionPolicy {
  const MesasPermissionPolicy._();

  static bool canCreateOrEdit({
    required Set<String> menuKeys,
    required bool isCashier,
  }) =>
      isCashier ||
      menuKeys.contains('administrar_mesas') ||
      menuKeys.contains('mesas');

  static bool canDeleteOrChangeState({
    required Set<String> menuKeys,
    required bool isCashier,
  }) =>
      isCashier || menuKeys.contains('administrar_mesas');

  static bool canEditExisting({
    required Set<String> menuKeys,
    required bool isCashier,
    required bool inactive,
  }) =>
      canCreateOrEdit(menuKeys: menuKeys, isCashier: isCashier) &&
      (!inactive || canDeleteOrChangeState(
          menuKeys: menuKeys, isCashier: isCashier));
}
