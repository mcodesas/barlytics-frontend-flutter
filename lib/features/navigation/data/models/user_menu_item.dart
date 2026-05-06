/// Opción de navegación autorizada para el usuario autenticado.
///
/// No representa directamente una tabla, sino la unión funcional de MENUS,
/// OPCIONMENU y ROLES que el frontend necesita para pintar el menú.
class UserMenuItem {
  const UserMenuItem({
    required this.keyName,
    required this.title,
    required this.path,
    this.description,
    this.menuId,
    this.roleId,
    this.optionId,
    this.system = false,
  });

  final String keyName;
  final String title;
  final String path;
  final String? description;
  final int? menuId;
  final int? roleId;
  final int? optionId;
  final bool system;
}
