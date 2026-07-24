/// Modelo de request para crear o actualizar registros del módulo Medios pago.
class MediosPagoRequestModel {
  const MediosPagoRequestModel({
    this.mepaDescripcion,
    this.mepaEstado,
    this.mepaNombre,
    this.mepaQr,
  });

  final String? mepaDescripcion;
  final int? mepaEstado;
  final String? mepaNombre;
  final String? mepaQr;

  factory MediosPagoRequestModel.fromJson(Map<String, dynamic> json) => MediosPagoRequestModel(
      mepaDescripcion: json['mepaDescripcion']?.toString(),
      mepaEstado: (json['mepaEstado'] as num?)?.toInt(),
      mepaNombre: json['mepaNombre']?.toString(),
      mepaQr: json['mepaQr']?.toString(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      if (mepaDescripcion != null) 'mepaDescripcion': mepaDescripcion,
      if (mepaEstado != null) 'mepaEstado': mepaEstado,
      if (mepaNombre != null) 'mepaNombre': mepaNombre,
      if (mepaQr != null) 'mepaQr': mepaQr,
  };
}
