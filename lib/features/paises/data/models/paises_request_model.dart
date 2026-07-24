/// Modelo de request para crear o actualizar registros del módulo Paises.
class PaisesRequestModel {
  const PaisesRequestModel({
    this.paisCodigo,
    this.paisEstado,
    this.paisNombre,
    this.zohoId,
  });

  final String? paisCodigo;
  final int? paisEstado;
  final String? paisNombre;
  final int? zohoId;

  factory PaisesRequestModel.fromJson(Map<String, dynamic> json) => PaisesRequestModel(
      paisCodigo: json['paisCodigo']?.toString(),
      paisEstado: (json['paisEstado'] as num?)?.toInt(),
      paisNombre: json['paisNombre']?.toString(),
      zohoId: (json['zohoId'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      if (paisCodigo != null) 'paisCodigo': paisCodigo,
      if (paisEstado != null) 'paisEstado': paisEstado,
      if (paisNombre != null) 'paisNombre': paisNombre,
      if (zohoId != null) 'zohoId': zohoId,
  };
}
