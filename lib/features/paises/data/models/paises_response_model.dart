/// Modelo de respuesta del módulo Paises basado en la colección Postman.
class PaisesResponseModel {
  const PaisesResponseModel({
    this.paisId,
    this.zohoId,
    this.paisNombre,
    this.paisCodigo,
    this.paisEstado,
    this.paisRegistradoPor,
    this.paisFechaCambio,
  });

  final int? paisId;
  final int? zohoId;
  final String? paisNombre;
  final String? paisCodigo;
  final int? paisEstado;
  final String? paisRegistradoPor;
  final String? paisFechaCambio;

  factory PaisesResponseModel.fromJson(Map<String, dynamic> json) => PaisesResponseModel(
      paisId: (json['paisId'] as num?)?.toInt(),
      zohoId: (json['zohoId'] as num?)?.toInt(),
      paisNombre: json['paisNombre']?.toString(),
      paisCodigo: json['paisCodigo']?.toString(),
      paisEstado: (json['paisEstado'] as num?)?.toInt(),
      paisRegistradoPor: json['paisRegistradoPor']?.toString(),
      paisFechaCambio: json['paisFechaCambio']?.toString(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      'paisId': paisId,
      'zohoId': zohoId,
      'paisNombre': paisNombre,
      'paisCodigo': paisCodigo,
      'paisEstado': paisEstado,
      'paisRegistradoPor': paisRegistradoPor,
      'paisFechaCambio': paisFechaCambio,
  };

  Object? get id => paisId;

  String label() {
    final values = <Object?>[paisId, zohoId, paisNombre, paisCodigo];
    return values.where((e) => e != null && e.toString().isNotEmpty).join(' · ');
  }
}
