import 'package:flutter/material.dart';

/// Paletas completas para la carta pública (web, móvil y vista previa).
/// Los colores son HEX #RRGGBB para mantener el contrato con el backend.
class MenuDigitalPalettePreset {
  const MenuDigitalPalettePreset(
    this.name, this.primary, this.background, this.text, this.card,
  );

  final String name;
  final String primary;
  final String background;
  final String text;
  final String card;
}

/// Combinaciones verificadas con contraste WCAG AA >= 4.5:1 entre
/// texto/fondo y texto/tarjeta. Siempre pueden ajustarse manualmente.
const menuDigitalPalettePresets = <MenuDigitalPalettePreset>[
  MenuDigitalPalettePreset('Océano', '#20C8C4', '#081B27', '#F8FAFC', '#112D3B'),
  MenuDigitalPalettePreset('Marfil', '#9B6B3F', '#FFF9EE', '#352819', '#F2E7D5'),
  MenuDigitalPalettePreset('Vino', '#E5B46B', '#29111D', '#FFF7ED', '#431E30'),
  MenuDigitalPalettePreset('Bosque', '#D6B979', '#10251D', '#F7F4E9', '#1C382D'),
  MenuDigitalPalettePreset('Lavanda', '#7451BB', '#F8F4FF', '#291F3E', '#EAE0F7'),
  MenuDigitalPalettePreset('Terracota', '#F8A875', '#291C1B', '#FFF4E9', '#45302B'),
  MenuDigitalPalettePreset('Café de autor', '#A97648', '#FAF4EA', '#342519', '#EFE3D3'),
  MenuDigitalPalettePreset('Champaña', '#A87C3D', '#FFF9EF', '#302418', '#F2E5CB'),
  MenuDigitalPalettePreset('Medianoche', '#74B7E8', '#0E1728', '#F7FAFF', '#1D2D46'),
  MenuDigitalPalettePreset('Jade', '#66D2AE', '#072C27', '#EDFFF8', '#15463C'),
  MenuDigitalPalettePreset('Rubí', '#F3A9BB', '#290E1B', '#FFF5F7', '#4A1E30'),
  MenuDigitalPalettePreset('Rosa viejo', '#A34D69', '#FFF3F4', '#44242E', '#F7E1E8'),
  MenuDigitalPalettePreset('Carbón dorado', '#ECC27C', '#171616', '#FCF4E7', '#302C27'),
  MenuDigitalPalettePreset('Sahara', '#BA753A', '#FFF7E9', '#3B291A', '#F1E2C6'),
  MenuDigitalPalettePreset('Azul hielo', '#226B95', '#F3FAFF', '#1A3144', '#DAECF7'),
  MenuDigitalPalettePreset('Menta fresca', '#278A73', '#F1FFFA', '#143B33', '#DDF4EA'),
  MenuDigitalPalettePreset('Pistacho', '#6A802E', '#FCFDF0', '#304020', '#EEF2D5'),
  MenuDigitalPalettePreset('Cobre', '#ED9A6B', '#241912', '#FFF2E8', '#3D2920'),
  MenuDigitalPalettePreset('Petróleo', '#67C4D6', '#0C2430', '#F6FBFC', '#173B48'),
  MenuDigitalPalettePreset('Mora', '#D0A6E8', '#23162E', '#F7F1FF', '#382247'),
  MenuDigitalPalettePreset('Coral', '#C05844', '#FFF4EC', '#442820', '#F8E2D6'),
  MenuDigitalPalettePreset('Oliva', '#CBD58C', '#242B19', '#F6F8EB', '#39442B'),
  MenuDigitalPalettePreset('Cielo', '#3878D0', '#F7FAFF', '#243252', '#E5EFFB'),
  MenuDigitalPalettePreset('Atardecer', '#FFB277', '#382023', '#FFF5EA', '#59343A'),
  MenuDigitalPalettePreset('Perla', '#7D658E', '#FFFDFB', '#393044', '#EEE6EF'),
  MenuDigitalPalettePreset('Turquesa', '#1C7F89', '#F0FCFC', '#133B3D', '#DDF3F1'),
  MenuDigitalPalettePreset('Noir', '#D5C5AD', '#14161B', '#FBF8F3', '#2A2D33'),
  MenuDigitalPalettePreset('Cereza', '#BA406B', '#FFF5F7', '#4D2437', '#F8E4EC'),
  MenuDigitalPalettePreset('Tierra', '#DAB18E', '#31251D', '#FFF8EF', '#4C3B30'),
  MenuDigitalPalettePreset('Cacao', '#BD906B', '#231B16', '#FCF5EC', '#403027'),
  MenuDigitalPalettePreset('Brisa', '#4B83A5', '#F2FAFF', '#263E51', '#E2EEF6'),
  MenuDigitalPalettePreset('Noche azul', '#88BAF1', '#10162A', '#F6FAFF', '#243452'),
];

/// Fuente única de colores para catálogo, botones para compartir y editor.
class MenuDigitalColors {
  const MenuDigitalColors({
    required this.accent,
    required this.canvas,
    required this.text,
    required this.card,
  });

  factory MenuDigitalColors.fromMenu(Map<String, dynamic> menu) =>
      MenuDigitalColors(
        accent: parse(menu['primario'], '#20C8C4'),
        canvas: parse(menu['fondo'], '#081B27'),
        text: parse(menu['texto'], '#F8FAFC'),
        card: parse(menu['tarjeta'], '#112D3B'),
      );

  final Color accent;
  final Color canvas;
  final Color text;
  final Color card;

  static Color parse(dynamic value, String fallback) {
    final hex = (value ?? fallback).toString().trim().replaceFirst('#', '');
    final safe = RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(hex)
        ? hex : fallback.replaceFirst('#', '');
    return Color(0xFF000000 | int.parse(safe, radix: 16));
  }

  static double contrast(Color a, Color b) {
    final hi = a.computeLuminance() > b.computeLuminance()
        ? a.computeLuminance() : b.computeLuminance();
    final lo = a.computeLuminance() < b.computeLuminance()
        ? a.computeLuminance() : b.computeLuminance();
    return (hi + .05) / (lo + .05);
  }

  static Color readableOn(Color background) =>
      contrast(Colors.white, background) >= contrast(Colors.black, background)
          ? Colors.white : Colors.black;

  Color get onAccent => readableOn(accent);
  Color get border => Color.lerp(card, text, .19)!;
  Color get mutedText => Color.lerp(text, card, .22)!;
  Color get secondarySurface => Color.lerp(card, canvas, .28)!;
}
