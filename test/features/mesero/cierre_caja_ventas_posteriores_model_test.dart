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


  test('Conciliar actualiza el cierre sin cambiar efectivo contado', () {
    final antes = CierreCajaResumenModel.fromJson({
      'cierreCajaId': 44,
      'sucursalId': 10,
      'fecha': '2026-10-29',
      'cerrado': true,
      'totalVendido': 50000,
      'totalEntregado': 50000,
      'diferencia': 0,
      'ventasIncluidas': 2,
      'ventasPendientes': [
        {'ventaId': 93, 'total': 8000, 'fecha': '2026-10-29T23:30:00'},
      ],
      'totalVentasPendientes': 8000,
    });
    // Respuesta después de conciliar una venta posterior con el backend.
    final despues = CierreCajaResumenModel.fromJson({
      'cierreCajaId': 44,
      'sucursalId': 10,
      'fecha': '2026-10-29',
      'cerrado': true,
      'totalVendido': 58000,
      'totalEntregado': 50000,
      'diferencia': -8000,
      'ventasIncluidas': 3,
      'ventasPendientes': [],
      'totalVentasPendientes': 0,
    });
    expect(antes.totalVendido, 50000);
    expect(antes.ventasPendientes.single.ventaId, 93);
    expect(despues.ventasPendientes, isEmpty);
    expect(despues.ventasIncluidas, 3);
    expect(despues.totalVendido, 58000);
    expect(despues.totalEntregado, antes.totalEntregado);
    expect(despues.diferencia, -8000);
  });

  test('La venta posterior nunca aparece en las incluidas sin conciliar', () {
    final cierre = CierreCajaResumenModel.fromJson({
      'cierreCajaId': 11,
      'sucursalId': 7,
      'fecha': '2026-11-02',
      'cerrado': true,
      'totalVendido': 15000,
      'ventas': [
        {'ventaId': 8, 'total': 15000},
      ],
      'ventasPendientes': [
        {'ventaId': 9, 'total': 12000},
      ],
      'totalVentasPendientes': 12000,
    });
    expect(cierre.ventas.map((venta) => venta.ventaId), contains(8));
    expect(cierre.ventas.map((venta) => venta.ventaId), isNot(contains(9)));
    expect(cierre.ventasPendientes.map((venta) => venta.ventaId), contains(9));
    expect(cierre.totalVendido, 15000);
  });

}
