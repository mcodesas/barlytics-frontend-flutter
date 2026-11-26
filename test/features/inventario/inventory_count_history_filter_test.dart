import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/inventario/presentation/utils/inventory_count_history_filter.dart';

void main() {
  test('La selección de producto excluye otros productos del mismo día', () {
    expect(
      matchesCountHistoryRow(
        productId: 23,
        countId: 800,
        productName: 'Cerveza rubia',
        selectedProductId: 23,
      ),
      isTrue,
    );
    expect(
      matchesCountHistoryRow(
        productId: 24,
        countId: 801,
        productName: 'Cerveza negra',
        selectedProductId: 23,
      ),
      isFalse,
    );
  });

  test('Busca por nombre sin distinguir mayúsculas ni espacios', () {
    expect(
      matchesCountHistoryRow(
        productId: 23,
        countId: 800,
        productName: 'Cerveza Rubia',
        query: ' RUBIA ',
      ),
      isTrue,
    );
    expect(
      matchesCountHistoryRow(
        productId: 23,
        countId: 800,
        productName: 'Cerveza Rubia',
        query: 'Gaseosa',
      ),
      isFalse,
    );
  });

  test('Permite consultar un conteo por su identificador histórico', () {
    expect(
      matchesCountHistoryRow(
        productId: 23,
        countId: 88014,
        productName: 'Agua mineral',
        query: '88014',
      ),
      isTrue,
    );
  });

  test('Combina producto elegido y búsqueda en la misma jornada', () {
    expect(
      matchesCountHistoryRow(
        productId: 23,
        countId: 88014,
        productName: 'Agua mineral',
        selectedProductId: 23,
        query: 'agua',
      ),
      isTrue,
    );
    expect(
      matchesCountHistoryRow(
        productId: 23,
        countId: 88014,
        productName: 'Agua mineral',
        selectedProductId: 99,
        query: 'agua',
      ),
      isFalse,
    );
  });

  test('Fecha específica muestra solo esa jornada de conteo', () {
    expect(
      matchesCountHistoryDay(
        date: DateTime(2026, 11, 4, 23, 30),
        selectedDay: '2026-11-04',
      ),
      isTrue,
    );
    expect(
      matchesCountHistoryDay(
        date: DateTime(2026, 11, 3, 23, 30),
        selectedDay: '2026-11-04',
      ),
      isFalse,
    );
  });

  test('Sin fecha seleccionada incluye cualquier jornada', () {
    expect(
      matchesCountHistoryDay(date: DateTime(2025, 6, 9)),
      isTrue,
    );
  });

  test('Sin criterios conserva todos los productos de la jornada', () {
    expect(
      matchesCountHistoryRow(
        productId: 12,
        countId: 25,
        productName: 'Refresco',
      ),
      isTrue,
    );
  });
  group('Períodos del historial', () {
    final today = DateTime(2026, 11, 26);
    test('Día único incluye solo la fecha elegida', () {
      final dates = countHistoryCalendarRange(period: CountHistoryPeriod.day,
          selected: DateTime(2026, 11, 5, 23), today: today);
      expect(dates.start, DateTime(2026, 11, 5));
      expect(dates.end, dates.start);
    });
    test('Quincenas civiles y fin de mes bisiesto', () {
      final first = countHistoryCalendarRange(period: CountHistoryPeriod.fortnight,
          selected: DateTime(2024, 2, 15), today: today);
      expect(first.start, DateTime(2024, 2, 1));
      expect(first.end, DateTime(2024, 2, 15));
      final second = countHistoryCalendarRange(period: CountHistoryPeriod.fortnight,
          selected: DateTime(2024, 2, 16), today: today);
      expect(second.start, DateTime(2024, 2, 16));
      expect(second.end, DateTime(2024, 2, 29));
    });
    test('Mes completo anterior y mes actual limitado a hoy', () {
      final previous = countHistoryCalendarRange(period: CountHistoryPeriod.month,
          selected: DateTime(2025, 12, 31), today: today);
      expect(previous.start, DateTime(2025, 12, 1));
      expect(previous.end, DateTime(2025, 12, 31));
      final current = countHistoryCalendarRange(period: CountHistoryPeriod.month,
          selected: today, today: today);
      expect(current.start, DateTime(2026, 11, 1));
      expect(current.end, today);
      final currentHalf = countHistoryCalendarRange(period: CountHistoryPeriod.fortnight,
          selected: today, today: today);
      expect(currentHalf.start, DateTime(2026, 11, 16));
      expect(currentHalf.end, today);
    });
    test('No permite fechas futuras', () {
      expect(() => countHistoryCalendarRange(period: CountHistoryPeriod.day,
          selected: DateTime(2026, 11, 27), today: today),
          throwsArgumentError);
    });
  });

}
