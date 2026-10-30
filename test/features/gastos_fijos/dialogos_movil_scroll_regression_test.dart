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
  test('Vista previa QR de pagos nunca usa altura infinita en teléfono', () {
    final src = File(
      'lib/features/medios_pago/presentation/pages/medios_pago_list_page.dart',
    ).readAsStringSync();
    expect(src, contains("Key('medio-pago-qr-dialog-scroll')"));
    expect(src, contains('maxHeight: MediaQuery.sizeOf(context).height * .75'));
  });

  test('Todos los formularios AlertDialog auditados permiten scroll', () {
    const paths = [
      'lib/features/gastos_fijos/presentation/pages/gastos_fijos_page.dart',
      'lib/features/mesero/presentation/pages/mesero_page.dart',
      'lib/features/inventario/presentation/pages/inventario_admin_page.dart',
      'lib/features/inventario/presentation/pages/inventario_list_page.dart',
      'lib/features/pagos/presentation/pages/pagos_list_page.dart',
      'lib/features/pedidos_compra/presentation/pages/pedidos_compra_page.dart',
      'lib/features/productos/presentation/pages/productos_form_page.dart',
      'lib/features/productos/presentation/widgets/productos_setup_tools.dart',
      'lib/features/empresas/presentation/pages/empresas_form_page.dart',
      'lib/features/eventos/presentation/eventos_admin_page.dart',
      'lib/core/printing/network_ticket_dialog.dart',
    ];
    for (final path in paths) {
      final src = File(path).readAsStringSync();
      final matches = RegExp(r'\bAlertDialog\(').allMatches(src);
      expect(matches, isNotEmpty, reason: path);
      for (final match in matches) {
        final end = (match.start + 340).clamp(0, src.length);
        expect(
          src.substring(match.start, end),
          contains(RegExp(r'\bscrollable:\s*true')),
          reason: '$path: diálogo sin scroll, posición ${match.start}',
        );
      }
    }
  });

}
