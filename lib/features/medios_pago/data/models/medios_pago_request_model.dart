/// Modelo de request para crear o actualizar registros del módulo Medios pago.
class MediosPagoRequestModel {
  const MediosPagoRequestModel({
    this.mepaDescripcion,
    this.mepaEstado,
    this.mepaNombre,
  });

  final String? mepaDescripcion;
  final int? mepaEstado;
  final String? mepaNombre;

  factory MediosPagoRequestModel.fromJson(Map<String, dynamic> json) => MediosPagoRequestModel(
      mepaDescripcion: json['mepaDescripcion']?.toString(),
      mepaEstado: (json['mepaEstado'] as num?)?.toInt(),
      mepaNombre: json['mepaNombre']?.toString(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      if (mepaDescripcion != null) 'mepaDescripcion': mepaDescripcion,
      if (mepaEstado != null) 'mepaEstado': mepaEstado,
      if (mepaNombre != null) 'mepaNombre': mepaNombre,
  };
}
