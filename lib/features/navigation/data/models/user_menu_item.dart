class UserMenuItem {
  const UserMenuItem({
    required this.keyName,
    required this.title,
    required this.path,
    this.description,
    this.menuId,
    this.roleId,
    this.optionId,
    this.roles = const <String>[],
    this.system = false,
  });

  final String keyName;
  final String title;
  final String path;
  final String? description;
  final int? menuId;
  final int? roleId;
  final int? optionId;
  final List<String> roles;
  final bool system;

  factory UserMenuItem.fromJson(Map<String, dynamic> json) {
    final parametro = json['parametro']?.toString() ?? json['menuParametro']?.toString() ?? '';
    final title = json['nombre']?.toString() ?? json['opcionNombre']?.toString() ?? json['menuNombre']?.toString() ?? parametro;
    return UserMenuItem(
      keyName: parametro,
      title: title,
      path: '/$parametro',
      description: json['descripcion']?.toString() ?? json['opcionDescripcion']?.toString(),
      menuId: _toInt(json['menuId']),
      roleId: _toInt(json['roleId']),
      optionId: _toInt(json['opcionId']),
      roles: (json['roles'] as List? ?? const <Object?>[]).map((e) => e.toString()).toList(growable: false),
    );
  }

  UserMenuItem copyWith({String? keyName, String? title, String? path}) => UserMenuItem(
        keyName: keyName ?? this.keyName,
        title: title ?? this.title,
        path: path ?? this.path,
        description: description,
        menuId: menuId,
        roleId: roleId,
        optionId: optionId,
        roles: roles,
        system: system,
      );

  static int? _toInt(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }
}
