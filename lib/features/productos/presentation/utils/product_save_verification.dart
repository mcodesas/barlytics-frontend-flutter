import '../../data/models/productos_response_model.dart';

/// Comprueba que la lectura posterior al guardado coincide con los datos
/// principales enviados al backend. No reemplaza la confirmación de receta,
/// precio ni movimientos de inventario de sus endpoints independientes.
bool productSaveVerified(
  ProductosResponseModel actual, {
  required int expectedId,
  required Map<String, dynamic> request,
}) {
  int? id(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  double? number(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  bool sameNumber(Object? lhs, Object? rhs) {
    final a = number(lhs);
    final b = number(rhs);
    if (a == null || b == null) return a == b;
    return (a - b).abs() <= 0.001;
  }

  String text(Object? value) => value?.toString().trim() ?? '';

  if (actual.prodId != expectedId ||
      actual.sucuId != id(request['sucuId']) ||
      actual.tpprId != id(request['tpprId']) ||
      actual.mrcaId != id(request['mrcaId']) ||
      text(actual.prodNombre) != text(request['prodNombre']) ||
      text(actual.prodDescripcion) != text(request['prodDescripcion'])) {
    return false;
  }

  if ((actual.prodCompraPorCantidad ?? 0) !=
      (id(request['prodCompraPorCantidad']) ?? 0)) {
    return false;
  }
  if (!sameNumber(actual.prodStockMinimo, request['prodStockMinimo'])) {
    return false;
  }
  if (!sameNumber(actual.prodStockMaximo, request['prodStockMaximo'])) {
    return false;
  }
  if ((actual.prodCompraPorCantidad ?? 0) == 1) {
    if (!sameNumber(actual.prodCantidadCompra, request['prodCantidadCompra']) ||
        text(actual.prodPresentacionCompra) != text(request['prodPresentacionCompra'])) {
      return false;
    }
  }
  if (text(actual.prodTipoControl).toUpperCase() !=
          text(request['prodTipoControl']).toUpperCase() ||
      text(actual.prodUnidadBase).toUpperCase() !=
          text(request['prodUnidadBase']).toUpperCase()) {
    return false;
  }
  return true;
}
