from pathlib import Path

path = Path('lib/features/mesero/presentation/pages/mesero_page.dart')
text = path.read_text(encoding='utf-8')

old = """  Future<Map<int, double>> _cargarProductosMasPedidosHoy() async {
    final hoy = DateTime.now();
    List<MeseroVentaModel> ventas = _historialVentas;

    try {
      ventas = await _dataSource.historialVentas();
      _historialVentas = ventas;
    } catch (_) {
      // Si el historial no está disponible, se conserva el orden del catálogo
      // y al menos se contabiliza la venta activa que el usuario está operando.
    }

    final acumulado = <int, double>{};
    final ventaActivaId = _ventaActiva?.ventaId;

    for (final venta in ventas) {
      if (venta.ventaId == ventaActivaId) continue;
      if (!_ventaCorrespondeAlDia(venta, hoy)) continue;
      _acumularProductosVenta(acumulado, venta);
    }

    final ventaActiva = _ventaActiva;
    if (ventaActiva != null && _ventaCorrespondeAlDia(ventaActiva, hoy)) {
      _acumularProductosVenta(acumulado, ventaActiva);
    }

    return acumulado;
  }
"""

new = """  Future<Map<int, double>> _cargarProductosMasPedidosHoy() async {
    final hoy = DateTime.now();

    try {
      return await _dataSource.productosMasPedidosHoy(fecha: _fechaIso(hoy));
    } catch (_) {
      // Fallback operativo: si el agregado no está disponible, se conserva el
      // catálogo funcional y se contabiliza al menos la venta activa.
      final acumulado = <int, double>{};
      final ventaActiva = _ventaActiva;
      if (ventaActiva != null && _ventaCorrespondeAlDia(ventaActiva, hoy)) {
        _acumularProductosVenta(acumulado, ventaActiva);
      }
      return acumulado;
    }
  }
"""

if new in text:
    print('El ajuste ya estaba aplicado.')
elif old not in text:
    raise SystemExit('No se encontró el bloque esperado en mesero_page.dart')
else:
    path.write_text(text.replace(old, new, 1), encoding='utf-8')
    print('Ajuste aplicado correctamente.')
