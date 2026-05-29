/// Modelo de request para crear o actualizar registros del módulo Productos.
class ProductosRequestModel {
  const ProductosRequestModel({
    this.mrcaId,
    this.prodDescripcion,
    this.prodNombre,
    this.tpprId,
    this.prodId,
    this.sucuId,
    this.prodFoto,
  });

  final int? mrcaId;
  final String? prodDescripcion;
  final String? prodNombre;
  final int? tpprId;
  final int? prodId;
  final int? sucuId;
  final String? prodFoto;

  factory ProductosRequestModel.fromJson(Map<String, dynamic> json) => ProductosRequestModel(
      mrcaId: (json['mrcaId'] as num?)?.toInt(),
      prodDescripcion: json['prodDescripcion']?.toString(),
      prodNombre: json['prodNombre']?.toString(),
      tpprId: (json['tpprId'] as num?)?.toInt(),
      prodId: (json['prodId'] as num?)?.toInt(),
      sucuId: (json['sucuId'] as num?)?.toInt(),
      prodFoto: json['prodFoto']?.toString(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      if (mrcaId != null) 'mrcaId': mrcaId,
      if (prodDescripcion != null) 'prodDescripcion': prodDescripcion,
      if (prodNombre != null) 'prodNombre': prodNombre,
      if (tpprId != null) 'tpprId': tpprId,
      if (prodId != null) 'prodId': prodId,
      if (sucuId != null) 'sucuId': sucuId,
      if (prodFoto != null) 'prodFoto': prodFoto,
  };
}
