import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/app/theme/app_palette.dart';
import 'package:barlytics_frontend/features/reportes/presentation/widgets/profit_expense_breakdown.dart';

void main() {
  const expenses = <Map<String, dynamic>>[
    {'categoria': 'FIJO', 'concepto': 'Arriendo', 'valor': 100000},
    {'categoria': 'MANO DE OBRA', 'concepto': 'Mesero', 'valor': 50000},
  ];

  Future<void> showBreakdown(WidgetTester tester, {
    Map<String, dynamic> finance = const {'gastos_operativos_periodo': 150000},
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ProfitExpenseBreakdown(
            items: expenses,
            finance: finance,
            palette: appPalettes.first,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('muestra suma de gastos y mano de obra por concepto', (tester) async {
    await showBreakdown(tester);

    expect(find.text('Detalle de gastos del período'), findsOneWidget);
    expect(find.text('Desglose conciliado'), findsOneWidget);
    expect(find.text('Arriendo'), findsOneWidget);
    expect(find.text('Mesero'), findsOneWidget);
    expect(find.text('Mano de obra'), findsWidgets);
  });

  testWidgets('permite buscar un concepto sin alterar los totales', (tester) async {
    await showBreakdown(tester);

    await tester.enterText(find.byType(TextField), 'Mesero');
    await tester.pumpAndSettle();
    expect(find.text('Mesero'), findsWidgets);
    expect(find.text('Arriendo'), findsNothing);
    expect(find.text('Desglose conciliado'), findsOneWidget);
  });

  testWidgets('advierte si la suma del detalle es distinta del total del backend', (tester) async {
    await showBreakdown(
      tester,
      finance: const {'gastos_operativos_periodo': 160000},
    );
    expect(find.textContaining('Diferencia por revisar'), findsOneWidget);
  });
}
