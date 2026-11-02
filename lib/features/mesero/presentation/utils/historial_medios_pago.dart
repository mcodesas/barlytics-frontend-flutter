import '../../data/models/mesero_models.dart';

/// Importe efectivamente registrado por medio en el historial.
/// No interpreta ventas sin pagos como si se hubiesen cobrado.
class HistorialMedioPagoResumen {
  const HistorialMedioPagoResumen({
    required this.medioPagoId,
    required this.nombre,
    required this.total,
    required this.cantidad,
  });

  final int? medioPagoId;
  final String nombre;
  final double total;
  final int cantidad;
}

/// Suma pagos reales, no el total de la venta ni el valor recibido en efectivo.
/// El cambio es solo informativo y no debe sumarse como ingreso.
List<HistorialMedioPagoResumen> resumirPagosRegistrados(
  Iterable<MeseroPagoModel> pagos,
) {
  final agrupados = <String, HistorialMedioPagoResumen>{};

  for (final pago in pagos) {
    final valor = pago.valor;
    if (valor == null || !valor.isFinite || valor == 0) continue;

    final nombreInformado = (pago.medioPagoNombre ?? '').trim();
    final nombre = nombreInformado.isNotEmpty
        ? nombreInformado
        : pago.medioPagoId == null
            ? 'Medio sin identificar'
            : 'Medio ${pago.medioPagoId}';
    final clave = pago.medioPagoId != null
        ? 'id:${pago.medioPagoId}'
        : 'nombre:${nombre.toLowerCase()}';
    final anterior = agrupados[clave];
    agrupados[clave] = HistorialMedioPagoResumen(
      medioPagoId: pago.medioPagoId,
      nombre: nombreInformado.isNotEmpty ? nombre : (anterior?.nombre ?? nombre),
      total: (anterior?.total ?? 0) + valor,
      cantidad: (anterior?.cantidad ?? 0) + 1,
    );
  }

  final resultado = agrupados.values.toList(growable: true);
  resultado.sort((a, b) {
    final porValor = b.total.compareTo(a.total);
    if (porValor != 0) return porValor;
    return a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
  });
  return resultado;
}

List<HistorialMedioPagoResumen> resumirPagosVentas(
  Iterable<MeseroVentaModel> ventas,
) {
  return resumirPagosRegistrados(
    ventas.expand((venta) => venta.cuentas.expand((cuenta) => cuenta.pagos)),
  );
}

double totalPagosRegistrados(Iterable<HistorialMedioPagoResumen> medios) {
  return medios.fold<double>(0, (suma, medio) => suma + medio.total);
}
