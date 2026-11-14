import 'package:barlytics_frontend/features/menu_digital/presentation/widgets/menu_digital_design_thumbnail.dart';
import 'package:barlytics_frontend/features/menu_digital/presentation/widgets/menu_digital_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final palette = MenuDigitalColors.fromMenu({
    'primario': '#14B8A6',
    'fondo': '#081B27',
    'texto': '#F8FAFC',
    'tarjeta': '#112D3B',
  });

  for (final style in const [
    'TIENDA', 'LIBRO', 'EDITORIAL', 'GALERIA', 'MINIMALISTA',
    'DOCUMENTO', 'ELEGANTE', 'TIENDA_WEB', 'BISTRO', 'NOCTURNO',
  ]) {
    for (final width in const [115.0, 180.0, 390.0]) {
      testWidgets('Miniatura $style a $width px sin desbordamiento',
          (tester) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Center(child: SizedBox(
              width: width,
              height: 108,
              child: MenuDigitalDesignThumbnail(
                colors: palette, style: style,
              ),
            )),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('Fuente del sistema grande no rompe las miniaturas',
      (tester) async {
    for (final style in const ['ELEGANTE', 'BISTRO', 'NOCTURNO']) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(1.8),
            ),
            child: SizedBox(
              height: 108,
              width: 165,
              child: MenuDigitalDesignThumbnail(
                colors: palette, style: style,
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
