/// Medio de pago del catálogo con la parametrización de la sucursal autenticada.
class MediosPagoResponseModel {
  const MediosPagoResponseModel({
    this.mepaId,
    this.sucursalMedioPagoId,
    this.sucuId,
    this.mepaNombre,
    this.mepaDescripcion,
    this.mepaEstado,
    this.mepaQr,
    this.mepaRegistradoPor,
    this.mepaFechaCambio,
  });

  final int? mepaId;
  final int? sucursalMedioPagoId;
  final int? sucuId;
  final String? mepaNombre;
  final String? mepaDescripcion;
  final int? mepaEstado;
  final String? mepaQr;
  final String? mepaRegistradoPor;
  final String? mepaFechaCambio;

  factory MediosPagoResponseModel.fromJson(Map<String, dynamic> json) => MediosPagoResponseModel(
        mepaId: (json['mepaId'] as num?)?.toInt(),
        sucursalMedioPagoId: (json['sucursalMedioPagoId'] as num?)?.toInt(),
        sucuId: (json['sucuId'] as num?)?.toInt(),
        mepaNombre: json['mepaNombre']?.toString(),
        mepaDescripcion: json['mepaDescripcion']?.toString(),
        mepaEstado: (json['mepaEstado'] as num?)?.toInt(),
        mepaQr: json['mepaQr']?.toString(),
        mepaRegistradoPor: json['mepaRegistradoPor']?.toString(),
        mepaFechaCambio: json['mepaFechaCambio']?.toString(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'mepaId': mepaId,
        'sucursalMedioPagoId': sucursalMedioPagoId,
        'sucuId': sucuId,
        'mepaNombre': mepaNombre,
        'mepaDescripcion': mepaDescripcion,
        'mepaEstado': mepaEstado,
        'mepaQr': mepaQr,
        'mepaRegistradoPor': mepaRegistradoPor,
        'mepaFechaCambio': mepaFechaCambio,
      };

  Object? get id => mepaId;

  String label() => [mepaNombre, mepaEstado == 1 ? 'Activo' : 'Inactivo']
      .where((value) => value != null && value.toString().isNotEmpty)
      .join(' · ');
}
