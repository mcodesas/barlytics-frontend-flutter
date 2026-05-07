/// Modelo de respuesta del módulo Medios pago basado en la colección Postman.
class MediosPagoResponseModel {
  const MediosPagoResponseModel({
    this.mepaId,
    this.mepaNombre,
    this.mepaDescripcion,
    this.mepaEstado,
    this.mepaRegistradoPor,
    this.mepaFechaCambio,
  });

  final int? mepaId;
  final String? mepaNombre;
  final String? mepaDescripcion;
  final int? mepaEstado;
  final String? mepaRegistradoPor;
  final String? mepaFechaCambio;

  factory MediosPagoResponseModel.fromJson(Map<String, dynamic> json) => MediosPagoResponseModel(
      mepaId: (json['mepaId'] as num?)?.toInt(),
      mepaNombre: json['mepaNombre']?.toString(),
      mepaDescripcion: json['mepaDescripcion']?.toString(),
      mepaEstado: (json['mepaEstado'] as num?)?.toInt(),
      mepaRegistradoPor: json['mepaRegistradoPor']?.toString(),
      mepaFechaCambio: json['mepaFechaCambio']?.toString(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      'mepaId': mepaId,
      'mepaNombre': mepaNombre,
      'mepaDescripcion': mepaDescripcion,
      'mepaEstado': mepaEstado,
      'mepaRegistradoPor': mepaRegistradoPor,
      'mepaFechaCambio': mepaFechaCambio,
  };

  Object? get id => mepaId;

  String label() {
    final values = <Object?>[mepaId, mepaNombre, mepaDescripcion, mepaEstado];
    return values.where((e) => e != null && e.toString().isNotEmpty).join(' · ');
  }
}
