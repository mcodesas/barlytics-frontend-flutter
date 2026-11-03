import 'package:barlytics_frontend/features/menu_digital/presentation/widgets/menu_digital_catalog.dart';
import 'package:barlytics_frontend/features/menu_digital/presentation/widgets/menu_digital_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Las 32 paletas tienen colores HEX válidos y contraste legible', () {
    expect(menuDigitalPalettePresets.length, greaterThanOrEqualTo(32));
    expect(menuDigitalPalettePresets.map((p) => p.name).toSet().length,
        menuDigitalPalettePresets.length);
    final pattern = RegExp(r'^#[0-9A-Fa-f]{6}$');
    for (final preset in menuDigitalPalettePresets) {
      for (final hex in <String>[
        preset.primary, preset.background, preset.text, preset.card,
      ]) {
        expect(pattern.hasMatch(hex), isTrue, reason: preset.name);
      }
      final colors = MenuDigitalColors.fromMenu(<String, dynamic>{
        'primario': preset.primary,
        'fondo': preset.background,
        'texto': preset.text,
        'tarjeta': preset.card,
      });
      expect(MenuDigitalColors.contrast(colors.text, colors.canvas),
          greaterThanOrEqualTo(4.5), reason: preset.name + ' fondo');
      expect(MenuDigitalColors.contrast(colors.text, colors.card),
          greaterThanOrEqualTo(4.5), reason: preset.name + ' tarjeta');
      expect(MenuDigitalColors.contrast(colors.onAccent, colors.accent),
          greaterThanOrEqualTo(4.5), reason: preset.name + ' botón');
    }
  });

  test('Los controles públicos pueden usar los tonos configurados', () {
    final colors = MenuDigitalColors.fromMenu(<String, dynamic>{
      'primario': '#A87C3D', 'fondo': '#FFF9EF',
      'texto': '#302418', 'tarjeta': '#F2E5CB',
    });
    expect(colors.accent, const Color(0xFFA87C3D));
    expect(colors.canvas, const Color(0xFFFFF9EF));
    expect(colors.text, const Color(0xFF302418));
    expect(colors.card, const Color(0xFFF2E5CB));
  });

  testWidgets('Pulsar la imagen muestra la descripción y el precio',
      (tester) async {
    final product = <String, dynamic>{
      'id': 1,
      'nombre': 'Producto de prueba',
      'descripcion': 'Descripción especial de este producto',
      'tipo': 'CERVEZA',
      'precio': 5000,
    };
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SizedBox(
        width: 460,
        height: 800,
        child: MenuDigitalCatalog(menu: <String, dynamic>{
          'titulo': 'Nuestra carta',
          'sucursal': 'Sucursal de prueba',
          'estilo': 'LIBRO',
          'productos': [product],
          'primario': '#A87C3D',
          'fondo': '#FFF9EF',
          'texto': '#302418',
          'tarjeta': '#F2E5CB',
        }),
      )),
    ));
    await tester.pumpAndSettle();
    final thumbnail = find.bySemanticsLabel(
        'Ampliar imagen y descripción de Producto de prueba');
    await tester.ensureVisible(thumbnail.first);
    await tester.tap(thumbnail.first);
    await tester.pumpAndSettle();
    expect(find.text('DETALLES DEL PRODUCTO'), findsOneWidget);
    expect(find.text('Descripción especial de este producto'), findsWidgets);
    expect(find.textContaining('5.000'), findsWidgets);
  });
}
