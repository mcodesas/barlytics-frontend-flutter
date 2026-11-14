import 'package:barlytics_frontend/features/menu_digital/domain/menu_digital_ordering.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> product(int id, String name, String type) => {
  'id': id,
  'nombre': name,
  'tipo': type,
};

void main() {
  test('Respeta orden manual de categorías y de productos', () {
    final items = [
      product(1, 'Cerveza A', 'Cervezas'),
      product(2, 'Ensalada', 'Comidas'),
      product(3, 'Cerveza B', 'Cervezas'),
      product(4, 'Limonada', 'Bebidas'),
    ];
    final arranged = MenuDigitalOrdering.arrange(items,
      productIds: [3, 1, 4, 2],
      categoryOrder: ['Bebidas', 'Cervezas', 'Comidas'],
    );
    expect(arranged.map(MenuDigitalOrdering.productId).toList(),
        [4, 3, 1, 2]);
  });

  test('Las nuevas categorías y productos siguen apareciendo sin perderse', () {
    final items = [
      product(10, 'Hamburguesa', 'Comidas'),
      product(11, 'Café', 'Bebidas'),
      product(12, 'Brownie', 'Postres'),
    ];
    final arranged = MenuDigitalOrdering.arrange(items,
      productIds: [11, 10],
      categoryOrder: ['Bebidas', 'Comidas'],
    );
    expect(MenuDigitalOrdering.categories(items, ['Bebidas', 'Comidas']),
        ['Bebidas', 'Comidas', 'Postres']);
    expect(arranged.map(MenuDigitalOrdering.productId).toList(),
        [11, 10, 12]);
  });

  test('Productos sin tipo se muestran en Especialidades', () {
    expect(MenuDigitalOrdering.category({'id': 1, 'tipo': null}),
        'Especialidades');
    expect(MenuDigitalOrdering.category({'id': 2, 'tipo': '  '}),
        'Especialidades');
  });
}
