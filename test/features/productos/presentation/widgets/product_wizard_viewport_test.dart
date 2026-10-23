import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/productos/presentation/widgets/product_wizard_viewport.dart';

void main() {
  Future<void> setIPhoneViewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('edición del producto muestra campos y navegación debajo',
      (tester) async {
    await setIPhoneViewport(tester);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        // Simula el encabezado y la barra del AppScaffold real.
        body: Column(
          children: [
            const SizedBox(height: 112, child: Text('Encabezado BarLytics')),
            Expanded(
              child: ProductWizardViewport(
                content: ListView(
                  children: [
                    const Text('Modificar producto'),
                    const TextField(
                      decoration: InputDecoration(labelText: 'Nombre del producto'),
                    ),
                    const TextField(
                      decoration: InputDecoration(labelText: 'Descripción'),
                    ),
                    for (var i = 0; i < 12; i++)
                      SizedBox(height: 65, child: Text('Campo $i')),
                  ],
                ),
                navigation: const SafeArea(
                  top: false,
                  child: SizedBox(height: 108, child: Text('Siguiente / Anterior')),
                ),
              ),
            ),
            const SizedBox(height: 68, child: Text('Barra inferior')),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Nombre del producto'), findsOneWidget);
    expect(find.text('Modificar producto'), findsOneWidget);
    expect(find.text('Siguiente / Anterior'), findsOneWidget);

    final fieldTop = tester.getTopLeft(find.text('Nombre del producto')).dy;
    final footerTop = tester.getTopLeft(find.text('Siguiente / Anterior')).dy;
    expect(fieldTop, lessThan(footerTop));
    expect(footerTop, greaterThan(480));
    expect(tester.takeException(), isNull);
  });

  testWidgets('cambiar de paso conserva una zona de formulario visible',
      (tester) async {
    await setIPhoneViewport(tester);
    var step = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, update) => ProductWizardViewport(
            content: ListView(
              key: ValueKey('paso-$step'),
              children: [
                Text(step == 0 ? 'Nombre del producto' : 'Valor de compra'),
                SizedBox(height: step == 0 ? 800 : 350),
              ],
            ),
            navigation: SafeArea(
              child: ElevatedButton(
                onPressed: () => update(() => step = 1),
                child: const Text('Siguiente'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Nombre del producto'), findsOneWidget);
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Valor de compra'), findsOneWidget);
    expect(find.text('Siguiente'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Valor de compra')).dy, lessThan(160));
    expect(tester.takeException(), isNull);
  });
  testWidgets('el formulario no desaparece bajo un padre sin altura acotada',
      (tester) async {
    await setIPhoneViewport(tester);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ProductWizardViewport(
            content: ListView(
              children: const [
                Text('Editar producto'),
                Text('Nombre del producto'),
                SizedBox(height: 450),
              ],
            ),
            navigation: const SizedBox(
              height: 104,
              child: Center(child: Text('Siguiente y Anterior')),
            ),
          ),
        ),
      ),
    ));

    expect(find.text('Nombre del producto'), findsOneWidget);
    expect(find.text('Siguiente y Anterior'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Nombre del producto')).dy,
      lessThan(tester.getTopLeft(find.text('Siguiente y Anterior')).dy),
    );
    expect(tester.takeException(), isNull);
  });

}
