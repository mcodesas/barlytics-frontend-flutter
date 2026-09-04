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
    this.groupCode = 'OTROS',
    this.groupName = 'Otros',
    this.groupIcon = 'more_horiz',
    this.groupOrder = 99,
    this.menuOrder = 99,
    this.bottomCode = 'OTROS',
    this.bottomName = 'Otros',
    this.bottomIcon = 'more_horiz',
    this.bottomOrder = 99,
    this.bottomVisible = false,
    this.bottomPrimary = false,
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
  final String groupCode;
  final String groupName;
  final String groupIcon;
  final int groupOrder;
  final int menuOrder;
  final String bottomCode;
  final String bottomName;
  final String bottomIcon;
  final int bottomOrder;
  final bool bottomVisible;
  final bool bottomPrimary;
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
      groupCode: _text(json['grupoCodigo'], 'OTROS'),
      groupName: _text(json['grupoNombre'], 'Otros'),
      groupIcon: _text(json['grupoIcono'], 'more_horiz'),
      groupOrder: _toInt(json['grupoOrden']) ?? 99,
      menuOrder: _toInt(json['menuOrden']) ?? 99,
      bottomCode: _text(json['bottomCodigo'], 'OTROS'),
      bottomName: _text(json['bottomNombre'], 'Otros'),
      bottomIcon: _text(json['bottomIcono'], 'more_horiz'),
      bottomOrder: _toInt(json['bottomOrden']) ?? 99,
      bottomVisible: (_toInt(json['bottomVisible']) ?? 0) == 1,
      bottomPrimary: (_toInt(json['bottomPrincipal']) ?? 0) == 1,
    );
  }

  UserMenuItem copyWith({
    String? keyName,
    String? title,
    String? path,
    List<String>? roles,
    String? groupCode,
    String? groupName,
    String? groupIcon,
    int? groupOrder,
    int? menuOrder,
    String? bottomCode,
    String? bottomName,
    String? bottomIcon,
    int? bottomOrder,
    bool? bottomVisible,
    bool? bottomPrimary,
  }) =>
      UserMenuItem(
        keyName: keyName ?? this.keyName,
        title: title ?? this.title,
        path: path ?? this.path,
        description: description,
        menuId: menuId,
        roleId: roleId,
        optionId: optionId,
        roles: roles ?? this.roles,
        groupCode: groupCode ?? this.groupCode,
        groupName: groupName ?? this.groupName,
        groupIcon: groupIcon ?? this.groupIcon,
        groupOrder: groupOrder ?? this.groupOrder,
        menuOrder: menuOrder ?? this.menuOrder,
        bottomCode: bottomCode ?? this.bottomCode,
        bottomName: bottomName ?? this.bottomName,
        bottomIcon: bottomIcon ?? this.bottomIcon,
        bottomOrder: bottomOrder ?? this.bottomOrder,
        bottomVisible: bottomVisible ?? this.bottomVisible,
        bottomPrimary: bottomPrimary ?? this.bottomPrimary,
        system: system,
      );

  static int? _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static String _text(Object? value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }
}
