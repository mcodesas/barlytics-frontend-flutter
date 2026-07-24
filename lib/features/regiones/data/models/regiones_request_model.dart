/// Modelo de request para crear o actualizar registros del módulo Regiones.
class RegionesRequestModel {
  const RegionesRequestModel({
    this.paisId,
    this.regiCodigo,
    this.regiNombre,
    this.zohoId,
    this.regiEstado,
  });

  final int? paisId;
  final String? regiCodigo;
  final String? regiNombre;
  final int? zohoId;
  final int? regiEstado;

  factory RegionesRequestModel.fromJson(Map<String, dynamic> json) => RegionesRequestModel(
      paisId: (json['paisId'] as num?)?.toInt(),
      regiCodigo: json['regiCodigo']?.toString(),
      regiNombre: json['regiNombre']?.toString(),
      zohoId: (json['zohoId'] as num?)?.toInt(),
      regiEstado: (json['regiEstado'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      if (paisId != null) 'paisId': paisId,
      if (regiCodigo != null) 'regiCodigo': regiCodigo,
      if (regiNombre != null) 'regiNombre': regiNombre,
      if (zohoId != null) 'zohoId': zohoId,
      if (regiEstado != null) 'regiEstado': regiEstado,
  };
}
