import 'package:barlytics_frontend/core/network/json_payload_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeJsonPayload', () {
    test('convierte double entero a int', () {
      expect(normalizeJsonPayload(1.0), 1);
      expect(normalizeJsonPayload(5000.0), 5000);
      expect(normalizeJsonPayload(-3.0), -3);
      expect(normalizeJsonPayload(-0.0), 0);
    });

    test('conserva valores realmente fraccionarios', () {
      expect(normalizeJsonPayload(1.5), 1.5);
      expect(normalizeJsonPayload(12.25), 12.25);
    });

    test('normaliza mapas y listas anidadas', () {
      final normalized = normalizeJsonPayload({
        'cantidad': 1.0,
        'pagos': [
          {'valor': 5000.0, 'valorRecibido': 10000.0},
          {'valor': 2500.5},
        ],
        'porcentaje': 19.25,
      });

      expect(
        normalized,
        {
          'cantidad': 1,
          'pagos': [
            {'valor': 5000, 'valorRecibido': 10000},
            {'valor': 2500.5},
          ],
          'porcentaje': 19.25,
        },
      );
    });

    test('normaliza query parameters', () {
      expect(
        normalizeJsonMap({'page': 1.0, 'factor': 1.25}),
        {'page': 1, 'factor': 1.25},
      );
    });
  });
}
