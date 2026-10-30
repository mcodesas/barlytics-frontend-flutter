import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Mano de obra tiene un solo scroll vertical para cargos y tarifas', () {
    final src = File(
      'lib/features/gastos_fijos/presentation/pages/gastos_fijos_page.dart',
    ).readAsStringSync();
    expect(src, contains("Key('labor-dialog-mobile-scroll')"));
    expect(src, contains('_rolesPane(embedded: true)'));
    expect(src, contains('_configurationPane(mobile: true)'));
    expect(src, contains('NeverScrollableScrollPhysics()'));
    expect(src, contains('shrinkWrap: embedded'));
    expect(src, contains('media.viewInsets.bottom'));
  });

  test('Proveedor mantiene una lista de productos delimitada y scroll externo', () {
    final src = File(
      'lib/features/pedidos_compra/presentation/pages/pedidos_compra_page.dart',
    ).readAsStringSync();
    expect(src, contains("Key('proveedor-dialog-scroll')"));
    expect(src, contains('ScrollViewKeyboardDismissBehavior.onDrag'));
    expect(src, contains('height: math.min(260.0,'));
  });

  test('Selector de cuentas de pago puede desplazarse sin salirse del viewport', () {
    final src = File(
      'lib/features/mesero/presentation/pages/mesero_page.dart',
    ).readAsStringSync();
    expect(src, contains("Key('seleccion-cuenta-pago-scroll')"));
    expect(src, contains('maxHeight: MediaQuery.sizeOf(context).height * .78'));
  });

  test('Edición y reserva de eventos respetan los safe areas y el teclado', () {
    final src = File(
      'lib/features/eventos/presentation/eventos_admin_page.dart',
    ).readAsStringSync();
    expect(src, contains('_eventDialogAvailableHeight(dialog)'));
    expect(src, contains('_eventDialogAvailableHeight(context)'));
    expect(src, contains('media.viewInsets.bottom'));
  });
}
