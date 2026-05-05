/// Modelo de request para crear o actualizar registros del módulo Opciones menu.
class OpcionesMenuRequestModel {
  const OpcionesMenuRequestModel({
    this.menuId,
    this.opmeCodigotraduccion,
    this.opmeDescripcion,
    this.opmeNombre,
    this.roleId,
  });

  final int? menuId;
  final String? opmeCodigotraduccion;
  final String? opmeDescripcion;
  final String? opmeNombre;
  final int? roleId;

  factory OpcionesMenuRequestModel.fromJson(Map<String, dynamic> json) => OpcionesMenuRequestModel(
      menuId: (json['menuId'] as num?)?.toInt(),
      opmeCodigotraduccion: json['opmeCodigotraduccion']?.toString(),
      opmeDescripcion: json['opmeDescripcion']?.toString(),
      opmeNombre: json['opmeNombre']?.toString(),
      roleId: (json['roleId'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      if (menuId != null) 'menuId': menuId,
      if (opmeCodigotraduccion != null) 'opmeCodigotraduccion': opmeCodigotraduccion,
      if (opmeDescripcion != null) 'opmeDescripcion': opmeDescripcion,
      if (opmeNombre != null) 'opmeNombre': opmeNombre,
      if (roleId != null) 'roleId': roleId,
  };
}
