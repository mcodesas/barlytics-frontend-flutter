/// Modelo de request para crear o actualizar registros del módulo Pagos.
class PagosRequestModel {
  const PagosRequestModel({
    this.cuveId,
    this.mepaId,
    this.pacvMonto,
    this.pacvObservacion,
    this.pacvValorRecibido,
    this.pacvCambio,
  });

  final int? cuveId;
  final int? mepaId;
  final double? pacvMonto;
  final double? pacvObservacion;
  final double? pacvValorRecibido;
  final double? pacvCambio;

  factory PagosRequestModel.fromJson(Map<String, dynamic> json) => PagosRequestModel(
      cuveId: (json['cuveId'] as num?)?.toInt(),
      mepaId: (json['mepaId'] as num?)?.toInt(),
      pacvMonto: (json['pacvMonto'] as num?)?.toDouble(),
      pacvObservacion: (json['pacvObservacion'] as num?)?.toDouble(),
      pacvValorRecibido: (json['pacvValorRecibido'] as num?)?.toDouble(),
      pacvCambio: (json['pacvCambio'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      if (cuveId != null) 'cuveId': cuveId,
      if (mepaId != null) 'mepaId': mepaId,
      if (pacvMonto != null) 'pacvMonto': pacvMonto,
      if (pacvObservacion != null) 'pacvObservacion': pacvObservacion,
      if (pacvValorRecibido != null) 'pacvValorRecibido': pacvValorRecibido,
      if (pacvCambio != null) 'pacvCambio': pacvCambio,
  };
}
