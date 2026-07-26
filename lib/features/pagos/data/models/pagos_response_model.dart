/// Modelo de respuesta del módulo Pagos basado en la colección Postman.
class PagosResponseModel {
  const PagosResponseModel({
    this.pacvId,
    this.cuveId,
    this.mepaId,
    this.pacvMonto,
    this.pacvObservacion,
    this.pacvValorRecibido,
    this.pacvCambio,
    this.pacvRegistradoPor,
    this.pacvFechaCambio,
  });

  final int? pacvId;
  final int? cuveId;
  final int? mepaId;
  final double? pacvMonto;
  final double? pacvObservacion;
  final double? pacvValorRecibido;
  final double? pacvCambio;
  final String? pacvRegistradoPor;
  final String? pacvFechaCambio;

  factory PagosResponseModel.fromJson(Map<String, dynamic> json) => PagosResponseModel(
      pacvId: (json['pacvId'] as num?)?.toInt(),
      cuveId: (json['cuveId'] as num?)?.toInt(),
      mepaId: (json['mepaId'] as num?)?.toInt(),
      pacvMonto: (json['pacvMonto'] as num?)?.toDouble(),
      pacvObservacion: (json['pacvObservacion'] as num?)?.toDouble(),
      pacvValorRecibido: (json['pacvValorRecibido'] as num?)?.toDouble(),
      pacvCambio: (json['pacvCambio'] as num?)?.toDouble(),
      pacvRegistradoPor: json['pacvRegistradoPor']?.toString(),
      pacvFechaCambio: json['pacvFechaCambio']?.toString(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      'pacvId': pacvId,
      'cuveId': cuveId,
      'mepaId': mepaId,
      'pacvMonto': pacvMonto,
      'pacvObservacion': pacvObservacion,
      'pacvValorRecibido': pacvValorRecibido,
      'pacvCambio': pacvCambio,
      'pacvRegistradoPor': pacvRegistradoPor,
      'pacvFechaCambio': pacvFechaCambio,
  };

  Object? get id => pacvId;

  String label() {
    final values = <Object?>[pacvId, cuveId, mepaId, pacvMonto];
    return values.where((e) => e != null && e.toString().isNotEmpty).join(' · ');
  }
}
