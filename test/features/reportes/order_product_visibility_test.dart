import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/reportes/presentation/utils/order_product_visibility.dart';

void main() {
  const products = <Map<String, dynamic>>[
    {'producto_id': 1, 'producto': 'Agua', 'catalogo_activo': true},
    {'producto_id': 2, 'producto': 'Cerveza eliminada', 'catalogo_activo': false},
    {'producto_id': 3, 'producto': 'Refresco inactivo', 'catalogo_activo': 0},
    {'producto_id': 4, 'producto': 'Limonada', 'catalogo_activo': 1},
    {'producto_id': 5, 'producto': 'Producto antiguo sin bandera'},
    {'producto_id': 6, 'producto': 'Producto inactivo texto', 'catalogo_activo': 'false'},
  ];

  test('pedido manual no incluye productos eliminados o inactivos', () {
    final active = activePurchaseCatalog(products);
    expect(active.map((row) => row['producto_id']), [1, 4, 5]);
    expect(active.any((row) => row['producto'] == 'Cerveza eliminada'), isFalse);
    expect(active.any((row) => row['producto'] == 'Refresco inactivo'), isFalse);
  });

  test('se conserva el reporte original para las ventas históricas', () {
    final active = activePurchaseCatalog(products);
    expect(active.length, 3);
    expect(products.length, 6);
    expect(products[1]['producto'], 'Cerveza eliminada');
  });

  test('formatos booleanos comunes no reactivan productos', () {
    expect(isPurchasableOrderProduct({'catalogo_activo': 'FALSE'}), isFalse);
    expect(isPurchasableOrderProduct({'catalogo_activo': '0'}), isFalse);
    expect(isPurchasableOrderProduct({'catalogo_activo': false}), isFalse);
    expect(isPurchasableOrderProduct({'catalogo_activo': 'TRUE'}), isTrue);
  });
}
