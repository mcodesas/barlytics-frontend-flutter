/// Modelo de respuesta del módulo Opciones menu basado en la colección Postman.
class OpcionesMenuResponseModel {
  const OpcionesMenuResponseModel({
    this.opmeId,
    this.menuId,
    this.roleId,
    this.opmeNombre,
    this.opmeDescripcion,
    this.opmeCodigotraduccion,
    this.opmeRegistradoPor,
    this.opmeFechaCambio,
  });

  final int? opmeId;
  final int? menuId;
  final int? roleId;
  final String? opmeNombre;
  final String? opmeDescripcion;
  final String? opmeCodigotraduccion;
  final String? opmeRegistradoPor;
  final String? opmeFechaCambio;

  factory OpcionesMenuResponseModel.fromJson(Map<String, dynamic> json) => OpcionesMenuResponseModel(
      opmeId: (json['opmeId'] as num?)?.toInt(),
      menuId: (json['menuId'] as num?)?.toInt(),
      roleId: (json['roleId'] as num?)?.toInt(),
      opmeNombre: json['opmeNombre']?.toString(),
      opmeDescripcion: json['opmeDescripcion']?.toString(),
      opmeCodigotraduccion: json['opmeCodigotraduccion']?.toString(),
      opmeRegistradoPor: json['opmeRegistradoPor']?.toString(),
      opmeFechaCambio: json['opmeFechaCambio']?.toString(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      'opmeId': opmeId,
      'menuId': menuId,
      'roleId': roleId,
      'opmeNombre': opmeNombre,
      'opmeDescripcion': opmeDescripcion,
      'opmeCodigotraduccion': opmeCodigotraduccion,
      'opmeRegistradoPor': opmeRegistradoPor,
      'opmeFechaCambio': opmeFechaCambio,
  };

  Object? get id => opmeId;

  String label() {
    final values = <Object?>[opmeId, menuId, roleId, opmeNombre];
    return values.where((e) => e != null && e.toString().isNotEmpty).join(' · ');
  }
}
