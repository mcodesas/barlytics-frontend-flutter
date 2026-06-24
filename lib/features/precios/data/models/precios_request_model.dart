/// Modelo de request para crear o actualizar registros del módulo Precios.
class PreciosRequestModel {
  const PreciosRequestModel({
    this.precEstado,
    this.precFechaInicia,
    this.precValorCompra,
    this.precValorVenta,
    this.prodId,
    this.sucuId,
    this.precFechaFinaliza,
    this.precAplicaImpuesto,
    this.precPorcentajeImpuesto,
    this.precValorImpuesto,
  });

  final int? precEstado;
  final String? precFechaInicia;
  final double? precValorCompra;
  final double? precValorVenta;
  final int? prodId;
  final int? sucuId;
  final String? precFechaFinaliza;
  final int? precAplicaImpuesto;
  final double? precPorcentajeImpuesto;
  final double? precValorImpuesto;

  factory PreciosRequestModel.fromJson(Map<String, dynamic> json) => PreciosRequestModel(
        precEstado: (json['precEstado'] as num?)?.toInt(),
        precFechaInicia: json['precFechaInicia']?.toString(),
        precValorCompra: (json['precValorCompra'] as num?)?.toDouble(),
        precValorVenta: (json['precValorVenta'] as num?)?.toDouble(),
        prodId: (json['prodId'] as num?)?.toInt(),
        sucuId: (json['sucuId'] as num?)?.toInt(),
        precFechaFinaliza: json['precFechaFinaliza']?.toString(),
        precAplicaImpuesto: (json['precAplicaImpuesto'] as num?)?.toInt(),
        precPorcentajeImpuesto: (json['precPorcentajeImpuesto'] as num?)?.toDouble(),
        precValorImpuesto: (json['precValorImpuesto'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (precEstado != null) 'precEstado': precEstado,
        if (precFechaInicia != null) 'precFechaInicia': precFechaInicia,
        if (precValorCompra != null) 'precValorCompra': precValorCompra,
        if (precValorVenta != null) 'precValorVenta': precValorVenta,
        if (prodId != null) 'prodId': prodId,
        if (sucuId != null) 'sucuId': sucuId,
        if (precFechaFinaliza != null) 'precFechaFinaliza': precFechaFinaliza,
        if (precAplicaImpuesto != null) 'precAplicaImpuesto': precAplicaImpuesto,
        if (precPorcentajeImpuesto != null) 'precPorcentajeImpuesto': precPorcentajeImpuesto,
        if (precValorImpuesto != null) 'precValorImpuesto': precValorImpuesto,
      };
}
