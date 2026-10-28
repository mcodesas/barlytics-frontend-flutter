import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/eventos/presentation/widgets/event_public_landing.dart';

void main(){
  testWidgets('Cerrar y volver a abrir la reserva no reutiliza un controller disposed',
    (tester) async {
    tester.view.physicalSize=const Size(1100,1350);
    tester.view.devicePixelRatio=1;
    addTearDown((){
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final name=TextEditingController(text:'Cliente prueba');
    final email=TextEditingController(text:'cliente@example.com');
    final phone=TextEditingController();
    addTearDown((){
      name.dispose();email.dispose();phone.dispose();
    });

    int selectedSeats=1;
    int bookings=0;
    await tester.pumpWidget(MaterialApp(home:StatefulBuilder(
      builder:(context,rebuild)=>EventPublicLanding(
        event:{
          'titulo':'Reserva de prueba',
          'sucursal':'Sucursal A',
          'modoReserva':'PUESTOS',
          'seleccionarMesa':false,
          'precioPorPuesto':true,
          'medioPago':'MERCADOPAGO',
          'precio':5000,
          'mesas':[{
            'id':4,'numero':1,'capacidad':4,'disponibles':4,
            'estado':'DISPONIBLE'
          }],
          'carta':[],
        },
        selectedTable:null,seats:selectedSeats,busy:false,
        name:name,email:email,phone:phone,
        onSelectTable:(_){},
        onSeatsChanged:(count)=>rebuild(()=>selectedSeats=count),
        onBook:(_)=>bookings++,
        onShare:(){},
        onRefresh:()async{},
      ),
    )));
    await tester.pumpAndSettle();

    Future<void> open() async {
      final action=find.text('Elegir mis puestos').last;
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.text('Cantidad de puestos'),findsOneWidget);
    }

    await open();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(),isNull);

    await open();
    await tester.enterText(find.byType(TextFormField).first,'3');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar al pago'));
    await tester.pumpAndSettle();
    expect(tester.takeException(),isNull);
    expect(selectedSeats,3);
    expect(bookings,1);

    // El widget original y los controladores de nombre/correo siguen vivos;
    // el campo numérico anterior pertenece únicamente al diálogo anterior.
    await open();
    expect(tester.widget<TextFormField>(
      find.byType(TextFormField).first).initialValue,'3');
    await tester.tap(find.byTooltip('Agregar un puesto'));
    await tester.pumpAndSettle();
    expect(find.text('4'),findsWidgets);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(),isNull);
  });

  testWidgets('Cerrar el modal mientras se desmonta la página no genera excepción',
    (tester)async{
    final name=TextEditingController(),email=TextEditingController(),
      phone=TextEditingController();
    addTearDown((){
      name.dispose();email.dispose();phone.dispose();
    });
    await tester.pumpWidget(MaterialApp(home:EventPublicLanding(
      event:{
        'titulo':'Evento','sucursal':'Sede',
        'modoReserva':'PUESTOS','seleccionarMesa':false,
        'medioPago':'MERCADOPAGO','precio':5000,
        'mesas':[{'id':1,'capacidad':4,'disponibles':4}],
      },
      selectedTable:null,seats:1,busy:false,
      name:name,email:email,phone:phone,
      onSelectTable:(_){},onSeatsChanged:(_){},onBook:(_){},
      onShare:(){},onRefresh:()async{},
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elegir mis puestos').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home:Scaffold()));
    await tester.pumpAndSettle();
    expect(tester.takeException(),isNull);
  });
}
