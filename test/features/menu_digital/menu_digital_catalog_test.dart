import 'package:barlytics_frontend/features/menu_digital/presentation/widgets/menu_digital_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> demo(String style) => {
  'titulo': 'Carta de la casa',
  'sucursal': 'Sede central',
  'descripcion': 'Selecciona tu favorito',
  'estilo': style,
  'primario': '#D6B979',
  'fondo': '#10251D',
  'texto': '#F7F4E9',
  'tarjeta': '#1C382D',
  'productos': [
    {
      'id': 1,
      'nombre': 'Café americano',
      'descripcion': 'Café artesanal',
      'tipo': 'Cafés',
      'precio': 5000,
    },
  ],
};

void main() {
  for (final style in ['TIENDA', 'LIBRO']) {
    testWidgets('Menú digital ' + style + ' conserva paleta y productos',
        (tester) async {
      tester.view.physicalSize = const Size(390, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SingleChildScrollView(
          child: MenuDigitalCatalog(menu: demo(style), preview: true),
        )),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Carta de la casa'), findsOneWidget);
      expect(find.text('Café americano'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
