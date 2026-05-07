/// Modelo de respuesta del módulo Movimientos basado en la colección Postman.
class MovimientosResponseModel {
  const MovimientosResponseModel({
    this.moviId,
    this.prodId,
    this.sucuId,
    this.timoId,
    this.moviCantidad,
    this.moviMotivo,
    this.moviReferencia,
    this.moviRegistradoPor,
    this.moviFechaCambio,
  });

  final int? moviId;
  final int? prodId;
  final int? sucuId;
  final int? timoId;
  final double? moviCantidad;
  final String? moviMotivo;
  final String? moviReferencia;
  final String? moviRegistradoPor;
  final String? moviFechaCambio;

  factory MovimientosResponseModel.fromJson(Map<String, dynamic> json) => MovimientosResponseModel(
      moviId: (json['moviId'] as num?)?.toInt(),
      prodId: (json['prodId'] as num?)?.toInt(),
      sucuId: (json['sucuId'] as num?)?.toInt(),
      timoId: (json['timoId'] as num?)?.toInt(),
      moviCantidad: (json['moviCantidad'] as num?)?.toDouble(),
      moviMotivo: json['moviMotivo']?.toString(),
      moviReferencia: json['moviReferencia']?.toString(),
      moviRegistradoPor: json['moviRegistradoPor']?.toString(),
      moviFechaCambio: json['moviFechaCambio']?.toString(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      'moviId': moviId,
      'prodId': prodId,
      'sucuId': sucuId,
      'timoId': timoId,
      'moviCantidad': moviCantidad,
      'moviMotivo': moviMotivo,
      'moviReferencia': moviReferencia,
      'moviRegistradoPor': moviRegistradoPor,
      'moviFechaCambio': moviFechaCambio,
  };

  Object? get id => moviId;

  String label() {
    final values = <Object?>[moviId, prodId, sucuId, timoId];
    return values.where((e) => e != null && e.toString().isNotEmpty).join(' · ');
  }
}
