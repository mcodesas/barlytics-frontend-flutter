/// Modelo de respuesta del módulo Zonas horarias basado en la colección Postman.
class ZonasHorariasResponseModel {
  const ZonasHorariasResponseModel({
    this.zohoId,
    this.zohoNombre,
    this.zohoDescripcion,
    this.zohoAbreviatura,
    this.zohoOffsetOut,
    this.zohoEstado,
    this.zohoRegistradoPor,
    this.zohoFechaCambio,
  });

  final int? zohoId;
  final String? zohoNombre;
  final String? zohoDescripcion;
  final String? zohoAbreviatura;
  final String? zohoOffsetOut;
  final int? zohoEstado;
  final String? zohoRegistradoPor;
  final String? zohoFechaCambio;

  factory ZonasHorariasResponseModel.fromJson(Map<String, dynamic> json) => ZonasHorariasResponseModel(
      zohoId: (json['zohoId'] as num?)?.toInt(),
      zohoNombre: json['zohoNombre']?.toString(),
      zohoDescripcion: json['zohoDescripcion']?.toString(),
      zohoAbreviatura: json['zohoAbreviatura']?.toString(),
      zohoOffsetOut: json['zohoOffsetOut']?.toString(),
      zohoEstado: (json['zohoEstado'] as num?)?.toInt(),
      zohoRegistradoPor: json['zohoRegistradoPor']?.toString(),
      zohoFechaCambio: json['zohoFechaCambio']?.toString(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      'zohoId': zohoId,
      'zohoNombre': zohoNombre,
      'zohoDescripcion': zohoDescripcion,
      'zohoAbreviatura': zohoAbreviatura,
      'zohoOffsetOut': zohoOffsetOut,
      'zohoEstado': zohoEstado,
      'zohoRegistradoPor': zohoRegistradoPor,
      'zohoFechaCambio': zohoFechaCambio,
  };

  Object? get id => zohoId;

  String label() {
    final values = <Object?>[zohoId, zohoNombre, zohoDescripcion, zohoAbreviatura];
    return values.where((e) => e != null && e.toString().isNotEmpty).join(' · ');
  }
}
