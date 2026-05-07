/// Modelo de request para crear o actualizar registros del módulo Movimientos.
class MovimientosRequestModel {
  const MovimientosRequestModel({
    this.moviCantidad,
    this.moviMotivo,
    this.moviReferencia,
    this.prodId,
    this.sucuId,
    this.timoId,
  });

  final double? moviCantidad;
  final String? moviMotivo;
  final String? moviReferencia;
  final int? prodId;
  final int? sucuId;
  final int? timoId;

  factory MovimientosRequestModel.fromJson(Map<String, dynamic> json) => MovimientosRequestModel(
      moviCantidad: (json['moviCantidad'] as num?)?.toDouble(),
      moviMotivo: json['moviMotivo']?.toString(),
      moviReferencia: json['moviReferencia']?.toString(),
      prodId: (json['prodId'] as num?)?.toInt(),
      sucuId: (json['sucuId'] as num?)?.toInt(),
      timoId: (json['timoId'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      if (moviCantidad != null) 'moviCantidad': moviCantidad,
      if (moviMotivo != null) 'moviMotivo': moviMotivo,
      if (moviReferencia != null) 'moviReferencia': moviReferencia,
      if (prodId != null) 'prodId': prodId,
      if (sucuId != null) 'sucuId': sucuId,
      if (timoId != null) 'timoId': timoId,
  };
}
