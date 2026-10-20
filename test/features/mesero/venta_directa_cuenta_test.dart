import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/mesero/data/datasources/mesero_remote_datasource.dart';
import 'package:barlytics_frontend/features/mesero/data/models/mesero_models.dart';

void main() {
  test('venta directa abre panel únicamente con cuenta persistida', () {
    const venta = MeseroVentaModel(
      ventaId: 41,
      tipoVenta: 'DIRECTA',
      cuentas: [
        MeseroCuentaModel(cuentaId: 72, numero: 1),
      ],
    );
    expect(cuentaDirectaLista(venta), isTrue);
  });

  test('respuesta del backend sin cuentas requiere consultar la venta existente', () {
    const sinCuentas = MeseroVentaModel(ventaId: 41, cuentas: []);
    const sinIdCuenta = MeseroVentaModel(
      ventaId: 41,
      cuentas: [MeseroCuentaModel(numero: 1)],
    );
    expect(cuentaDirectaLista(sinCuentas), isFalse);
    expect(cuentaDirectaLista(sinIdCuenta), isFalse);
    expect(cuentaDirectaLista(const MeseroVentaModel(
      cuentas: [MeseroCuentaModel(cuentaId: 72)],
    )), isFalse);
  });
}
