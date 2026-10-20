import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/gastos_fijos/presentation/pages/gastos_fijos_page.dart';

void main() {
  test('una fecha puntual reemplaza al período y la recurrencia sin sumarlos', () {
    final tarifas = <Map<String, dynamic>>[
      {
        'gafdId': 1,
        'gafdDiaSemana': 2,
        'gafdModo': 'RECURRENTE',
        'gafdVigenciaDesde': '2026-01-01',
        'gafdValor': 30000,
      },
      {
        'gafdId': 2,
        'gafdDiaSemana': 2,
        'gafdModo': 'PERIODO',
        'gafdVigenciaDesde': '2026-10-19',
        'gafdVigenciaHasta': '2026-10-21',
        'gafdValor': 80000,
      },
      {
        'gafdId': 3,
        'gafdDiaSemana': 2,
        'gafdModo': 'DIA',
        'gafdVigenciaDesde': '2026-10-20',
        'gafdVigenciaHasta': '2026-10-20',
        'gafdValor': 90000,
      },
    ];

    expect(costoManoObraEnFecha(tarifas, DateTime(2026, 10, 20)), 90000);
    expect(costoManoObraEnFecha(tarifas, DateTime(2026, 10, 27)), 30000);
    expect(costoManoObraEnFecha(tarifas, DateTime(2026, 10, 19)), 0);
  });

  test('período inclusivo no se cobra fuera de los límites', () {
    final tarifas = <Map<String, dynamic>>[
      {
        'gafdId': 10,
        'gafdDiaSemana': 3,
        'gafdModo': 'PERIODO',
        'gafdVigenciaDesde': '2026-10-19',
        'gafdVigenciaHasta': '2026-10-21',
        'gafdValor': 80000,
      },
    ];
    expect(costoManoObraEnFecha(tarifas, DateTime(2026, 10, 21)), 80000);
    expect(costoManoObraEnFecha(tarifas, DateTime(2026, 10, 28)), 0);
  });
}
