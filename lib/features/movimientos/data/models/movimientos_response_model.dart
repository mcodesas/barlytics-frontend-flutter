/// Modelo de respuesta del módulo Movimientos basado en la API del backend.
class MovimientosResponseModel {
  const MovimientosResponseModel({
    this.moviId,
    this.prodId,
    this.sucuId,
    this.timoId,
    this.moviCantidad,
    this.moviCantidadCapturada,
    this.moviUnidad,
    this.moviFactorConversion,
    this.moviMotivo,
    this.moviReferencia,
    this.moviOperacion,
    this.moviRegistradoPor,
    this.moviFechaCambio,
  });

  final int? moviId;
  final int? prodId;
  final int? sucuId;
  final int? timoId;

  /// Unidades efectivas aplicadas al inventario.
  final double? moviCantidad;

  /// Cantidad que ingresó el usuario, por ejemplo 1 paquete.
  final double? moviCantidadCapturada;
  final String? moviUnidad;
  final double? moviFactorConversion;

  final String? moviMotivo;
  final String? moviReferencia;
  final String? moviOperacion;
  final String? moviRegistradoPor;
  final String? moviFechaCambio;

  factory MovimientosResponseModel.fromJson(Map<String, dynamic> json) =>
      MovimientosResponseModel(
        moviId: (json['moviId'] as num?)?.toInt(),
        prodId: (json['prodId'] as num?)?.toInt(),
        sucuId: (json['sucuId'] as num?)?.toInt(),
        timoId: (json['timoId'] as num?)?.toInt(),
        moviCantidad: (json['moviCantidad'] as num?)?.toDouble(),
        moviCantidadCapturada:
            (json['moviCantidadCapturada'] as num?)?.toDouble(),
        moviUnidad: json['moviUnidad']?.toString(),
        moviFactorConversion:
            (json['moviFactorConversion'] as num?)?.toDouble(),
        moviMotivo: json['moviMotivo']?.toString(),
        moviReferencia: json['moviReferencia']?.toString(),
        moviOperacion: json['moviOperacion']?.toString(),
        moviRegistradoPor: json['moviRegistradoPor']?.toString(),
        moviFechaCambio: json['moviFechaCambio']?.toString(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'moviId': moviId,
        'prodId': prodId,
        'sucuId': sucuId,
        'timoId': timoId,
        // El formulario debe editar la cantidad originalmente capturada,
        // no las unidades ya convertidas que afectaron el inventario.
        'moviCantidad': moviCantidadCapturada ?? moviCantidad,
        'moviCantidadInventario': moviCantidad,
        'moviCantidadCapturada': moviCantidadCapturada,
        'moviUnidad': moviUnidad,
        'moviFactorConversion': moviFactorConversion,
        'moviMotivo': moviMotivo,
        'moviReferencia': moviReferencia,
        'moviOperacion': moviOperacion,
        'moviRegistradoPor': moviRegistradoPor,
        'moviFechaCambio': moviFechaCambio,
      };

  Object? get id => moviId;

  String label() {
    final values = <Object?>[moviId, prodId, sucuId, timoId];
    return values.where((e) => e != null && e.toString().isNotEmpty).join(' · ');
  }
}
