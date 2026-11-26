import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guardas estructurales complementarias a las pruebas unitarias del saldo.
/// La validación interactiva se ejecuta aparte con el widget en navegador.
void main() {
  final source = File(
    'lib/features/inventario/presentation/pages/inventario_admin_page.dart',
  ).readAsStringSync();

  test('Los cinco indicadores solo usan la última jornada y muestran fecha', () {
    expect(source, contains('final ultimoConteo = allDays.isEmpty ? null : allDays.first;'));
    expect(source, contains('lastCountDate: ultimoConteo?.date'));
    expect(source, contains('final missing = ultimoConteo?.missingValue ?? 0.0;'));
    expect(source, contains('final surplus = ultimoConteo?.surplusValue ?? 0.0;'));
    expect(source, contains('final accuracy = ultimoConteo?.accuracy ?? 0.0;'));
    expect(source, contains('final pending = ultimoConteo?.pendingCount ?? 0;'));
    expect(source, contains('Último conteo:'));
  });

  test('Todas las jornadas son clicables y abren panel informativo', () {
    expect(source, contains('_DayValueBar('));
    expect(source, contains('onTap: () => onDayTap(day)'));
    expect(source, contains('class _DayDifferenceDetails extends StatefulWidget'));
    expect(source, contains('_DayDifferenceFilter.faltantes'));
    expect(source, contains('_DayDifferenceFilter.sobrantes'));
    expect(source, contains('_DayDifferenceFilter.cuadrados'));
    expect(source, contains('Contado por:'));
    expect(source, contains('Esperado guardado al contar'));
    expect(source, contains('Stock actual de Productos'));
  });

  test('Prioridades no incluyen históricos acumulados', () {
    expect(source, contains('Hallazgos prioritarios · último conteo'));
    expect(source, contains('final ultimo = days.isEmpty ? null : days.first;'));
    expect(source, contains('row.status == \'PENDIENTE\' || row.status == \'ANULADO\''));
    expect(source, contains('onProductTap(ultimo!, row.productId)'));
  });

  test('No se accede a Riverpod después de desmontar la ruta', () {
    expect(source, contains('if (mounted) _load();'));
    expect(source, contains('if (!mounted) return;'));
    expect(source, contains('final palette = ref.read(selectedAppPaletteProvider);'));
    expect(source, isNot(contains('palette: ref.read(selectedAppPaletteProvider)')));
  });
}
