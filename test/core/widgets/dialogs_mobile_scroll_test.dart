import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/core/widgets/confirmation_dialog.dart';

void main() {
  testWidgets('La confirmación permite desplazarse en pantalla pequeña con teclado',
      (tester) async {
    tester.view.physicalSize = const Size(320, 520);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () => showConfirmationDialog(
              context,
              title: 'Confirmar cambios pendientes',
              message: List.filled(28,
                'El contenido debe conservarse visible y desplazable.').join(' '),
            ),
            child: const Text('Abrir confirmación'),
          );
        }),
      ),
    ));
    await tester.tap(find.text('Abrir confirmación'));
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.widget<AlertDialog>(find.byType(AlertDialog)).scrollable, isTrue);
    expect(find.byType(Scrollable), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  test('Mano de obra usa alto disponible y scroll general en móvil', () {
    final source = File(
      'lib/features/gastos_fijos/presentation/pages/gastos_fijos_page.dart',
    ).readAsStringSync();

    expect(source, contains("Key('labor-dialog-mobile-scroll')"));
    expect(source, contains('MediaQuery.viewInsetsOf(context).bottom'));
    expect(source, contains('ScrollViewKeyboardDismissBehavior.onDrag'));
    expect(source, contains('_rolesPane(compact: true)'));
    expect(source, contains('_configurationPane(compact: true)'));
    expect(source, contains('SizedBox(height: 230, child: _rateHistory(selectedRates))'));
    expect(source, isNot(contains('SizedBox(height: 260, child: _rolesPane())')));
  });
}
