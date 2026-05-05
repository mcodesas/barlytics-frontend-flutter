/// Modelo de request para crear o actualizar registros del módulo Inventario.
class InventarioRequestModel {
  const InventarioRequestModel({
    this.invtCantidad,
    this.invtFecha,
    this.prodId,
    this.sucuId,
  });

  final double? invtCantidad;
  final String? invtFecha;
  final int? prodId;
  final int? sucuId;

  factory InventarioRequestModel.fromJson(Map<String, dynamic> json) => InventarioRequestModel(
      invtCantidad: (json['invtCantidad'] as num?)?.toDouble(),
      invtFecha: json['invtFecha']?.toString(),
      prodId: (json['prodId'] as num?)?.toInt(),
      sucuId: (json['sucuId'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      if (invtCantidad != null) 'invtCantidad': invtCantidad,
      if (invtFecha != null) 'invtFecha': invtFecha,
      if (prodId != null) 'prodId': prodId,
      if (sucuId != null) 'sucuId': sucuId,
  };
}
