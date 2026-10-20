import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/productos/data/models/productos_response_model.dart';
import 'package:barlytics_frontend/features/productos/presentation/pages/productos_list_page.dart';

void main() {
  const productos = [
    ProductosResponseModel(prodId: 1, sucuId: 10, prodNombre: 'Burger'),
    ProductosResponseModel(prodId: 2, sucuId: 20, prodNombre: 'Cerveza'),
    ProductosResponseModel(prodId: 3, sucuId: 10, prodNombre: 'Papas'),
  ];

  test('muestra únicamente productos de la sucursal activa', () {
    expect(productosDeSucursalActiva(productos, 10).map((p) => p.prodId),
        [1, 3]);
    expect(productosDeSucursalActiva(productos, 20).map((p) => p.prodId),
        [2]);
  });

  test('sin sucursal activa nunca expone productos de otras sucursales', () {
    expect(productosDeSucursalActiva(productos, null), isEmpty);
  });
}
