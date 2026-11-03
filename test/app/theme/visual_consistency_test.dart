import 'package:barlytics_frontend/app/theme/app_palette.dart';
import 'package:barlytics_frontend/app/theme/app_theme.dart';
import 'package:barlytics_frontend/core/widgets/confirmation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('El tema compartido mantiene superficies y colores de la paleta', () {
    final palette = appPalettes.first;
    final theme = AppTheme.buildFromPalette(palette);
    expect(theme.colorScheme.surface, palette.surface);
    expect(theme.colorScheme.onSurface, palette.textPrimary);
    expect(theme.cardTheme.shape, isA<RoundedRectangleBorder>());
    expect(theme.dialogTheme.shape, isA<RoundedRectangleBorder>());
    expect(theme.bottomSheetTheme.shape, isA<RoundedRectangleBorder>());
  });

  testWidgets('Las confirmaciones respetan la paleta y caben en móvil pequeño',
      (tester) async {
    tester.view.physicalSize = const Size(320, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final palette = appPalettes.first;
    bool? result;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.buildFromPalette(palette),
      home: Scaffold(
        body: Builder(builder: (context) => Center(
          child: FilledButton(
            onPressed: () async {
              result = await showConfirmationDialog(
                context,
                title: 'Validar operación y cambios del negocio',
                message: List.filled(
                  35, 'Esta operación requiere revisar las condiciones.').join(' '),
              );
            },
            child: const Text('Abrir confirmación'),
          ),
        )),
      ),
    ));
    await tester.tap(find.text('Abrir confirmación'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('Confirmar'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(tester.takeException(), isNull);
  });
}
