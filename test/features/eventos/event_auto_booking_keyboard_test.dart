import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/eventos/presentation/widgets/event_public_landing.dart';
import 'package:barlytics_frontend/features/eventos/presentation/widgets/event_visual_kit.dart';

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

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byKey(const Key('event-booking-form-scroll')), findsOneWidget);
    final bar=find.byKey(const Key('event-booking-scrollbar'));
    expect(bar,findsOneWidget);
    final scrollbar=tester.widget<Scrollbar>(bar);
    expect(scrollbar.thumbVisibility,isTrue);
    expect(scrollbar.interactive,isTrue);
    final handle=find.byKey(const Key('event-booking-drag-handle'));
    expect(handle,findsOneWidget);
    final colors=EventPagePalette.fromHex(null,null);
    final decoration=tester.widget<Container>(handle).decoration as BoxDecoration;
    expect(decoration.color,
      Color.lerp(colors.surface,colors.accentOnSurface,.38));
    // La barra la pinta la paleta, no el drag handle azul del tema Flutter.
    expect(tester.widget<BottomSheet>(find.byType(BottomSheet)).showDragHandle,
      false);

    // La regresión real ocurre al abrir el teclado, ANTES de escribir.
    // El panel inferior debe mantener la cabecera y el botón de pago visibles.
    final nameField = find.byKey(const Key('event-booking-name'));
    // No usar ensureVisible: debe desplazarlo el propio formulario al recibir
    // el foco, antes de introducir cualquier carácter en WA Business.
    await tester.showKeyboard(nameField);
    tester.view.viewInsets = const FakeViewPadding(bottom: 335);
    await tester.pumpAndSettle();

    final header = find.text('Reservar puestos').last;
    final continueFixed = find.byKey(const Key('event-booking-continue'));
    expect(header, findsOneWidget);
    expect(continueFixed, findsOneWidget);
    expect(tester.getTopLeft(header).dy, greaterThanOrEqualTo(0));
    expect(tester.getBottomRight(continueFixed).dy, lessThan(440));
    // Antes de teclear, el nombre completo debe quedar encima de la barra
    // fija. Era el defecto reproducido en el navegador de Facebook.
    final nameBottom=tester.getBottomRight(nameField).dy;
    final buttonTop=tester.getTopLeft(continueFixed).dy;
    expect(nameBottom, lessThan(buttonTop),
      reason:'El nombre no puede quedar detrás de Continuar al pago');
    final formScroll=tester.widget<SingleChildScrollView>(
      find.byKey(const Key('event-booking-form-scroll')));
    expect(formScroll.controller?.hasClients,isTrue);
    expect(formScroll.controller!.offset,greaterThan(0),
      reason:'El campo enfocado debe desplazar el scroll sin escribir letras');
    expect(tester.takeException(), isNull);

    await tester.enterText(nameField, 'Cliente de prueba');
    // Abrir y cerrar el teclado no debe desmontar el formulario ni
    // descartar el nombre que acaba de escribir el asistente.
    tester.view.viewInsets = const FakeViewPadding(bottom: 0);
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 335);
    await tester.pumpAndSettle();
    expect(tester.state<FormFieldState<String>>(nameField).value,
      'Cliente de prueba');
    expect(find.text('Reservar puestos').last, findsOneWidget);
    final mailField = find.widgetWithText(TextFormField, 'Correo electrónico *');
    await tester.showKeyboard(mailField);
    await tester.pumpAndSettle();
    expect(tester.getBottomRight(mailField).dy,
      lessThan(tester.getTopLeft(continueFixed).dy),
      reason:'El correo debe permanecer visible con el teclado abierto');
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
