/// Modelo de respuesta del módulo Regiones basado en la colección Postman.
class RegionesResponseModel {
  const RegionesResponseModel({
    this.regiId,
    this.paisId,
    this.zohoId,
    this.regiNombre,
    this.regiCodigo,
    this.regiEstado,
    this.regiRegistradoPor,
    this.regiFechaCambio,
  });

  final int? regiId;
  final int? paisId;
  final int? zohoId;
  final String? regiNombre;
  final String? regiCodigo;
  final int? regiEstado;
  final String? regiRegistradoPor;
  final String? regiFechaCambio;

  factory RegionesResponseModel.fromJson(Map<String, dynamic> json) => RegionesResponseModel(
      regiId: (json['regiId'] as num?)?.toInt(),
      paisId: (json['paisId'] as num?)?.toInt(),
      zohoId: (json['zohoId'] as num?)?.toInt(),
      regiNombre: json['regiNombre']?.toString(),
      regiCodigo: json['regiCodigo']?.toString(),
      regiEstado: (json['regiEstado'] as num?)?.toInt(),
      regiRegistradoPor: json['regiRegistradoPor']?.toString(),
      regiFechaCambio: json['regiFechaCambio']?.toString(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      'regiId': regiId,
      'paisId': paisId,
      'zohoId': zohoId,
      'regiNombre': regiNombre,
      'regiCodigo': regiCodigo,
      'regiEstado': regiEstado,
      'regiRegistradoPor': regiRegistradoPor,
      'regiFechaCambio': regiFechaCambio,
  };

  Object? get id => regiId;

  String label() {
    final values = <Object?>[regiId, paisId, zohoId, regiNombre];
    return values.where((e) => e != null && e.toString().isNotEmpty).join(' · ');
  }
}
