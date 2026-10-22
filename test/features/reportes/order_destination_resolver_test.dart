import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/reportes/presentation/utils/order_destination_resolver.dart';

void main() {
  const destinations = <Map<String, dynamic>>[
    {
      'id': 10,
      'nombre': 'Proveedor A',
      'whatsapp': '573000000001',
      'productoIds': [1, 2, 3],
      'productoIdsPredeterminados': [2],
    },
    {
      'id': 20,
      'nombre': 'Proveedor B',
      'whatsapp': '573000000002',
      'productoIds': [3, 4],
      'productoIdsPredeterminados': [],
    },
  ];

  test('producto asociado sin predeterminado usa proveedor asignado', () {
    expect(OrderDestinationResolver.resolve(
      productId: 1, destinations: destinations,
    ), 10);
  });

  test('proveedor predeterminado tiene prioridad sobre varios asociados', () {
    expect(OrderDestinationResolver.resolve(
      productId: 2, destinations: destinations,
    ), 10);
  });

  test('producto con dos proveedores exige seleccion, no general', () {
    expect(OrderDestinationResolver.needsChoice(
      productId: 3, destinations: destinations,
    ), isTrue);
    expect(OrderDestinationResolver.resolve(
      productId: 3, destinations: destinations,
    ), isNull);
    expect(OrderDestinationResolver.resolve(
      productId: 3, destinations: destinations, selected: 20,
    ), 20);
  });

  test('producto sin proveedor no inventa un destino', () {
    expect(OrderDestinationResolver.associatedDestinations(
      99, destinations,
    ), isEmpty);
    expect(OrderDestinationResolver.resolve(
      productId: 99, destinations: destinations,
    ), isNull);
    expect(OrderDestinationResolver.needsChoice(
      productId: 99, destinations: destinations,
    ), isFalse);
  });

  test('no acepta proveedor inactivo que ya no figure en catalogo', () {
    expect(OrderDestinationResolver.resolve(
      productId: 1, destinations: destinations, selected: 999,
    ), 10);
  });

  test('si no hay proveedores no asigna WhatsApp de otra sucursal', () {
    expect(OrderDestinationResolver.resolve(
      productId: 1, destinations: const [],
    ), isNull);
  });
}
