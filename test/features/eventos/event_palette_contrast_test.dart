import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/eventos/presentation/widgets/event_visual_kit.dart';

void expectReadable(EventPagePalette colors){
  expect(EventPagePalette.contrast(colors.onSurface,colors.surface),
      greaterThanOrEqualTo(4.48));
  expect(EventPagePalette.contrast(colors.onSurfaceSoft,colors.surfaceSoft),
      greaterThanOrEqualTo(4.48));
  expect(EventPagePalette.contrast(colors.muted,colors.surface),
      greaterThanOrEqualTo(4.48));
  expect(EventPagePalette.contrast(colors.accentOnSurface,colors.surface),
      greaterThanOrEqualTo(4.48));
  expect(EventPagePalette.contrast(colors.accentOnSoft,colors.surfaceSoft),
      greaterThanOrEqualTo(4.48));
  expect(EventPagePalette.contrast(colors.menuInk,colors.menuPaper),
      greaterThanOrEqualTo(4.48));
  expect(EventPagePalette.contrast(colors.heroInk,colors.heroShade),
      greaterThanOrEqualTo(4.48));
  expect(EventPagePalette.contrast(colors.onAccent,colors.accent),
      greaterThanOrEqualTo(4.48));
}

void main(){
  test('Todas las paletas prediseñadas conservan contraste legible',(){
    for(final preset in eventPalettePresets){
      final theme=EventPagePalette.fromHex(
        preset.accent,preset.background,preset.text);
      expectReadable(theme);
    }
  });

  test('Colores personalizados inválidos se ajustan sin alterar el fondo',(){
    const bg='#F6EEE1',card='#FFF9EC';
    final p=EventPagePalette.fromHex(
      '#F7DFB2',bg,'#FDFEFF',card,'#FFFFFF','#F7F2E9');
    expect(p.canvas,EventPagePalette.parse(bg,Colors.black));
    expect(p.surface,EventPagePalette.parse(card,Colors.black));
    expectReadable(p);
  });

  test('Tema oscuro con texto negro y acento oscuro sigue siendo legible',(){
    final p=EventPagePalette.fromHex(
      '#24212A','#171518','#101015','#211E25','#211E25','#171518');
    expectReadable(p);
  });

  test('Legibilidad de texto conserva el color seleccionado cuando es válido',(){
    const preferred=Color(0xFF121212),background=Color(0xFFFFFFFF);
    expect(EventPagePalette.readable(preferred,background),preferred);
  });
}
