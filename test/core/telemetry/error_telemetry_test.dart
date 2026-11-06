import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/core/telemetry/error_telemetry.dart';

void main() {
  group('Privacidad de telemetría', () {
    test('No registra tokens, correos ni números financieros', () {
      final result = ErrorTelemetry.sanitize(
        'Bearer fakeToken123 '
        'password=FAKE_TEST_SECRET '
        'test@example.com tarjeta 4242424242424242 '
        '192.168.1.99',
        500,
      );
      expect(result, isNot(contains('fakeToken123')));
      expect(result, isNot(contains('FAKE_TEST_SECRET')));
      expect(result, isNot(contains('test@example.com')));
      expect(result, isNot(contains('4242424242424242')));
      expect(result, isNot(contains('192.168.1.99')));
      expect(result, contains('[EMAIL]'));
    });

    test('Anonimiza ruta local de Windows y macOS', () {
      final windows = ErrorTelemetry.sanitize(
        r'C:\Users\PersonaPrueba\AppData\Local', 500);
      final unix = ErrorTelemetry.sanitize(
        '/Users/PersonaPrueba/Library/logs.txt', 500);
      expect(windows, isNot(contains('PersonaPrueba')));
      expect(unix, isNot(contains('PersonaPrueba')));
    });

    test('Respeta longitud y conserva estructura de la traza', () {
      final trace = ErrorTelemetry.sanitize(
        'RenderFlex overflowed\napp_scaffold.dart:2583\n'
        'framework.dart:1051',
        500,
      );
      expect(trace, contains('\n'));
      expect(trace, contains('app_scaffold.dart:2583'));
      expect(ErrorTelemetry.sanitize('a' * 1000, 120).length, 120);
    });
  });

  group('Identificación del módulo o endpoint', () {
    test('Preserva ruta técnica sin sus parámetros ni identificadores', () {
      expect(
        ErrorTelemetry.normalizeRoute(
          '/api/v1/inventario/administracion/excel?token=secreto',
        ),
        '/api/v1/inventario/administracion/excel',
      );
      expect(
        ErrorTelemetry.normalizeRoute('/api/v1/ventas/1515165/pagos'),
        '/api/v1/ventas/:id/pagos',
      );
      expect(
        ErrorTelemetry.normalizeRoute(
          '/api/v1/eventos/public/nombre-del-cliente/reservas',
        ),
        '/api/v1/eventos/public/:id/reservas',
      );
    });

    test('Elimina slugs e identificadores de páginas públicas', () {
      expect(ErrorTelemetry.normalizeRoute('/evento/reserva-personal'),
          '/evento');
      expect(ErrorTelemetry.normalizeRoute('/carta/empresa-cliente'),
          '/carta');
      expect(ErrorTelemetry.normalizeRoute('/inventario_admin'),
          '/inventario_admin');
      expect(ErrorTelemetry.normalizeRoute('/'), '/');
    });
  });
}
