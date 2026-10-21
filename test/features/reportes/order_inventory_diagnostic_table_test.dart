import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/app/theme/app_palette.dart';
import 'package:barlytics_frontend/features/reportes/presentation/widgets/order_inventory_diagnostic_table.dart';

void main() {
  const rows = <Map<String, dynamic>>[
    {
      'producto': 'Cerveza Dorada',
      'stock_actual': 2,
      'stock_minimo': 12,
      'stock_maximo': 40,
      'estado_reposicion': 'PEDIR_AHORA',
      'presentaciones_pedir': 2,
      'presentacion_compra': 'Caja',
      'costo_pedido_estimado': 140000,
    },
  ];

  testWidgets('móvil muestra estado y valores legibles', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: OrderInventoryDiagnosticTable(
            rows: rows,
            palette: appPalettes.first,
          ),
        ),
      ),
    ));
    expect(find.text('Cerveza Dorada'), findsOneWidget);
    expect(find.text('Pedir ahora'), findsOneWidget);
    expect(find.text('Disponible'), findsOneWidget);
    expect(find.text('Sugerido: 2 Caja'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('escritorio muestra columnas en tabla', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: OrderInventoryDiagnosticTable(
          rows: rows,
          palette: appPalettes.first,
        ),
      ),
    ));
    expect(find.byType(Table), findsOneWidget);
    expect(find.text('Compra sugerida'), findsOneWidget);
    expect(find.text('Mínimo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
