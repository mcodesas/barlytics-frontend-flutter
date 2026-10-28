import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main(){
  test('Los cinco accesos al visor entregan la paleta del evento',(){
    final src=File('lib/features/eventos/presentation/widgets/'
      'event_public_landing.dart').readAsStringSync();
    const call='showEventPhotoViewer(context,eventPalette:palette,';
    expect(call.allMatches(src).length,5);
  });

  test('El visor de fotografías no usa colores fijos de administración',(){
    final src=File('lib/features/eventos/presentation/widgets/'
      'event_photo_viewer.dart').readAsStringSync();
    expect(src.contains('EventColors.'),isFalse);
    expect(src.contains('Color(0xFF03141D)'),isFalse);
    expect(src.contains('eventPalette ?? EventPagePalette.of(context)'),isTrue);
    expect(src.contains('final iconColor=p.accentOnSurface'),isTrue);
    expect(src.contains('foregroundColor:p.accentOnSoft'),isTrue);
  });

  test('Compartir y entradas usan colores del evento',(){
    final share=File('lib/features/eventos/presentation/widgets/'
      'event_share_sheet.dart').readAsStringSync();
    final entry=File('lib/features/eventos/presentation/'
      'evento_publico_page.dart').readAsStringSync();
    expect(share.contains('colors.onSurface'),isTrue);
    expect(share.contains('palette:p'),isTrue);
    expect(entry.contains('final foreground=palette.onSurface;'),isTrue);
    expect(entry.contains('palette.accentOnSurface'),isTrue);
  });
}
