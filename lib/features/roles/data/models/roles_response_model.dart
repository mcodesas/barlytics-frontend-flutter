/// Modelo de respuesta del módulo Roles basado en la colección Postman.
class RolesResponseModel {
  const RolesResponseModel({
    this.roleId,
    this.tiusId,
    this.roleNombre,
    this.roleDescripcion,
    this.roleRegistradoPor,
    this.roleFechaCambio,
  });

  final int? roleId;
  final int? tiusId;
  final String? roleNombre;
  final String? roleDescripcion;
  final String? roleRegistradoPor;
  final String? roleFechaCambio;

  factory RolesResponseModel.fromJson(Map<String, dynamic> json) => RolesResponseModel(
      roleId: (json['roleId'] as num?)?.toInt(),
      tiusId: (json['tiusId'] as num?)?.toInt(),
      roleNombre: json['roleNombre']?.toString(),
      roleDescripcion: json['roleDescripcion']?.toString(),
      roleRegistradoPor: json['roleRegistradoPor']?.toString(),
      roleFechaCambio: json['roleFechaCambio']?.toString(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      'roleId': roleId,
      'tiusId': tiusId,
      'roleNombre': roleNombre,
      'roleDescripcion': roleDescripcion,
      'roleRegistradoPor': roleRegistradoPor,
      'roleFechaCambio': roleFechaCambio,
  };

  Object? get id => roleId;

  String label() {
    final values = <Object?>[roleId, tiusId, roleNombre, roleDescripcion];
    return values.where((e) => e != null && e.toString().isNotEmpty).join(' · ');
  }
}
