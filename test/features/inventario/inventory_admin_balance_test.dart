import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/inventario/utils/inventory_admin_balance.dart';

InventoryAdminBalance balance({
  required double historical,
  required double counted,
  required double stock,
  bool latest = true,
  bool available = true,
  String status = 'PENDIENTE',
  double cost = 2317,
}) => InventoryAdminBalance.resolve(
      historicalExpected: historical,
      counted: counted,
      currentStock: stock,
      hasCurrentStock: available,
      latestCount: latest,
      persistedStatus: status,
      unitCost: cost,
      persistedExpectedValue: historical * cost,
      persistedCountedValue: counted * cost,
      persistedMissingValue: (historical > counted ? historical - counted : 0.0) * cost,
      persistedSurplusValue: (counted > historical ? counted - historical : 0.0) * cost,
      persistedNetImpact: (counted - historical) * cost,
    );

void main() {
  test('Águila Light: 122 guardado no crea faltante cuando stock y físico son 92', () {
    final actual = balance(historical: 122, counted: 92, stock: 92);
    expect(actual.expected, 92);
    expect(actual.historicalExpected, 122);
    expect(actual.difference, 0);
    expect(actual.status, 'CUADRA');
    expect(actual.missingValue, 0);
    expect(actual.netImpact, 0);
    expect(actual.usesCurrentStock, isTrue);
  });

  test('Águila Original: no reporta faltante ficticio de 60', () {
    final actual = balance(historical: 130, counted: 70, stock: 70);
    expect(actual.difference, 0);
    expect(actual.missingValue, 0);
    expect(actual.status, 'CUADRA');
  });

  test('Cuenta únicamente diferencias reales del stock actual', () {
    final actual = balance(historical: 122, counted: 92, stock: 100);
    expect(actual.expected, 100);
    expect(actual.difference, -8);
    expect(actual.missingValue, 8 * 2317);
    expect(actual.netImpact, -8 * 2317);
    expect(actual.status, 'PENDIENTE');
  });

  test('Al entrar mercancía con el conteo abierto se usa el stock actualizado', () {
    final antes = balance(historical: 62, counted: 92, stock: 62);
    final despues = balance(historical: 62, counted: 92, stock: 92);
    expect(antes.difference, 30);
    expect(despues.difference, 0);
    expect(despues.historicalExpected, 62);
  });

  test('Conteos pasados y sincronizados conservan su auditoría original', () {
    for (final row in [
      balance(historical: 122, counted: 92, stock: 70, latest: false),
      balance(historical: 122, counted: 92, stock: 70, status: 'SINCRONIZADO'),
      balance(historical: 122, counted: 92, stock: 70, status: 'SUPERADO'),
    ]) {
      expect(row.expected, 122);
      expect(row.difference, -30);
      expect(row.usesCurrentStock, isFalse);
    }
  });

  test('Sin stock operativo disponible no se inventa una referencia cero', () {
    final actual = balance(historical: 122, counted: 92, stock: 0, available: false);
    expect(actual.expected, 122);
    expect(actual.status, 'PENDIENTE');
    expect(actual.usesCurrentStock, isFalse);
  });
}
