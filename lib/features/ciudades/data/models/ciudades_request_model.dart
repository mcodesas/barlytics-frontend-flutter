/// Modelo de request para crear o actualizar registros del módulo Ciudades.
class CiudadesRequestModel {
  const CiudadesRequestModel({
    this.ciudCodigoDane,
    this.ciudCodigoPostal,
    this.ciudEstado,
    this.ciudNombre,
    this.regiId,
    this.zohoId,
  });

  final String? ciudCodigoDane;
  final String? ciudCodigoPostal;
  final int? ciudEstado;
  final String? ciudNombre;
  final int? regiId;
  final int? zohoId;

  factory CiudadesRequestModel.fromJson(Map<String, dynamic> json) => CiudadesRequestModel(
      ciudCodigoDane: json['ciudCodigoDane']?.toString(),
      ciudCodigoPostal: json['ciudCodigoPostal']?.toString(),
      ciudEstado: (json['ciudEstado'] as num?)?.toInt(),
      ciudNombre: json['ciudNombre']?.toString(),
      regiId: (json['regiId'] as num?)?.toInt(),
      zohoId: (json['zohoId'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      if (ciudCodigoDane != null) 'ciudCodigoDane': ciudCodigoDane,
      if (ciudCodigoPostal != null) 'ciudCodigoPostal': ciudCodigoPostal,
      if (ciudEstado != null) 'ciudEstado': ciudEstado,
      if (ciudNombre != null) 'ciudNombre': ciudNombre,
      if (regiId != null) 'regiId': regiId,
      if (zohoId != null) 'zohoId': zohoId,
  };
}
