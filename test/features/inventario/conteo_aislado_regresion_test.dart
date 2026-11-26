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

  test('Conteo no sincroniza y abre administración solo con menú autorizado', () {
    final code = File(
      'lib/features/inventario/presentation/pages/inventario_list_page.dart',
    ).readAsStringSync();
    expect(code, isNot(contains('sincronizarDiferencias(')));
    expect(code, isNot(contains('_openReconcileDialog')));
    expect(code, contains('ref.watch(userMenuProvider).maybeWhen('));
    expect(code, contains("item.path == '/inventario_admin'"));
    expect(code, contains('orElse: () => false'));
    expect(code, contains('if (canAdministerInventory)'));
    expect(code, contains("context.push('/inventario_admin')"));
    expect(code, contains('Administrar inventario'));
  });
}
