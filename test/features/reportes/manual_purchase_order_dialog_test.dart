import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/reportes/presentation/widgets/manual_purchase_order_dialog.dart';

void main() {
  const products = <Map<String, dynamic>>[
    {
      'producto_id': 11,
      'producto': 'Cerveza Dorada',
      'stock_actual': 100,
      'presentacion_compra': 'Caja x 24',
      'costo_presentacion_actual': 60000,
    },
    {
      'producto_id': 12,
      'producto': 'Agua mineral',
      'stock_actual': 40,
      'presentacion_compra': 'Unidad',
      'unidades_por_presentacion': 12,
      'costo_presentacion_actual': 2000,
    },
    {
      'producto_id': 13,
      'producto': 'Sin costo',
      'stock_actual': 10,
      'presentacion_compra': 'Unidad',
      'costo_presentacion_actual': 0,
    },
  ];

  testWidgets('permite seleccionar cantidades incluso con stock suficiente',
      (tester) async {
    Map<int, int>? selection;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              selection = await showDialog<Map<int, int>>(
                context: context,
                builder: (_) => const ManualPurchaseOrderDialog(
                  products: products,
                  initialSelection: <int, int>{},
                ),
              );
            },
            child: const Text('Abrir pedido'),
          );
        }),
      ),
    ));

    await tester.tap(find.text('Abrir pedido'));
    await tester.pumpAndSettle();
    expect(find.text('Crear pedido manual'), findsOneWidget);
    expect(find.text('Cerveza Dorada'), findsOneWidget);

    // El stock actual es suficiente, pero el pedido manual lo admite.
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('Agregar 1 producto'), findsOneWidget);
    await tester.tap(find.byTooltip('Aumentar paquetes o presentaciones').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar 1 producto'));
    await tester.pumpAndSettle();
    expect(selection, <int, int>{11: 2});
  });

  testWidgets('muestra paquetes y no unidades al elegir la cantidad de compra',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ManualPurchaseOrderDialog(
          products: products,
          initialSelection: <int, int>{12: 2},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Presentación histórica "Unidad", pero realmente compramos por paquetes
    // de 12. Mostrar dos paquetes, no dos unidades ni veinticuatro sueltas.
    expect(find.textContaining('Compra por: 1 paquete x 12'), findsOneWidget);
    expect(find.text('Pedir: 2 paquetes x 12'), findsOneWidget);
    expect(find.text('Pedir: 2 unidades'), findsNothing);
  });

  testWidgets('no permite seleccionar productos sin costo de compra',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ManualPurchaseOrderDialog(
        products: products,
        initialSelection: <int, int>{},
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Sin costo de compra configurado'), findsOneWidget);
    final widgets = tester.widgetList<Checkbox>(find.byType(Checkbox)).toList();
    expect(widgets.last.onChanged, isNull);
  });
  testWidgets('pedido manual no excede viewport reducido por teclado', (tester) async {
    tester.view.physicalSize = const Size(360, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ManualPurchaseOrderDialog(
          products: products,
          initialSelection: <int, int>{},
        ),
      ),
    ));
    tester.view.viewInsets = const FakeViewPadding(bottom: 310);
    await tester.pumpAndSettle();
    expect(find.text('Crear pedido manual'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final dialogRect = tester.getRect(find.byType(Dialog));
    expect(dialogRect.top, greaterThanOrEqualTo(0));
    expect(dialogRect.bottom, lessThanOrEqualTo(600));
  });

}
