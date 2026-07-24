/// Modelo de request para crear o actualizar registros del módulo Roles.
class RolesRequestModel {
  const RolesRequestModel({
    this.roleDescripcion,
    this.roleNombre,
    this.tiusId,
  });

  final String? roleDescripcion;
  final String? roleNombre;
  final int? tiusId;

  factory RolesRequestModel.fromJson(Map<String, dynamic> json) => RolesRequestModel(
      roleDescripcion: json['roleDescripcion']?.toString(),
      roleNombre: json['roleNombre']?.toString(),
      tiusId: (json['tiusId'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      if (roleDescripcion != null) 'roleDescripcion': roleDescripcion,
      if (roleNombre != null) 'roleNombre': roleNombre,
      if (tiusId != null) 'tiusId': tiusId,
  };
}
