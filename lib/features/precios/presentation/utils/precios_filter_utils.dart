import '../../../productos/data/models/productos_response_model.dart';

/// Filtra exclusivamente borradores del contexto seleccionado. Los precios
/// guardados se filtran desde el backend mediante /productos/page.
List<ProductosResponseModel> filtrarPreciosPendientes({
  required Iterable<ProductosResponseModel> productos,
  required int? sucursalId,
  int? tipoId,
  int? marcaId,
  String busqueda = '',
}) {
  if (sucursalId == null) return const <ProductosResponseModel>[];
  final texto = busqueda.trim().toLowerCase();
  final filtrados = productos.where((producto) {
    if (producto.sucuId != sucursalId) return false;
    if (tipoId != null && producto.tpprId != tipoId) return false;
    if (marcaId != null && producto.mrcaId != marcaId) return false;
    if (texto.isEmpty) return true;
    return <String>[
      producto.prodNombre ?? '',
      producto.prodDescripcion ?? '',
      producto.prodId?.toString() ?? '',
    ].join(' ').toLowerCase().contains(texto);
  }).toList();
  filtrados.sort((a, b) => (a.prodNombre ?? '')
      .toLowerCase()
      .compareTo((b.prodNombre ?? '').toLowerCase()));
  return filtrados;
}
