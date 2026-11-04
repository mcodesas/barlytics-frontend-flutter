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
}
