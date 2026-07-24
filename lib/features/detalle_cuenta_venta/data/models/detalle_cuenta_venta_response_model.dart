/// Modelo de respuesta del módulo Detalle cuenta venta basado en la colección Postman.
class DetalleCuentaVentaResponseModel {
  const DetalleCuentaVentaResponseModel({
    this.decvId,
    this.cuveId,
    this.precId,
    this.decvCantidad,
    this.decvSubtotal,
    this.decvFechaCambio,
    this.decvRegistradoPor,
  });

  final int? decvId;
  final int? cuveId;
  final int? precId;
  final double? decvCantidad;
  final double? decvSubtotal;
  final String? decvFechaCambio;
  final String? decvRegistradoPor;

  factory DetalleCuentaVentaResponseModel.fromJson(Map<String, dynamic> json) => DetalleCuentaVentaResponseModel(
      decvId: (json['decvId'] as num?)?.toInt(),
      cuveId: (json['cuveId'] as num?)?.toInt(),
      precId: (json['precId'] as num?)?.toInt(),
      decvCantidad: (json['decvCantidad'] as num?)?.toDouble(),
      decvSubtotal: (json['decvSubtotal'] as num?)?.toDouble(),
      decvFechaCambio: json['decvFechaCambio']?.toString(),
      decvRegistradoPor: json['decvRegistradoPor']?.toString(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      'decvId': decvId,
      'cuveId': cuveId,
      'precId': precId,
      'decvCantidad': decvCantidad,
      'decvSubtotal': decvSubtotal,
      'decvFechaCambio': decvFechaCambio,
      'decvRegistradoPor': decvRegistradoPor,
  };

  Object? get id => decvId;

  String label() {
    final values = <Object?>[decvId, cuveId, precId, decvCantidad];
    return values.where((e) => e != null && e.toString().isNotEmpty).join(' · ');
  }
}
