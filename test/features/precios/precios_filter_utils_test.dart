import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/precios/presentation/utils/precios_filter_utils.dart';
import 'package:barlytics_frontend/features/productos/data/models/productos_response_model.dart';

void main() {
  const products = <ProductosResponseModel>[
    ProductosResponseModel(
      prodId: 1, sucuId: 10, tpprId: 3, mrcaId: 2,
      prodNombre: 'Cerveza Dorada', prodDescripcion: 'Lata'),
    ProductosResponseModel(
      prodId: 2, sucuId: 10, tpprId: 3, mrcaId: 4,
      prodNombre: 'Cerveza Roja', prodDescripcion: 'Botella'),
    ProductosResponseModel(
      prodId: 3, sucuId: 10, tpprId: 5, mrcaId: 2,
      prodNombre: 'Papas', prodDescripcion: 'Acompañamiento'),
    ProductosResponseModel(
      prodId: 4, sucuId: 11, tpprId: 3, mrcaId: 2,
      prodNombre: 'Cerveza ajena', prodDescripcion: 'Otra sucursal'),
    ProductosResponseModel(
      prodId: 5, sucuId: 10, tpprId: 3, mrcaId: null,
      prodNombre: 'Cerveza sin marca'),
  ];

  test('sin sucursal no expone precios editados', () {
    final result = filtrarPreciosPendientes(
      productos: products,
      sucursalId: null,
    );
    expect(result, isEmpty);
  });

  test('el filtro por tipo se aplica solo a la sucursal actual', () {
    final result = filtrarPreciosPendientes(
      productos: products, sucursalId: 10, tipoId: 3,
    );
    expect(result.map((p) => p.prodId), [1, 5, 2]);
  });

  test('tipo y marca se intersectan sin perder el contexto de sucursal', () {
    final result = filtrarPreciosPendientes(
      productos: products, sucursalId: 10, tipoId: 3, marcaId: 2,
    );
    expect(result.map((p) => p.prodId), [1]);
  });

  test('buscar por nombre o código combina con tipo y marca', () {
    final result = filtrarPreciosPendientes(
      productos: products, sucursalId: 10, tipoId: 3,
      marcaId: 4, busqueda: 'ROJA',
    );
    expect(result.map((p) => p.prodId), [2]);

    final codeSearch = filtrarPreciosPendientes(
      productos: products, sucursalId: 10, busqueda: '3',
    );
    expect(codeSearch.map((p) => p.prodId), [3]);
  });

  test('sin filtros permite consultar los borradores de la sucursal', () {
    final result = filtrarPreciosPendientes(
      productos: products, sucursalId: 10,
    );
    expect(result.length, 4);
    expect(result.every((p) => p.sucuId == 10), isTrue);
  });
}
