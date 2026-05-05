/// Modelo de request para crear o actualizar registros del módulo Zonas horarias.
class ZonasHorariasRequestModel {
  const ZonasHorariasRequestModel({
    this.zohoAbreviatura,
    this.zohoDescripcion,
    this.zohoEstado,
    this.zohoNombre,
    this.zohoOffsetOut,
  });

  final String? zohoAbreviatura;
  final String? zohoDescripcion;
  final int? zohoEstado;
  final String? zohoNombre;
  final String? zohoOffsetOut;

  factory ZonasHorariasRequestModel.fromJson(Map<String, dynamic> json) => ZonasHorariasRequestModel(
      zohoAbreviatura: json['zohoAbreviatura']?.toString(),
      zohoDescripcion: json['zohoDescripcion']?.toString(),
      zohoEstado: (json['zohoEstado'] as num?)?.toInt(),
      zohoNombre: json['zohoNombre']?.toString(),
      zohoOffsetOut: json['zohoOffsetOut']?.toString(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      if (zohoAbreviatura != null) 'zohoAbreviatura': zohoAbreviatura,
      if (zohoDescripcion != null) 'zohoDescripcion': zohoDescripcion,
      if (zohoEstado != null) 'zohoEstado': zohoEstado,
      if (zohoNombre != null) 'zohoNombre': zohoNombre,
      if (zohoOffsetOut != null) 'zohoOffsetOut': zohoOffsetOut,
  };
}
