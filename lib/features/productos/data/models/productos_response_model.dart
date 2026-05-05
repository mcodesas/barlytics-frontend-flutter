/// Modelo de respuesta del módulo Productos basado en la colección Postman.
class ProductosResponseModel {
  const ProductosResponseModel({
    this.prodId,
    this.sucuId,
    this.tpprId,
    this.mrcaId,
    this.prodNombre,
    this.prodDescripcion,
    this.prodCreadoPor,
    this.prodFechaCambio,
  });

  final int? prodId;
  final int? sucuId;
  final int? tpprId;
  final int? mrcaId;
  final String? prodNombre;
  final String? prodDescripcion;
  final String? prodCreadoPor;
  final String? prodFechaCambio;

  factory ProductosResponseModel.fromJson(Map<String, dynamic> json) => ProductosResponseModel(
      prodId: (json['prodId'] as num?)?.toInt(),
      sucuId: (json['sucuId'] as num?)?.toInt(),
      tpprId: (json['tpprId'] as num?)?.toInt(),
      mrcaId: (json['mrcaId'] as num?)?.toInt(),
      prodNombre: json['prodNombre']?.toString(),
      prodDescripcion: json['prodDescripcion']?.toString(),
      prodCreadoPor: json['prodCreadoPor']?.toString(),
      prodFechaCambio: json['prodFechaCambio']?.toString(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      'prodId': prodId,
      'sucuId': sucuId,
      'tpprId': tpprId,
      'mrcaId': mrcaId,
      'prodNombre': prodNombre,
      'prodDescripcion': prodDescripcion,
      'prodCreadoPor': prodCreadoPor,
      'prodFechaCambio': prodFechaCambio,
  };

  Object? get id => prodId;

  String label() {
    final values = <Object?>[prodId, sucuId, tpprId, mrcaId];
    return values.where((e) => e != null && e.toString().isNotEmpty).join(' · ');
  }
}
