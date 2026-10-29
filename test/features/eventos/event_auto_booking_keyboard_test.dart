import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/eventos/presentation/widgets/event_public_landing.dart';

void main() {
  testWidgets('iPhone: el teclado no bloquea el formulario ni continuar al pago',
      (tester) async {
    tester.view.physicalSize = const Size(390, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });

    final name = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    addTearDown(() {
      name.dispose();
      email.dispose();
      phone.dispose();
    });
    var booked = false;
    var assignedSeats = 0;

    await tester.pumpWidget(MaterialApp(
      home: EventPublicLanding(
        event: {
          'titulo': 'Noche de estreno',
          'sucursal': 'La barra reserva',
          'modoReserva': 'PUESTOS',
          'seleccionarMesa': false,
          'precioPorPuesto': true,
          'medioPago': 'MERCADOPAGO',
          'precio': 40000,
          'mesas': [
            {'id': 1, 'numero': 1, 'capacidad': 6,
             'disponibles': 6, 'estado': 'DISPONIBLE'},
          ],
          'carta': [],
        },
        selectedTable: null,
        seats: 1,
        busy: false,
        name: name,
        email: email,
        phone: phone,
        onSelectTable: (_) {},
        onSeatsChanged: (value) => assignedSeats = value,
        onBook: (_) => booked = true,
        onShare: () {},
        onRefresh: () async {},
      ),
    ));
    await tester.pumpAndSettle();

    final open = find.text('Elegir mis puestos').last;
    await tester.ensureVisible(open);
    await tester.tap(open);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.widget<AlertDialog>(find.byType(AlertDialog)).scrollable, true);

    // Simula teclado del navegador integrado de Instagram en iPhone.
    tester.view.viewInsets = const FakeViewPadding(bottom: 335);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final nameField = find.widgetWithText(TextFormField, 'Nombre completo *');
    await tester.ensureVisible(nameField);
    await tester.enterText(nameField, 'Cliente de prueba');
    final mailField = find.widgetWithText(TextFormField, 'Correo electrónico *');
    await tester.ensureVisible(mailField);
    await tester.enterText(mailField, 'cliente@example.com');
    await tester.pumpAndSettle();

    // El botón está fuera del contenido desplazable, no detrás del teclado.
    final continueButton = find.text('Continuar al pago');
    expect(continueButton, findsOneWidget);
    await tester.ensureVisible(continueButton);
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(booked, isTrue);
    expect(assignedSeats, 1);
    expect(name.text, 'Cliente de prueba');
    expect(email.text, 'cliente@example.com');
    expect(tester.takeException(), isNull);
  });
}
