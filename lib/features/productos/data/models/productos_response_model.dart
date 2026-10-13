/// Modelo de respuesta del módulo Productos basado en la colección Postman.
class ProductosResponseModel {
  const ProductosResponseModel({
    this.prodId,
    this.sucuId,
    this.tpprId,
    this.mrcaId,
    this.prodNombre,
    this.prodDescripcion,
    this.prodFoto,
    this.prodFechaVencimiento,
    this.prodCompraPorCantidad,
    this.prodCantidadCompra,
    this.prodPresentacionCompra,
    this.prodStockMinimo,
    this.prodStockMaximo,
    this.prodTipoControl,
    this.prodUnidadBase,
    this.inventarioActual,
    this.ventasAyer,
    this.precioVigenteId,
    this.precioVentaVigente,
    this.precioCompraVigente,
    this.precioAplicaImpuesto,
    this.precioPorcentajeImpuesto,
    this.prodCreadoPor,
    this.prodFechaCambio,
  });

  final int? prodId;
  final int? sucuId;
  final int? tpprId;
  final int? mrcaId;
  final String? prodNombre;
  final String? prodDescripcion;
  final String? prodFoto;
  final String? prodFechaVencimiento;
  final int? prodCompraPorCantidad;
  final double? prodCantidadCompra;
  final String? prodPresentacionCompra;
  final double? prodStockMinimo;
  final double? prodStockMaximo;
  final String? prodTipoControl;
  final String? prodUnidadBase;
  final double? inventarioActual;
  final double? ventasAyer;
  final int? precioVigenteId;
  final double? precioVentaVigente;
  final double? precioCompraVigente;
  final int? precioAplicaImpuesto;
  final double? precioPorcentajeImpuesto;
  final String? prodCreadoPor;
  final String? prodFechaCambio;

  factory ProductosResponseModel.fromJson(Map<String, dynamic> json) => ProductosResponseModel(
        prodId: _toInt(json['prodId']),
        sucuId: _toInt(json['sucuId']),
        tpprId: _toInt(json['tpprId']),
        mrcaId: _toInt(json['mrcaId']),
        prodNombre: json['prodNombre']?.toString(),
        prodDescripcion: json['prodDescripcion']?.toString(),
        prodFoto: _normalizeImageValue(json['prodFoto']),
        prodFechaVencimiento: json['prodFechaVencimiento']?.toString(),
        prodCompraPorCantidad: _toInt(json['prodCompraPorCantidad']),
        prodCantidadCompra: _toDouble(json['prodCantidadCompra']),
        prodPresentacionCompra: json['prodPresentacionCompra']?.toString(),
        prodStockMinimo: _toDouble(json['prodStockMinimo']),
        prodStockMaximo: _toDouble(json['prodStockMaximo']),
        prodTipoControl: json['prodTipoControl']?.toString(),
        prodUnidadBase: json['prodUnidadBase']?.toString(),
        inventarioActual: _toDouble(json['inventarioActual']),
        ventasAyer: _toDouble(json['ventasAyer']),
        precioVigenteId: _toInt(json['precioVigenteId']),
        precioVentaVigente: _toDouble(json['precioVentaVigente']),
        precioCompraVigente: _toDouble(json['precioCompraVigente']),
        precioAplicaImpuesto: _toInt(json['precioAplicaImpuesto']),
        precioPorcentajeImpuesto: _toDouble(json['precioPorcentajeImpuesto']),
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
        'prodFoto': prodFoto,
        'prodFechaVencimiento': prodFechaVencimiento,
        'prodCompraPorCantidad': prodCompraPorCantidad,
        'prodCantidadCompra': prodCantidadCompra,
        'prodPresentacionCompra': prodPresentacionCompra,
        'prodStockMinimo': prodStockMinimo,
        'prodStockMaximo': prodStockMaximo,
        'prodTipoControl': prodTipoControl,
        'prodUnidadBase': prodUnidadBase,
        'inventarioActual': inventarioActual,
        'ventasAyer': ventasAyer,
        'precioVigenteId': precioVigenteId,
        'precioVentaVigente': precioVentaVigente,
        'precioCompraVigente': precioCompraVigente,
        'precioAplicaImpuesto': precioAplicaImpuesto,
        'precioPorcentajeImpuesto': precioPorcentajeImpuesto,
        'prodCreadoPor': prodCreadoPor,
        'prodFechaCambio': prodFechaCambio,
      };

  Object? get id => prodId;

  String label() {
    final values = <Object?>[prodNombre, prodDescripcion];
    return values.where((e) => e != null && e.toString().isNotEmpty).join(' · ');
  }
}

class ProductosPageResponseModel {
  const ProductosPageResponseModel({
    this.content = const [],
    this.page = 0,
    this.size = 20,
    this.totalElements = 0,
    this.totalPages = 0,
    this.first = true,
    this.last = true,
    this.empty = true,
  });

  final List<ProductosResponseModel> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool first;
  final bool last;
  final bool empty;

  factory ProductosPageResponseModel.fromJson(Map<String, dynamic> json) => ProductosPageResponseModel(
        content: (json['content'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => ProductosResponseModel.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        page: _toInt(json['page']) ?? 0,
        size: _toInt(json['size']) ?? 20,
        totalElements: _toInt(json['totalElements']) ?? 0,
        totalPages: _toInt(json['totalPages']) ?? 0,
        first: json['first'] == true,
        last: json['last'] == true,
        empty: json['empty'] == true,
      );
}

int? _toInt(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double? _toDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

String? _normalizeImageValue(Object? value) {
  if (value == null) return null;
  if (value is List) {
    // Fallback defensivo por si algún endpoint antiguo retorna byte[] como arreglo JSON.
    return null;
  }
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}
