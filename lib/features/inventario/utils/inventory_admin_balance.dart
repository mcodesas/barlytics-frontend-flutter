/// Separación entre la referencia histórica del conteo y el stock
/// operativo vigente. Sólo el último conteo AÚN SIN SINCRONIZAR puede
/// mostrar diferencias accionables contra el saldo actual de Productos.
/// Los conteos sincronizados y superados permanecen como historia.
class InventoryAdminBalance {
  const InventoryAdminBalance({
    required this.expected,
    required this.historicalExpected,
    required this.counted,
    required this.difference,
    required this.status,
    required this.usesCurrentStock,
    required this.expectedValue,
    required this.countedValue,
    required this.missingValue,
    required this.surplusValue,
    required this.netImpact,
  });

  final double expected;
  final double historicalExpected;
  final double counted;
  final double difference;
  final String status;
  final bool usesCurrentStock;
  final double expectedValue;
  final double countedValue;
  final double missingValue;
  final double surplusValue;
  final double netImpact;

  factory InventoryAdminBalance.resolve({
    required double historicalExpected,
    required double counted,
    required double currentStock,
    required bool hasCurrentStock,
    required bool latestCount,
    required String persistedStatus,
    required double unitCost,
    required double persistedExpectedValue,
    required double persistedCountedValue,
    required double persistedMissingValue,
    required double persistedSurplusValue,
    required double persistedNetImpact,
  }) {
    // No reescribir la fotografía histórica: si ya fue sincronizada,
    // una venta posterior no debe mostrar un faltante ficticio del pasado.
    final live = latestCount &&
        hasCurrentStock &&
        (persistedStatus == 'PENDIENTE' || persistedStatus == 'CUADRA');
    final expected = live ? currentStock : historicalExpected;
    final difference = counted - expected;
    final status = live
        ? (difference.abs() <= 0.0001 ? 'CUADRA' : 'PENDIENTE')
        : persistedStatus;

    if (!live) {
      return InventoryAdminBalance(
        expected: expected,
        historicalExpected: historicalExpected,
        counted: counted,
        difference: difference,
        status: status,
        usesCurrentStock: false,
        expectedValue: persistedExpectedValue,
        countedValue: persistedCountedValue,
        missingValue: persistedMissingValue,
        surplusValue: persistedSurplusValue,
        netImpact: persistedNetImpact,
      );
    }

    final expectedValue = expected * unitCost;
    final countedValue = counted * unitCost;
    final missingValue = (expected - counted > 0 ? expected - counted : 0) * unitCost;
    final surplusValue = (difference > 0 ? difference : 0) * unitCost;
    return InventoryAdminBalance(
      expected: expected,
      historicalExpected: historicalExpected,
      counted: counted,
      difference: difference,
      status: status,
      usesCurrentStock: true,
      expectedValue: expectedValue,
      countedValue: countedValue,
      missingValue: missingValue,
      surplusValue: surplusValue,
      netImpact: countedValue - expectedValue,
    );
  }
}
