import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/eventos/presentation/widgets/event_public_landing.dart';
import 'package:barlytics_frontend/features/eventos/presentation/widgets/event_visual_kit.dart';

void main(){
  testWidgets('Botones secundarios se leen sobre cualquier fotografía de portada',
      (tester)async{
    tester.view.physicalSize=const Size(1440,950);
    tester.view.devicePixelRatio=1;
    final name=TextEditingController();
    final email=TextEditingController();
    final phone=TextEditingController();
    addTearDown((){
      name.dispose();email.dispose();phone.dispose();
      tester.view.resetPhysicalSize();tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(home:EventPublicLanding(
      event:{
        'titulo':'Evento personalizado',
        'sucursal':'Sucursal Norte',
        'descripcion':'Fiesta y comida',
        'ubicacionGoogleMaps':'https://maps.google.com/',
        'colorPrimario':'#C7984B',
        'colorFondo':'#F6ECE0',
        'colorTarjeta':'#F9EEDD',
        'colorTexto':'#332A24',
        'colorBorde':'#CDB79C',
        'modoReserva':'PUESTOS',
        'seleccionarMesa':false,
        'precioPorPuesto':true,
        'precio':40000,
        'mesas':[{'id':1,'capacidad':8,'disponibles':8}],
        'carta':[],
      },
      selectedTable:null,seats:1,busy:false,
      name:name,email:email,phone:phone,
      onSelectTable:(_){},onSeatsChanged:(_){},onBook:(_){},
      onShare:(){},onRefresh:()async{},
    )));
    await tester.pumpAndSettle();
    final p=EventPagePalette.fromHex(
      '#C7984B','#F6ECE0','#332A24','#F9EEDD','#CDB79C',null);
    for(final label in ['Cómo llegar','Compartir']){
      final button=tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton,label));
      final style=button.style!;
      final bg=style.backgroundColor!.resolve(<WidgetState>{})!;
      final fg=style.foregroundColor!.resolve(<WidgetState>{})!;
      expect(bg,p.surface);
      expect(EventPagePalette.contrast(fg,bg),greaterThanOrEqualTo(4.5));
      expect(style.minimumSize!.resolve(<WidgetState>{})!.height,
        greaterThanOrEqualTo(44));
    }
    final floating=find.byType(FloatingActionButton);
    expect(floating,findsNothing); // No se inventa WhatsApp sin contacto.
  });
}
