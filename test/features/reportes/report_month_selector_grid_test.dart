import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/reportes/presentation/widgets/report_month_selector_grid.dart';

const _months = <String>[
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
];

Widget _testApp({required ValueChanged<int> onSelected, int year = 2026}) =>
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                scrollable: true,
                title: const Text('Selecciona el mes'),
                content: SizedBox(
                  width: 430,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(children: [
                        const Icon(Icons.calendar_month_rounded),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Año $year')),
                      ]),
                      const SizedBox(height: 16),
                      ReportMonthSelectorGrid(
                        monthNames: _months,
                        selectedYear: year,
                        selectedMonth: 10,
                        currentYear: 2026,
                        currentMonth: 11,
                        onSelected: onSelected,
                      ),
                      const SizedBox(height: 12),
                      const Text('Mes seleccionado: Octubre'),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ],
              ),
            ),
            child: const Text('Abrir selector'),
          ),
        ),
      ),
    );

void main() {
  testWidgets('El selector de mes cabe en AlertDialog scrollable en móvil',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final months = <int>[];
    await tester.pumpWidget(_testApp(onSelected: months.add));
    await tester.tap(find.text('Abrir selector'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Selecciona el mes'), findsOneWidget);
    expect(find.text('Enero'), findsOneWidget);
    expect(find.text('Diciembre'), findsOneWidget);
    expect(find.byType(GridView), findsNothing);
  });

  testWidgets('El selector de mes cabe en diálogo de escritorio',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp(onSelected: (_) {}));
    await tester.tap(find.text('Abrir selector'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Septiembre'), findsOneWidget);
  });

  testWidgets('No permite seleccionar meses futuros del año actual',
      (tester) async {
    final months = <int>[];
    await tester.pumpWidget(_testApp(onSelected: months.add));
    await tester.tap(find.text('Abrir selector'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Diciembre'));
    await tester.pump();
    expect(months, isEmpty);

    await tester.tap(find.text('Enero'));
    await tester.pump();
    expect(months, [1]);
    expect(tester.takeException(), isNull);
  });
}
