import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/mesero/data/models/mesero_models.dart';

void main() {
  test('Un cierre histórico muestra ventas posteriores sin alterar su total', () {
    final cierre = CierreCajaResumenModel.fromJson({
      'cierreCajaId': 44,
      'fecha': '2026-10-29',
      'cerrado': true,
      'ventasIncluidas': 2,
      'totalVendido': 50000,
      'totalEntregado': 50000,
      'diferencia': 0,
      'ventasPendientes': [
        {
          'ventaId': 93,
          'fecha': '2026-10-29T23:30:00',
          'tipoVenta': 'DIRECTA',
          'total': 8000,
          'propina': 0,
        },
      ],
      'totalVentasPendientes': 8000,
    });
    expect(cierre.cerrado, isTrue);
    expect(cierre.totalVendido, 50000);
    expect(cierre.ventasIncluidas, 2);
    expect(cierre.ventasPendientes, hasLength(1));
    expect(cierre.ventasPendientes.single.ventaId, 93);
    expect(cierre.totalVentasPendientes, 8000);
    expect(cierre.totalEntregado, 50000);
    expect(cierre.diferencia, 0);
  });

  test('El modelo conserva compatibilidad con el backend anterior', () {
    final cierre = CierreCajaResumenModel.fromJson({
      'cierreCajaId': 44, 'cerrado': true, 'totalVendido': 50000,
    });
    expect(cierre.ventasPendientes, isEmpty);
    expect(cierre.totalVentasPendientes, isNull);
  });
}
