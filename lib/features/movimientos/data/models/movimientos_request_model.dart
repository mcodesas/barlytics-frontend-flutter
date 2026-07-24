/// Modelo de request para crear o actualizar registros del módulo Movimientos.
class MovimientosRequestModel {
  const MovimientosRequestModel({
    this.moviCantidad,
    this.moviCantidadCapturada,
    this.moviFactorConversion,
    this.moviUnidad,
    this.moviMotivo,
    this.moviReferencia,
    this.moviOperacion,
    this.prodId,
    this.sucuId,
    this.timoId,
  });

  /// Cantidad capturada por el usuario. En una compra puede ser el número de
  /// paquetes; en ajustes y salidas corresponde a unidades.
  final double? moviCantidad;

  /// Campos devueltos por el backend y útiles al editar/auditar.
  final double? moviCantidadCapturada;
  final double? moviFactorConversion;
  final String? moviUnidad;

  final String? moviMotivo;
  final String? moviReferencia;
  final String? moviOperacion;
  final int? prodId;
  final int? sucuId;
  final int? timoId;

  factory MovimientosRequestModel.fromJson(Map<String, dynamic> json) =>
      MovimientosRequestModel(
        moviCantidad: (json['moviCantidad'] as num?)?.toDouble(),
        moviCantidadCapturada:
            (json['moviCantidadCapturada'] as num?)?.toDouble(),
        moviFactorConversion:
            (json['moviFactorConversion'] as num?)?.toDouble(),
        moviUnidad: json['moviUnidad']?.toString(),
        moviMotivo: json['moviMotivo']?.toString(),
        moviReferencia: json['moviReferencia']?.toString(),
        moviOperacion: json['moviOperacion']?.toString(),
        prodId: (json['prodId'] as num?)?.toInt(),
        sucuId: (json['sucuId'] as num?)?.toInt(),
        timoId: (json['timoId'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (moviCantidad != null) 'moviCantidad': moviCantidad,
        if (moviCantidadCapturada != null)
          'moviCantidadCapturada': moviCantidadCapturada,
        if (moviFactorConversion != null)
          'moviFactorConversion': moviFactorConversion,
        if (moviUnidad != null) 'moviUnidad': moviUnidad,
        if (moviMotivo != null) 'moviMotivo': moviMotivo,
        if (moviReferencia != null) 'moviReferencia': moviReferencia,
        if (moviOperacion != null) 'moviOperacion': moviOperacion,
        if (prodId != null) 'prodId': prodId,
        if (sucuId != null) 'sucuId': sucuId,
        if (timoId != null) 'timoId': timoId,
      };
}
