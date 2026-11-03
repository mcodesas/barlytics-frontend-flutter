import 'package:barlytics_frontend/features/mesero/presentation/widgets/venta_historica_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildActions({required String estado, bool autorizado = true}) =>
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: VentaHistoricaActions(
                ventaId: 77,
                estado: estado,
                autorizado: autorizado,
                totalPagado: 15000,
                onAnulada: () async {},
                onCorregida: (id) async {},
              ),
            ),
          ),
        ),
      );

  testWidgets('Una venta anulada puede retomar la corrección posteriormente',
      (tester) async {
    await tester.pumpWidget(buildActions(estado: 'ANULADA'));
    expect(find.text('Retomar o corregir venta'), findsOneWidget);
    expect(find.text('Desanular venta'), findsOneWidget);
    expect(find.text('Ver motivo y auditoría'), findsOneWidget);

    await tester.tap(find.text('Retomar o corregir venta'));
    await tester.pumpAndSettle();
    expect(find.text('Retomar corrección #77'), findsOneWidget);
    expect(find.textContaining('NO se volverá a devolver stock'), findsOneWidget);
    expect(find.text('Retomar corrección'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsOneWidget);
  });

  testWidgets('Desanular requiere motivo y confirmación explícita',
      (tester) async {
    await tester.pumpWidget(buildActions(estado: 'ANULADA'));
    await tester.tap(find.text('Desanular venta'));
    await tester.pumpAndSettle();

    expect(find.text('Desanular venta #77'), findsOneWidget);
    expect(find.text('Confirmar desanulación'), findsOneWidget);
    final confirm = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Confirmar desanulación'));
    expect(confirm.onPressed, isNull);
    expect(find.textContaining('se archivará automáticamente'), findsOneWidget);
  });

  testWidgets('Una venta finalizada permite corregir o anular',
      (tester) async {
    await tester.pumpWidget(buildActions(estado: 'FINALIZADA'));
    expect(find.text('Corregir venta'), findsOneWidget);
    expect(find.text('Anular venta'), findsOneWidget);
    expect(find.text('Retomar o corregir venta'), findsNothing);
  });

  testWidgets('Mesero sin rol autorizado no ve acciones administrativas',
      (tester) async {
    await tester.pumpWidget(
        buildActions(estado: 'ANULADA', autorizado: false));
    expect(find.text('Retomar o corregir venta'), findsNothing);
    expect(find.text('Ver motivo y auditoría'), findsNothing);
    expect(find.text('Desanular venta'), findsNothing);
  });
}
