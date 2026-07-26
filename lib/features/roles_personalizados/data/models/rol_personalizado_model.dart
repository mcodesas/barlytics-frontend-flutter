class MenuAsignableModel {
  const MenuAsignableModel({
    required this.menuId,
    required this.nombre,
    required this.descripcion,
    required this.parametro,
  });

  final int menuId;
  final String nombre;
  final String descripcion;
  final String parametro;

  factory MenuAsignableModel.fromJson(Map<String, dynamic> json) => MenuAsignableModel(
        menuId: (json['menuId'] as num).toInt(),
        nombre: json['nombre']?.toString() ?? 'Opción',
        descripcion: json['descripcion']?.toString() ?? '',
        parametro: json['parametro']?.toString() ?? '',
      );
}

class RolPersonalizadoModel {
  const RolPersonalizadoModel({
    required this.roleId,
    required this.emprId,
    required this.roleNombre,
    required this.roleDescripcion,
    required this.roleEstado,
    required this.alcance,
    required this.usuariosAsignados,
    required this.menuIds,
    required this.menus,
    this.sucuId,
    this.roleFechaCambio,
  });

  final int roleId;
  final int emprId;
  final int? sucuId;
  final String roleNombre;
  final String roleDescripcion;
  final int roleEstado;
  final String alcance;
  final int usuariosAsignados;
  final List<int> menuIds;
  final List<MenuAsignableModel> menus;
  final String? roleFechaCambio;

  bool get active => roleEstado == 1;
  bool get companyWide => sucuId == null;

  factory RolPersonalizadoModel.fromJson(Map<String, dynamic> json) => RolPersonalizadoModel(
        roleId: (json['roleId'] as num).toInt(),
        emprId: (json['emprId'] as num).toInt(),
        sucuId: (json['sucuId'] as num?)?.toInt(),
        roleNombre: json['roleNombre']?.toString() ?? 'Rol personalizado',
        roleDescripcion: json['roleDescripcion']?.toString() ?? '',
        roleEstado: (json['roleEstado'] as num?)?.toInt() ?? 1,
        alcance: json['alcance']?.toString() ?? 'EMPRESA',
        usuariosAsignados: (json['usuariosAsignados'] as num?)?.toInt() ?? 0,
        menuIds: (json['menuIds'] as List? ?? const <Object?>[])
            .whereType<num>()
            .map((value) => value.toInt())
            .toList(),
        menus: (json['menus'] as List? ?? const <Object?>[])
            .whereType<Map>()
            .map((item) => MenuAsignableModel.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
        roleFechaCambio: json['roleFechaCambio']?.toString(),
      );
}
