import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/eventos/presentation/widgets/event_public_landing.dart';

void main(){
  Future<void> render(WidgetTester tester,{String? phone})async{
    tester.view.physicalSize=const Size(390,844);
    tester.view.devicePixelRatio=1;
    final name=TextEditingController();
    final email=TextEditingController();
    final contact=TextEditingController();
    addTearDown((){
      name.dispose();email.dispose();contact.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(home:EventPublicLanding(
      event:{
        'titulo':'Evento móvil','sucursal':'Sucursal principal',
        'telefono':phone,'modoReserva':'PUESTOS',
        'seleccionarMesa':false,'precioPorPuesto':true,
        'precio':40000,'medioPago':'MERCADOPAGO',
        'mesas':[{'id':1,'numero':1,'capacidad':8,'disponibles':8}],
        'carta':[],
      },
      selectedTable:null,seats:1,busy:false,
      name:name,email:email,phone:contact,
      onSelectTable:(_){},onSeatsChanged:(_){},onBook:(_){},
      onShare:(){},onRefresh:()async{},
    )));
    await tester.pumpAndSettle();
  }

  testWidgets('WhatsApp flota separado de la barra de reserva móvil',(tester)async{
    await render(tester,phone:'314 257 1739');
    final scaffold=tester.widget<Scaffold>(find.byType(Scaffold).last);
    expect(scaffold.floatingActionButton,isA<FloatingActionButton>());
    expect(scaffold.bottomNavigationBar,isNotNull);
    expect(find.descendant(
      of:find.byWidget(scaffold.bottomNavigationBar!),
      matching:find.byType(OutlinedButton)),findsNothing);
    expect(find.descendant(
      of:find.byWidget(scaffold.bottomNavigationBar!),
      matching:find.byType(FilledButton)),findsOneWidget);
    expect(find.byTooltip('¿Dudas? Escríbenos por WhatsApp'),findsOneWidget);
  });

  testWidgets('Sin teléfono válido no muestra botón de ayuda',(tester)async{
    await render(tester,phone:null);
    final scaffold=tester.widget<Scaffold>(find.byType(Scaffold).last);
    expect(scaffold.floatingActionButton,isNull);
    expect(find.text('Reservar puestos'),findsWidgets);
  });
}
