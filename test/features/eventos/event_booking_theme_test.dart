import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/eventos/presentation/widgets/event_public_landing.dart';
import 'package:barlytics_frontend/features/eventos/presentation/widgets/event_visual_kit.dart';

void main(){
  testWidgets('Modal de reservas utiliza contraste del evento y no azul global',
      (tester)async{
    tester.view.physicalSize=const Size(1000,1200);
    tester.view.devicePixelRatio=1;
    addTearDown((){
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final name=TextEditingController();
    final email=TextEditingController();
    final phone=TextEditingController();
    addTearDown((){
      name.dispose();email.dispose();phone.dispose();
    });

    await tester.pumpWidget(MaterialApp(
      theme:ThemeData(colorScheme:ColorScheme.fromSeed(seedColor:Colors.blue)),
      home:EventPublicLanding(
        event:{
          'titulo':'Evento de prueba',
          'sucursal':'Sucursal de prueba',
          'modoReserva':'PUESTOS',
          'seleccionarMesa':false,
          'precioPorPuesto':true,
          'medioPago':'MERCADOPAGO',
          'precio':40000,
          'colorPrimario':'#C19547',
          'colorFondo':'#F4EBDE',
          'colorTarjeta':'#F7EFE3',
          'colorTexto':'#35271F',
          'colorBorde':'#D6C4AF',
          'mesas':[{
            'id':1,'numero':1,'capacidad':8,'disponibles':8,
            'estado':'DISPONIBLE',
          }],
          'carta':[],
        },
        selectedTable:null,
        seats:4,
        busy:false,
        name:name,
        email:email,
        phone:phone,
        onSelectTable:(_){},
        onSeatsChanged:(_){},
        onBook:(_){},
        onShare:(){},
        onRefresh:()async{},
      ),
    ));

    await tester.pumpAndSettle();
    final action=find.text('Elegir mis puestos').last;
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();

    expect(find.text('Cantidad de puestos'),findsOneWidget);
    final field=find.widgetWithText(TextFormField,'Nombre completo *');
    expect(field,findsOneWidget);
    final theme=Theme.of(tester.element(field));
    final input=theme.inputDecorationTheme;
    final background=input.fillColor!;
    expect(EventPagePalette.contrast(input.labelStyle!.color!,background),
      greaterThanOrEqualTo(4.48));
    expect(EventPagePalette.contrast(input.counterStyle!.color!,background),
      greaterThanOrEqualTo(4.48));
    expect(EventPagePalette.contrast(input.prefixIconColor!,background),
      greaterThanOrEqualTo(4.48));
    expect(theme.colorScheme.primary,isNot(Colors.blue));
    expect(find.text('160.000 COP'),findsWidgets);
  });
}
