import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/mesero/data/models/mesero_models.dart';
import 'package:barlytics_frontend/features/mesero/presentation/utils/historial_medios_pago.dart';

void main() {
  test('Suma pagos divididos por tipo sin duplicar venta ni cambio', () {
    final venta = MeseroVentaModel(
      ventaId: 110,
      total: 55000,
      totalPagado: 55000,
      cuentas: const [
        MeseroCuentaModel(
          cuentaId: 1,
          pagos: [
            MeseroPagoModel(
              pagoId: 1, medioPagoId: 2, medioPagoNombre: 'Nequi',
              valor: 20000,
            ),
            MeseroPagoModel(
              pagoId: 2, medioPagoId: 1, medioPagoNombre: 'Efectivo',
              valor: 15000, valorRecibido: 20000, cambio: 5000,
            ),
          ],
        ),
        MeseroCuentaModel(
          cuentaId: 2,
          pagos: [
            MeseroPagoModel(
              pagoId: 3, medioPagoId: 2, medioPagoNombre: 'Nequi',
              valor: 10000,
            ),
            MeseroPagoModel(
              pagoId: 4, medioPagoId: 3, medioPagoNombre: 'Tarjeta',
              valor: 10000,
            ),
          ],
        ),
      ],
    );

    final medios = resumirPagosVentas([venta]);
    expect(medios, hasLength(3));
    expect(medios.first.nombre, 'Nequi');
    expect(medios.first.total, 30000);
    expect(medios.first.cantidad, 2);
    expect(medios.firstWhere((m) => m.nombre == 'Efectivo').total, 15000);
    expect(medios.firstWhere((m) => m.nombre == 'Tarjeta').total, 10000);
    expect(totalPagosRegistrados(medios), 55000);
  });

  test('Suma ventas filtradas y no mezcla medios con IDs diferentes', () {
    const ventas = [
      MeseroVentaModel(cuentas: [
        MeseroCuentaModel(pagos: [
          MeseroPagoModel(medioPagoId: 10, medioPagoNombre: 'QR', valor: 8000),
        ]),
      ]),
      MeseroVentaModel(cuentas: [
        MeseroCuentaModel(pagos: [
          MeseroPagoModel(medioPagoId: 20, medioPagoNombre: 'QR', valor: 12000),
        ]),
      ]),
    ];
    final medios = resumirPagosVentas(ventas);
    expect(medios, hasLength(2));
    expect(totalPagosRegistrados(medios), 20000);
  });

  test('Usa nombre de respaldo si el backend no trae el medio', () {
    const pagos = [
      MeseroPagoModel(medioPagoId: 5, valor: 5000),
      MeseroPagoModel(medioPagoNombre: 'DaviPlata', valor: 7000),
      MeseroPagoModel(medioPagoNombre: 'daviplata', valor: 3000),
      MeseroPagoModel(valor: 0),
    ];
    final medios = resumirPagosRegistrados(pagos);
    expect(medios, hasLength(2));
    expect(medios.first.nombre, 'DaviPlata');
    expect(medios.first.total, 10000);
    expect(medios.last.nombre, 'Medio 5');
    expect(medios.last.total, 5000);
  });

  test('No inventa pagos cuando la venta aparece pagada sin movimientos', () {
    const venta = MeseroVentaModel(
      pagada: true,
      total: 30000,
      totalPagado: 30000,
      cuentas: [MeseroCuentaModel(pagos: [])],
    );
    final medios = resumirPagosVentas([venta]);
    expect(medios, isEmpty);
    expect(totalPagosRegistrados(medios), 0);
  });

  test('La edición histórica de un medio se refleja en el resumen', () {
    const original = [
      MeseroPagoModel(medioPagoId: 1, medioPagoNombre: 'Efectivo', valor: 22000),
    ];
    const editado = [
      MeseroPagoModel(medioPagoId: 3, medioPagoNombre: 'Tarjeta', valor: 22000),
    ];
    expect(resumirPagosRegistrados(original).single.nombre, 'Efectivo');
    expect(resumirPagosRegistrados(editado).single.nombre, 'Tarjeta');
    expect(totalPagosRegistrados(resumirPagosRegistrados(editado)), 22000);
  });
}
