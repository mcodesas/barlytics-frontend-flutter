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
    this.prodFechaVencimiento,
    this.prodCompraPorCantidad,
    this.prodCantidadCompra,
    this.prodPresentacionCompra,
    this.prodStockMinimo,
    this.prodStockMaximo,
    this.prodTipoControl,
    this.prodUnidadBase,
  });

  final int? mrcaId;
  final String? prodDescripcion;
  final String? prodNombre;
  final int? tpprId;
  final int? prodId;
  final int? sucuId;
  final String? prodFoto;
  final String? prodFechaVencimiento;
  final int? prodCompraPorCantidad;
  final double? prodCantidadCompra;
  final String? prodPresentacionCompra;
  final double? prodStockMinimo;
  final double? prodStockMaximo;
  final String? prodTipoControl;
  final String? prodUnidadBase;

  factory ProductosRequestModel.fromJson(Map<String, dynamic> json) => ProductosRequestModel(
        mrcaId: (json['mrcaId'] as num?)?.toInt(),
        prodDescripcion: json['prodDescripcion']?.toString(),
        prodNombre: json['prodNombre']?.toString(),
        tpprId: (json['tpprId'] as num?)?.toInt(),
        prodId: (json['prodId'] as num?)?.toInt(),
        sucuId: (json['sucuId'] as num?)?.toInt(),
        prodFoto: json['prodFoto']?.toString(),
        prodFechaVencimiento: json['prodFechaVencimiento']?.toString(),
        prodCompraPorCantidad: (json['prodCompraPorCantidad'] as num?)?.toInt(),
        prodCantidadCompra: (json['prodCantidadCompra'] as num?)?.toDouble(),
        prodPresentacionCompra: json['prodPresentacionCompra']?.toString(),
        prodStockMinimo: (json['prodStockMinimo'] as num?)?.toDouble(),
        prodStockMaximo: (json['prodStockMaximo'] as num?)?.toDouble(),
        prodTipoControl: json['prodTipoControl']?.toString(),
        prodUnidadBase: json['prodUnidadBase']?.toString(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (mrcaId != null) 'mrcaId': mrcaId,
        if (prodDescripcion != null) 'prodDescripcion': prodDescripcion,
        if (prodNombre != null) 'prodNombre': prodNombre,
        if (tpprId != null) 'tpprId': tpprId,
        if (prodId != null) 'prodId': prodId,
        if (sucuId != null) 'sucuId': sucuId,
        if (prodFoto != null) 'prodFoto': prodFoto,
        if (prodFechaVencimiento != null) 'prodFechaVencimiento': prodFechaVencimiento,
        if (prodCompraPorCantidad != null) 'prodCompraPorCantidad': prodCompraPorCantidad,
        if (prodCantidadCompra != null) 'prodCantidadCompra': prodCantidadCompra,
        if (prodPresentacionCompra != null) 'prodPresentacionCompra': prodPresentacionCompra,
        if (prodStockMinimo != null) 'prodStockMinimo': prodStockMinimo,
        'prodStockMaximo': prodStockMaximo,
        if (prodTipoControl != null) 'prodTipoControl': prodTipoControl,
        if (prodUnidadBase != null) 'prodUnidadBase': prodUnidadBase,
      };
}
