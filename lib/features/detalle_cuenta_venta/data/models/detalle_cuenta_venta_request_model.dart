/// Modelo de request para crear o actualizar registros del módulo Detalle cuenta venta.
class DetalleCuentaVentaRequestModel {
  const DetalleCuentaVentaRequestModel({
    this.cuveId,
    this.decvCantidad,
    this.decvSubtotal,
    this.precId,
  });

  final int? cuveId;
  final double? decvCantidad;
  final double? decvSubtotal;
  final int? precId;

  factory DetalleCuentaVentaRequestModel.fromJson(Map<String, dynamic> json) => DetalleCuentaVentaRequestModel(
      cuveId: (json['cuveId'] as num?)?.toInt(),
      decvCantidad: (json['decvCantidad'] as num?)?.toDouble(),
      decvSubtotal: (json['decvSubtotal'] as num?)?.toDouble(),
      precId: (json['precId'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      if (cuveId != null) 'cuveId': cuveId,
      if (decvCantidad != null) 'decvCantidad': decvCantidad,
      if (decvSubtotal != null) 'decvSubtotal': decvSubtotal,
      if (precId != null) 'precId': precId,
  };
}
