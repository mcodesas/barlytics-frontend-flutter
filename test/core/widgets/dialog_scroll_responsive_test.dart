import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/core/widgets/confirmation_dialog.dart';
import 'package:barlytics_frontend/features/reportes/presentation/widgets/manual_purchase_order_dialog.dart';

void main() {
  testWidgets('Confirmación larga permite desplazar y confirmar en iPhone pequeño',
      (tester) async {
    tester.view.physicalSize = const Size(320, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    bool? accepted;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) => Center(
          child: FilledButton(
            onPressed: () async {
              accepted = await showConfirmationDialog(
                context,
                title: 'Confirmación de información bastante extensa',
                message: List.filled(70,
                    'Esta operación requiere leer todos los detalles.').join(' '),
              );
            },
            child: const Text('Abrir diálogo'),
          ),
        )),
      ),
    ));
    await tester.tap(find.text('Abrir diálogo'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Confirmar'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(accepted, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pedido manual mantiene búsqueda y botones en vista compacta',
      (tester) async {
    tester.view.physicalSize = const Size(360, 690);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (context) => FilledButton(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => const ManualPurchaseOrderDialog(
            products: [],
            initialSelection: {},
          ),
        ),
        child: const Text('Abrir pedido manual'),
      ))),
    ));
    await tester.tap(find.text('Abrir pedido manual'));
    await tester.pumpAndSettle();

    expect(find.text('Crear pedido manual'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('Buscar por nombre, presentación o código'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('Pedido con productos no desborda en móvil estrecho', (tester) async {
    tester.view.physicalSize = const Size(320, 580);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (context) => FilledButton(
        onPressed: () => showDialog<Map<int, int>>(
          context: context,
          builder: (_) => const ManualPurchaseOrderDialog(
            products: [
              {
                'producto_id': 1,
                'producto': 'Producto de presentación de compra extensa',
                'presentacion_compra': 'Paquete',
                'costo_presentacion_actual': 12000,
                'stock_actual': 10,
                'unidades_por_presentacion': 6,
              },
            ],
            initialSelection: {},
          ),
        ),
        child: const Text('Abrir'),
      ))),
    ));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Producto de presentación de compra extensa'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

}
