import 'package:barlytics_frontend/features/mesero/presentation/providers/mesero_tab_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Vender / Mesas siempre apunta a la vista Mesas', () {
    expect(meseroModeForMenuPath('/mesero'), MeseroPageMode.mesas);
    expect(meseroModeForMenuPath('/administrar_mesas'), MeseroPageMode.mesas);
  });

  test('Cada enlace del POS abre la pestaña correspondiente', () {
    expect(meseroModeForMenuPath('/mesero/productos'), MeseroPageMode.productos);
    expect(meseroModeForMenuPath('/mesero/historial'), MeseroPageMode.historial);
    expect(meseroModeForMenuPath('/historial_ventas'), MeseroPageMode.historial);
    expect(meseroModeForMenuPath('/mesero/cierre-caja'), MeseroPageMode.cierreCaja);
    expect(meseroModeForMenuPath('/cierre_caja'), MeseroPageMode.cierreCaja);
    expect(meseroModeForMenuPath('/mesero/resumen'), MeseroPageMode.resumen);
    expect(meseroModeForMenuPath('/home'), isNull);
  });

  testWidgets('Volver a Mesas desde Cierre de caja restaura la vista',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(meseroSelectedModeProvider.notifier).state =
        MeseroPageMode.cierreCaja;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () =>
                    selectMeseroModeForMenuPath(ref, '/mesero'),
                child: const Text('Vender / Mesas'),
              ),
            ),
          ),
        ),
      ),
    );

    expect(container.read(meseroSelectedModeProvider),
        MeseroPageMode.cierreCaja);
    await tester.tap(find.text('Vender / Mesas'));
    await tester.pump();
    expect(container.read(meseroSelectedModeProvider), MeseroPageMode.mesas);
  });

  testWidgets('Seleccionar nuevamente Mesas funciona si la ruta no cambia',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () =>
                    selectMeseroModeForMenuPath(ref, '/mesero'),
                child: const Text('Vender / Mesas'),
              ),
            ),
          ),
        ),
      ),
    );
    container.read(meseroSelectedModeProvider.notifier).state =
        MeseroPageMode.productos;
    await tester.tap(find.text('Vender / Mesas'));
    await tester.pump();
    expect(container.read(meseroSelectedModeProvider), MeseroPageMode.mesas);
  });
}
