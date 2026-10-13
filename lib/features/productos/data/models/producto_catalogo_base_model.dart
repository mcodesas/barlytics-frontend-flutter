class ProductoCatalogoBaseModel {
  const ProductoCatalogoBaseModel({
    required this.catalogId,
    required this.codigo,
    required this.nombre,
    required this.descripcion,
    required this.tipoProducto,
    required this.marca,
    this.foto,
    required this.precioCompra,
    required this.precioVenta,
    required this.stockMinimo,
    this.stockMaximo,
    required this.compraPorCantidad,
    this.cantidadCompra,
    this.presentacionCompra,
    required this.tipoControl,
    required this.unidadBase,
    required this.aplicaImpuesto,
    this.porcentajeImpuesto,
    required this.alreadyInBranch,
    this.existingProductId,
  });

  final int catalogId;
  final String codigo;
  final String nombre;
  final String descripcion;
  final String tipoProducto;
  final String marca;
  final String? foto;
  final double precioCompra;
  final double precioVenta;
  final double stockMinimo;
  final double? stockMaximo;
  final int compraPorCantidad;
  final double? cantidadCompra;
  final String? presentacionCompra;
  final String tipoControl;
  final String unidadBase;
  final int aplicaImpuesto;
  final double? porcentajeImpuesto;
  final bool alreadyInBranch;
  final int? existingProductId;

  factory ProductoCatalogoBaseModel.fromJson(Map<String, dynamic> json) {
    return ProductoCatalogoBaseModel(
      catalogId: _int(json['catalogId']) ?? 0,
      codigo: json['codigo']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? 'Producto',
      descripcion: json['descripcion']?.toString() ?? '',
      tipoProducto: json['tipoProducto']?.toString() ?? 'Otro',
      marca: json['marca']?.toString() ?? 'Sin marca',
      foto: _text(json['foto']),
      precioCompra: _double(json['precioCompra']) ?? 0,
      precioVenta: _double(json['precioVenta']) ?? 0,
      stockMinimo: _double(json['stockMinimo']) ?? 0,
      stockMaximo: _double(json['stockMaximo']),
      compraPorCantidad: _int(json['compraPorCantidad']) ?? 0,
      cantidadCompra: _double(json['cantidadCompra']),
      presentacionCompra: _text(json['presentacionCompra']),
      tipoControl: json['tipoControl']?.toString() ?? 'NORMAL',
      unidadBase: json['unidadBase']?.toString() ?? 'UND',
      aplicaImpuesto: _int(json['aplicaImpuesto']) ?? 0,
      porcentajeImpuesto: _double(json['porcentajeImpuesto']),
      alreadyInBranch: json['alreadyInBranch'] == true,
      existingProductId: _int(json['existingProductId']),
    );
  }
}

int? _int(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double? _double(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

String? _text(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
