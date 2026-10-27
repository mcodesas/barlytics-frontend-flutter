import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/eventos/presentation/widgets/event_visual_kit.dart';

void main() {
  test('Las paletas son completas, legibles y distintas', () {
    expect(eventPalettePresets.length, greaterThanOrEqualTo(20));
    expect(eventPalettePresets.map((p) => p.name).toSet().length,
        eventPalettePresets.length);
    for (final p in eventPalettePresets) {
      final theme = EventPagePalette.fromHex(p.accent, p.background, p.text);
      expect(theme.canvas, EventPagePalette.parse(p.background, Colors.black));
      expect(theme.text, EventPagePalette.parse(p.text, Colors.white));
      expect(EventPagePalette.contrast(theme.text, theme.canvas),
          greaterThanOrEqualTo(4.5), reason: p.name);
      expect(theme.menuPaper, isNot(Colors.transparent));
    }
  });

  test('El fondo no queda forzado a azul por un color fijo', () {
    final light = EventPagePalette.fromHex(
        '#B66B4F', '#F3E1D5', '#342721');
    final night = EventPagePalette.fromHex(
        '#E39A67', '#1E1614', '#F4E7D8');
    expect(light.canvas, const Color(0xFFF3E1D5));
    expect(night.canvas, const Color(0xFF1E1614));
    expect(light.surface, isNot(night.surface));
    expect(light.menuPaper, isNot(night.menuPaper));
  });

  test('La carta hereda la tipografía y el color del evento', () {
    final palette = EventPagePalette.fromHex(
        '#D6A85F', '#EFE4D4', '#30211B');
    expect(palette.menuInk, const Color(0xFF30211B));
    expect(EventPagePalette.contrast(palette.menuInk, palette.menuPaper),
        greaterThan(4.5));
  });
}
