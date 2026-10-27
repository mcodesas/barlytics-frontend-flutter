import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/eventos/presentation/widgets/event_public_landing.dart';

void main() {
  testWidgets('Sin selección de mesa abre diálogo y permite más de cuatro puestos',
      (tester) async {
    tester.view.physicalSize = const Size(1250, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final name = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    addTearDown(() {
      name.dispose();
      email.dispose();
      phone.dispose();
    });

    int? selectedTable;
    int requestedSeats = 1;
    bool booked = false;
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:EventPublicLanding(
        event:{
          'titulo':'Evento de prueba',
          'sucursal':'Establecimiento de prueba',
          'modoReserva':'PUESTOS',
          'seleccionarMesa':false,
          'seleccionarSillas':false,
          'medioPago':'MERCADOPAGO',
          'precioPorPuesto':true,
          'precio':10000,
          'mesas':[
            {'id':3,'numero':1,'capacidad':8,'disponibles':8,
              'estado':'DISPONIBLE'},
          ],
          'carta':[],
        },
        selectedTable:null,
        seats:1,
        busy:false,
        name:name,
        email:email,
        phone:phone,
        onSelectTable:(id)=>selectedTable=id,
        onSeatsChanged:(amount)=>requestedSeats=amount,
        onBook:(_)=>booked=true,
        onShare:(){},
        onRefresh:() async {},
      ),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Mesa 1'),findsNothing);
    await tester.ensureVisible(find.text('Reservar puestos').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reservar puestos').last);
    await tester.pumpAndSettle();
    expect(find.text('Cantidad de puestos'),findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first,'6');
    await tester.enterText(find.widgetWithText(TextFormField,'Nombre completo *'),
        'Cliente de prueba');
    await tester.enterText(find.widgetWithText(TextFormField,'Correo electrónico *'),
        'cliente@example.com');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continuar al pago'));
    await tester.pumpAndSettle();
    expect(selectedTable,-1);
    expect(requestedSeats,6);
    expect(booked,isTrue);
  });
}
