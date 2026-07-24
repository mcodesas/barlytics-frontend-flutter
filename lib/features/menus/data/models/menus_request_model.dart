/// Modelo de request para crear o actualizar registros del módulo Menus.
class MenusRequestModel {
  const MenusRequestModel({
    this.menuDescripcion,
    this.menuNombre,
    this.menuParametro,
  });

  final String? menuDescripcion;
  final String? menuNombre;
  final String? menuParametro;

  factory MenusRequestModel.fromJson(Map<String, dynamic> json) => MenusRequestModel(
      menuDescripcion: json['menuDescripcion']?.toString(),
      menuNombre: json['menuNombre']?.toString(),
      menuParametro: json['menuParametro']?.toString(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      if (menuDescripcion != null) 'menuDescripcion': menuDescripcion,
      if (menuNombre != null) 'menuNombre': menuNombre,
      if (menuParametro != null) 'menuParametro': menuParametro,
  };
}
