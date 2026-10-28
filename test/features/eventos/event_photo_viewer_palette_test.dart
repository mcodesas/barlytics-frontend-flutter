import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/eventos/presentation/widgets/event_visual_kit.dart';
import 'package:barlytics_frontend/features/eventos/presentation/widgets/event_photo_viewer.dart';

void main(){
  // PNG de un pixel para probar el visor sin depender de servidores externos.
  const image='data:image/png;base64,'
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/liMAAAAASUVORK5CYII=';
  testWidgets('Foto hereda colores seleccionados aun al abrir Dialog en Navigator',
      (tester)async{
    final p=EventPagePalette.fromHex(
      '#BD7F46','#F1E4D3','#2C211B','#F7EDDD','#BA9D80','#F2E2D0');
    await tester.pumpWidget(MaterialApp(
      home:Scaffold(body:Builder(builder:(context)=>EventPaletteScope(
        palette:p,
        child:Builder(builder:(inner)=>TextButton(
          onPressed:()=>showEventPhotoViewer(inner,
            eventPalette:p,
            images:[image,image],
            labels:['Fotografía del lugar 1','Fotografía del lugar 2']),
          child:const Text('Abrir galería'),
        )),
      ))),
    ));
    await tester.tap(find.text('Abrir galería'));
    await tester.pumpAndSettle();
    expect(find.text('Fotografía del lugar 1'),findsOneWidget);
    final fullscreen=find.byType(Dialog);
    expect(fullscreen,findsOneWidget);
    final dialog=tester.widget<Dialog>(fullscreen);
    expect(dialog.backgroundColor,p.surface);
    final icon=find.byIcon(Icons.collections_outlined);
    expect(icon,findsOneWidget);
    expect(tester.widget<Icon>(icon).color,p.accentOnSurface);
    final next=find.byTooltip('Siguiente');
    expect(next,findsOneWidget);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.text('Fotografía del lugar 2'),findsOneWidget);
  });
}
