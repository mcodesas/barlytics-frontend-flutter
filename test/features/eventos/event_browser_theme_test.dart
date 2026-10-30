import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/eventos/presentation/widgets/event_browser_theme.dart';
import 'package:barlytics_frontend/features/eventos/presentation/widgets/event_visual_kit.dart';

void main(){
  test('Color del navegador usa el fondo seleccionado, no el azul corporativo',(){
    final champagne=EventPagePalette.fromHex(
      '#AC8246','#F3E7D3','#2A211C');
    expect(eventBrowserThemeHex(champagne.canvas),'#F3E7D3');
    final wine=EventPagePalette.fromHex(
      '#8A3D52','#F6EBDD','#2A1E1F');
    expect(eventBrowserThemeHex(wine.canvas),'#F6EBDD');
    final turquoise=EventPagePalette.fromHex(
      '#35D0C5','#102735','#F2FBFF');
    expect(eventBrowserThemeHex(turquoise.canvas),'#102735');
  });

  testWidgets('Al cambiar la paleta se actualiza el scope y se desmonta sin error',
    (tester)async{
    await tester.pumpWidget(MaterialApp(home:EventBrowserThemeScope(
      background:const Color(0xFFF3E7D3),
      child:Scaffold(body:Text('Evento')),
    )));
    expect(find.text('Evento'),findsOneWidget);
    await tester.pumpWidget(MaterialApp(home:EventBrowserThemeScope(
      background:const Color(0xFF102735),
      child:Scaffold(body:Text('Evento actualizado')),
    )));
    expect(find.text('Evento actualizado'),findsOneWidget);
    await tester.pumpWidget(const MaterialApp(home:Scaffold()));
    expect(tester.takeException(),isNull);
  });
}
