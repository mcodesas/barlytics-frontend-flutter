import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/productos/data/models/productos_response_model.dart';
import 'package:barlytics_frontend/features/productos/presentation/utils/product_save_verification.dart';

void main() {
  const persisted = ProductosResponseModel(
    prodId: 35,
    sucuId: 8,
    tpprId: 4,
    mrcaId: 2,
    prodNombre: 'Agua mineral',
    prodDescripcion: 'Paquete de doce',
    prodCompraPorCantidad: 1,
    prodCantidadCompra: 12,
    prodPresentacionCompra: 'Paquete',
    prodStockMinimo: 2,
    prodStockMaximo: 100,
    prodTipoControl: 'NORMAL',
    prodUnidadBase: 'UND',
  );

  final request = <String, dynamic>{
    'sucuId': 8,
    'tpprId': 4,
    'mrcaId': 2,
    'prodNombre': 'Agua mineral',
    'prodDescripcion': 'Paquete de doce',
    'prodCompraPorCantidad': 1,
    'prodCantidadCompra': 12,
    'prodPresentacionCompra': 'Paquete',
    'prodStockMinimo': 2,
    'prodStockMaximo': 100,
    'prodTipoControl': 'NORMAL',
    'prodUnidadBase': 'UND',
  };

  test('confirma persistencia de un producto editado con su presentación', () {
    expect(productSaveVerified(persisted, expectedId: 35, request: request), isTrue);
  });

  test('un producto diferente o de otra sucursal no confirma guardado', () {
    expect(productSaveVerified(persisted, expectedId: 36, request: request), isFalse);
    expect(productSaveVerified(
      persisted, expectedId: 35, request: {...request, 'sucuId': 9},
    ), isFalse);
  });

  test('no se confirma un precio o cantidad de compra no guardada', () {
    expect(productSaveVerified(
      persisted, expectedId: 35,
      request: {...request, 'prodCantidadCompra': 24},
    ), isFalse);
    expect(productSaveVerified(
      persisted, expectedId: 35,
      request: {...request, 'prodStockMinimo': 5},
    ), isFalse);
  });

  test('nombre o descripción anterior no deben dar éxito falso', () {
    expect(productSaveVerified(
      persisted, expectedId: 35,
      request: {...request, 'prodDescripcion': 'Presentación modificada'},
    ), isFalse);
  });
}
