import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Evita que futuros cambios reintroduzcan AlertDialog sin scroll en móvil.
void main() {
  const views = <String>[
    'lib/core/widgets/confirmation_dialog.dart',
    'lib/core/printing/network_ticket_dialog.dart',
    'lib/core/widgets/lookup_dropdown.dart',
    'lib/core/update/app_update_gate.dart',
    'lib/core/widgets/app_scaffold.dart',
    'lib/core/widgets/ready_order_notification_host.dart',
    'lib/features/auth/presentation/pages/reset_password_page.dart',
    'lib/features/auth/presentation/pages/forgot_password_page.dart',
    'lib/features/eventos/presentation/eventos_admin_page.dart',
    'lib/features/eventos/presentation/evento_publico_page.dart',
    'lib/features/eventos/presentation/widgets/event_access_control_dialog.dart',
    'lib/features/gastos_fijos/presentation/pages/gastos_fijos_page.dart',
    'lib/features/mesero/presentation/pages/mesero_page.dart',
    'lib/features/reportes/presentation/pages/reportes_page.dart',
    'lib/features/pedidos_compra/presentation/pages/pedidos_compra_page.dart',
    'lib/features/productos/presentation/pages/productos_form_page.dart',
    'lib/features/productos/presentation/widgets/productos_setup_tools.dart',
    'lib/features/inventario/presentation/pages/inventario_admin_page.dart',
    'lib/features/inventario/presentation/pages/inventario_list_page.dart',
    'lib/features/movimientos/presentation/pages/movimientos_list_page.dart',
    'lib/features/pagos/presentation/pages/pagos_list_page.dart',
    'lib/features/mesas/presentation/pages/mesas_list_page.dart',
    'lib/features/precios/presentation/pages/precios_list_page.dart',
    'lib/features/empresas/presentation/pages/empresas_form_page.dart',
    'lib/features/empresas/presentation/pages/empresas_list_page.dart',
    'lib/features/sucursales/presentation/widgets/confirm_permanent_branch_delete.dart',
    'lib/features/tipos_producto/presentation/pages/tipos_producto_list_page.dart',
    'lib/features/admin_support/presentation/pages/master_catalog_page.dart',
    'lib/features/admin_support/presentation/pages/product_catalog_sync_page.dart',
    'lib/features/subscription/presentation/pages/subscription_plans_admin_page.dart',
    'lib/features/roles_personalizados/presentation/pages/roles_personalizados_page.dart',
  ];

  for (final path in views) {
    test('Diálogos con scroll: $path', () {
      final source=File(path).readAsStringSync();
      final matches=RegExp(r'\bAlertDialog\s*\(').allMatches(source).toList();
      expect(matches,isNotEmpty,reason:'No se encontraron AlertDialog en $path');
      for (final match in matches) {
        final end=(match.end+130).clamp(0,source.length).toInt();
        final parameters=source.substring(match.end,end);
        expect(RegExp(r'^\s*scrollable\s*:\s*true\s*,').hasMatch(parameters),
          isTrue,reason:'Falta scrollable: true cerca de '
          'la línea ${source.substring(0,match.start).split('\n').length} de $path');
      }
    });
  }

  test('Diálogos personalizados incluyen desplazamiento',(){
    for(final path in [
      'lib/features/profile/presentation/pages/profile_page.dart',
      'lib/features/marcas/presentation/pages/marcas_list_page.dart',
      'lib/features/medios_pago/presentation/pages/medios_pago_list_page.dart',
    ]){
      final content=File(path).readAsStringSync();
      expect(content,contains('child: SingleChildScrollView('),reason:path);
    }
  });
}
