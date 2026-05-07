/// Modelo de respuesta del módulo Precios basado en la colección Postman.
class PreciosResponseModel {
  const PreciosResponseModel({
    this.precId,
    this.prodId,
    this.sucuId,
    this.precEstado,
    this.precValorVenta,
    this.precValorCompra,
    this.precFechaInicia,
    this.precFechaFinaliza,
    this.precRegistradoPor,
    this.precFechaCambio,
  });

  final int? precId;
  final int? prodId;
  final int? sucuId;
  final int? precEstado;
  final double? precValorVenta;
  final double? precValorCompra;
  final String? precFechaInicia;
  final String? precFechaFinaliza;
  final String? precRegistradoPor;
  final String? precFechaCambio;

  factory PreciosResponseModel.fromJson(Map<String, dynamic> json) => PreciosResponseModel(
      precId: (json['precId'] as num?)?.toInt(),
      prodId: (json['prodId'] as num?)?.toInt(),
      sucuId: (json['sucuId'] as num?)?.toInt(),
      precEstado: (json['precEstado'] as num?)?.toInt(),
      precValorVenta: (json['precValorVenta'] as num?)?.toDouble(),
      precValorCompra: (json['precValorCompra'] as num?)?.toDouble(),
      precFechaInicia: json['precFechaInicia']?.toString(),
      precFechaFinaliza: json['precFechaFinaliza']?.toString(),
      precRegistradoPor: json['precRegistradoPor']?.toString(),
      precFechaCambio: json['precFechaCambio']?.toString(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      'precId': precId,
      'prodId': prodId,
      'sucuId': sucuId,
      'precEstado': precEstado,
      'precValorVenta': precValorVenta,
      'precValorCompra': precValorCompra,
      'precFechaInicia': precFechaInicia,
      'precFechaFinaliza': precFechaFinaliza,
      'precRegistradoPor': precRegistradoPor,
      'precFechaCambio': precFechaCambio,
  };

  Object? get id => precId;

  String label() {
    final values = <Object?>[precId, prodId, sucuId, precEstado];
    return values.where((e) => e != null && e.toString().isNotEmpty).join(' · ');
  }
}
