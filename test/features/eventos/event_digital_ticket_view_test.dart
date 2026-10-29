import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/eventos/presentation/widgets/event_digital_ticket_view.dart';
import 'package:barlytics_frontend/features/eventos/presentation/widgets/event_visual_kit.dart';

void main() {
  testWidgets('Finalizar permite regresar al evento desde una reserva pendiente',
      (tester) async {
    var finished = false;
    var refreshes = 0;
    await tester.pumpWidget(MaterialApp(
      home: EventDigitalTicketView(
        token: 'token-ejemplo',
        value: const <String, dynamic>{
          'evento': 'Noche de celebración',
          'sucursal': 'La barra reserva',
          'estado': 'PENDIENTE_PAGO',
          'mesa': 1,
          'puestos': 1,
          'mesas': <dynamic>[],
          'mensajeEstado': 'Esperando aprobación del pago.',
        },
        error: null,
        palette: EventPagePalette.fromHex('#35D0C5', '#102735'),
        qrUrl: (token) => 'https://example.com/qr',
        onRefresh: () => refreshes++,
        onFinish: () => finished = true,
        onPay: (url) async {},
      ),
    ));

    expect(find.text('Pendiente de pago'), findsWidgets);
    expect(find.text('Noche de celebración'), findsOneWidget);
    expect(find.text('Tus entradas individuales'), findsNothing);

    final button = find.byKey(const Key('event-ticket-finish'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pump();
    expect(finished, isTrue);
    expect(refreshes, 0);
  });

  testWidgets('La entrada adapta su diseño a fondos claros', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: EventDigitalTicketView(
        token: 'token-ejemplo',
        value: const <String, dynamic>{
          'evento': 'Cena especial',
          'sucursal': 'Sede principal',
          'estado': 'PENDIENTE_REVISION',
          'mesa': 4,
          'puestos': 2,
          'mesas': <dynamic>[],
        },
        error: null,
        palette: EventPagePalette.fromHex(
          '#AC8246', '#F3E7D3', '#2A211C'),
        qrUrl: (token) => 'https://example.com/qr',
        onRefresh: () {},
        onFinish: () {},
        onPay: (url) async {},
      ),
    ));
    expect(find.text('Cena especial'), findsOneWidget);
    expect(find.text('Pendiente de aprobación'), findsWidgets);
    expect(find.text('2 puestos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Reserva confirmada muestra QR y acceso individual',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: EventDigitalTicketView(
        token: 'reserva-principal',
        value: const <String, dynamic>{
          'evento': 'Festival de apertura',
          'sucursal': 'La barra reserva',
          'estado': 'CONFIRMADA',
          'mesa': 1,
          'puestos': 1,
          'mesas': <dynamic>[],
          'entradas': <dynamic>[
            <String, dynamic>{
              'numero': 1,
              'mesa': 1,
              'silla': 2,
              'token': 'entrada-individual',
              'url': 'https://example.com/entrada',
            },
          ],
        },
        error: null,
        palette: EventPagePalette.fromHex('#35D0C5', '#102735'),
        qrUrl: (token) => 'https://example.com/qr',
        onRefresh: () {},
        onFinish: () {},
        onPay: (url) async {},
      ),
    ));
    expect(find.text('Reserva confirmada'), findsWidgets);
    expect(find.text('Tus entradas individuales'), findsOneWidget);
    expect(find.text('Entrada 1 de 1'), findsOneWidget);
    expect(find.text('Mesa 1 · Puesto 2'), findsOneWidget);
    expect(find.byKey(const Key('event-ticket-finish')), findsOneWidget);
  });

}
