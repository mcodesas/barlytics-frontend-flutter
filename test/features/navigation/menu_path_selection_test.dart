import 'package:barlytics_frontend/features/navigation/domain/menu_path_selection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('selección de opciones del menú', () {
    test('Listar productos gana sobre la ruta padre Vender / Mesas', () {
      expect(
        mostSpecificMenuPath('/mesero/productos', [
          '/home',
          '/mesero',
          '/mesero/productos',
          '/historial_ventas',
          '/cierre_caja',
        ]),
        '/mesero/productos',
      );
    });

    test('Mesas sigue seleccionado al volver a su ruta', () {
      expect(
        mostSpecificMenuPath('/mesero', ['/home', '/mesero', '/mesero/productos']),
        '/mesero',
      );
    });

    test('Cierre de caja usa el alias que retorna el menú de base de datos', () {
      expect(
        mostSpecificMenuPath('/mesero/cierre-caja', ['/mesero', '/cierre_caja']),
        '/cierre_caja',
      );
    });

    test('Historial usa el alias que retorna el menú de base de datos', () {
      expect(
        mostSpecificMenuPath('/mesero/historial', ['/mesero', '/historial_ventas']),
        '/historial_ventas',
      );
    });

    test('En rutas hijas gana la opción más específica', () {
      expect(
        mostSpecificMenuPath('/mesero/productos/detalle', [
          '/mesero',
          '/mesero/productos',
        ]),
        '/mesero/productos',
      );
    });

    test('La ruta literal de administrar mesas gana al alias de Mesas', () {
      expect(
        mostSpecificMenuPath(
          '/administrar_mesas',
          ['/mesero', '/administrar_mesas'],
        ),
        '/administrar_mesas',
      );
      expect(
        mostSpecificMenuPath(
          '/mesero',
          ['/administrar_mesas', '/mesero'],
        ),
        '/mesero',
      );
    });

    test('Prioriza historial exacto frente a un alias equivalente', () {
      expect(
        mostSpecificMenuPath(
          '/historial_ventas',
          ['/mesero/historial', '/historial_ventas'],
        ),
        '/historial_ventas',
      );
    });

    test('Sin coincidencias no selecciona una opción equivocada', () {
      expect(
        mostSpecificMenuPath('/reporte', ['/home', '/mesero']),
        isNull,
      );
    });
  });
}
