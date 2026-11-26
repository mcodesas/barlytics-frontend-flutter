/// Coincidencia del producto efectivamente registrado en una jornada.
///
/// El filtro se aplica a cada fila del conteo (no solamente a la tarjeta de
/// la fecha), por lo que la vista muestra las cantidades del producto buscado.
bool matchesCountHistoryRow({
  required int productId,
  required int countId,
  required String productName,
  int? selectedProductId,
  String query = '',
}) {
  if (selectedProductId != null && selectedProductId != productId) {
    return false;
  }
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return true;
  return productName.toLowerCase().contains(normalized) ||
      '$countId'.contains(normalized);
}

/// La fecha elegida corresponde al día civil de la jornada y no depende de
/// la hora en que se registraron los productos.
bool matchesCountHistoryDay({
  required DateTime date,
  String? selectedDay,
}) {
  if (selectedDay == null) return true;
  final key = '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
  return key == selectedDay;
}

enum CountHistoryPeriod { day, fortnight, month, custom }

/// Límites civiles inclusivos; la quincena es 1–15 o 16–fin de mes.
/// No consulta jornadas posteriores a hoy.
({DateTime start, DateTime end}) countHistoryCalendarRange({
  required CountHistoryPeriod period,
  required DateTime selected,
  required DateTime today,
}) {
  final day = DateTime(selected.year, selected.month, selected.day);
  final limit = DateTime(today.year, today.month, today.day);
  if (day.isAfter(limit) || period == CountHistoryPeriod.custom) {
    throw ArgumentError('Selecciona un día válido o un rango personalizado.');
  }
  final start = switch (period) {
    CountHistoryPeriod.day => day,
    CountHistoryPeriod.fortnight =>
      DateTime(day.year, day.month, day.day <= 15 ? 1 : 16),
    CountHistoryPeriod.month => DateTime(day.year, day.month),
    CountHistoryPeriod.custom => throw StateError('Rango personalizado'),
  };
  final end = switch (period) {
    CountHistoryPeriod.day => day,
    CountHistoryPeriod.fortnight => day.day <= 15
        ? DateTime(day.year, day.month, 15)
        : DateTime(day.year, day.month + 1, 0),
    CountHistoryPeriod.month => DateTime(day.year, day.month + 1, 0),
    CountHistoryPeriod.custom => throw StateError('Rango personalizado'),
  };
  return (start: start, end: end.isAfter(limit) ? limit : end);
}

String countHistoryPeriodLabel(CountHistoryPeriod period) => switch (period) {
  CountHistoryPeriod.day => 'Día',
  CountHistoryPeriod.fortnight => 'Quincena',
  CountHistoryPeriod.month => 'Mes',
  CountHistoryPeriod.custom => 'Personalizado',
};
