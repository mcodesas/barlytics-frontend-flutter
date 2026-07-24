/// Modelo de respuesta del módulo Menus basado en la colección Postman.
class MenusResponseModel {
  const MenusResponseModel({
    this.menuId,
    this.menuNombre,
    this.menuDescripcion,
    this.menuParametro,
    this.menuRegistradoPor,
    this.menuFechaCambio,
  });

  final int? menuId;
  final String? menuNombre;
  final String? menuDescripcion;
  final String? menuParametro;
  final String? menuRegistradoPor;
  final String? menuFechaCambio;

  factory MenusResponseModel.fromJson(Map<String, dynamic> json) => MenusResponseModel(
      menuId: (json['menuId'] as num?)?.toInt(),
      menuNombre: json['menuNombre']?.toString(),
      menuDescripcion: json['menuDescripcion']?.toString(),
      menuParametro: json['menuParametro']?.toString(),
      menuRegistradoPor: json['menuRegistradoPor']?.toString(),
      menuFechaCambio: json['menuFechaCambio']?.toString(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      'menuId': menuId,
      'menuNombre': menuNombre,
      'menuDescripcion': menuDescripcion,
      'menuParametro': menuParametro,
      'menuRegistradoPor': menuRegistradoPor,
      'menuFechaCambio': menuFechaCambio,
  };

  Object? get id => menuId;

  String label() {
    final values = <Object?>[menuId, menuNombre, menuDescripcion, menuParametro];
    return values.where((e) => e != null && e.toString().isNotEmpty).join(' · ');
  }
}
