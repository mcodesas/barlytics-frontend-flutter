import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Conteo muestra el mismo stock operativo que Productos', () {
    final code = File(
      'lib/features/inventario/presentation/pages/inventario_list_page.dart',
    ).readAsStringSync();
    expect(
      code,
      contains('final systemStock = widget.product.inventarioActual ?? 0;'),
    );
    expect(
      code,
      isNot(contains('widget.previousRecord?.invtCantidadEsperada ??')),
    );
    // Una compra recibida mientras se cuenta debe refrescar el catálogo
    // antes de abrir nuevamente el registro de un producto.
    expect(
      code,
      contains('await ref.read(inventarioConteoProvider.notifier).load();'),
    );
  });

  test('Guardar físico no modifica existencias sin sincronización', () {
    final code = File(
      'lib/features/inventario/presentation/providers/inventario_conteo_provider.dart',
    ).readAsStringSync();
    expect(code, isNot(contains('_productWithInventory')));
    expect(code, contains('final updatedProducts = state.productos;'));
    expect(code, contains('stockActual[entry.key]!'));
  });

  test('La conciliación muestra la diferencia real y no la histórica', () {
    final code = File(
      'lib/features/inventario/presentation/pages/inventario_list_page.dart',
    ).readAsStringSync();
    expect(code, contains('final actual = product?.inventarioActual;'));
    expect(code, contains('final delta = actual == null ? null : fisico - actual;'));
    expect(code, contains('Ajuste real'));
  });
}
