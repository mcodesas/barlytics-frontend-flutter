import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_palette.dart';

/// Fondo tecnológico reutilizable para mantener una identidad visual unificada.
class TechBackground extends ConsumerWidget {
  const TechBackground({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.showPattern = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool showPattern;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final backgroundGradient = RadialGradient(
      center: const Alignment(-0.55, -0.85),
      radius: 1.45,
      colors: palette.darkBackground
          ? [
              Color.lerp(const Color(0xFF155B66), palette.primary, 0.22)!,
              Color.lerp(const Color(0xFF082B3A), palette.secondary, 0.10)!,
              Color.lerp(const Color(0xFF061723), palette.primary, 0.05)!,
            ]
          : [
              Color.lerp(const Color(0xFFE7F8F5), palette.primary, 0.10)!,
              const Color(0xFFF4F8FB),
              Color.lerp(Colors.white, palette.secondary, 0.05)!,
            ],
    );

    return Container(
      decoration: BoxDecoration(gradient: backgroundGradient),
      child: Stack(
        children: [
          Positioned(
            top: -95,
            right: -70,
            child: GlowCircle(
              size: 270,
              opacity: palette.darkBackground ? 0.24 : 0.13,
              color: palette.primary,
            ),
          ),
          Positioned(
            bottom: -130,
            left: -85,
            child: GlowCircle(
              size: 320,
              opacity: palette.darkBackground ? 0.18 : 0.10,
              color: palette.secondary,
            ),
          ),
          Positioned(
            top: 130,
            left: -65,
            child: GlowCircle(
              size: 190,
              opacity: palette.darkBackground ? 0.14 : 0.10,
              color: palette.primary,
            ),
          ),
          if (showPattern) Positioned.fill(child: _BarMoodPattern(palette: palette)),
          SafeArea(child: Padding(padding: padding, child: child)),
        ],
      ),
    );
  }
}

class GlowCircle extends StatelessWidget {
  const GlowCircle({super.key, required this.size, this.opacity = 0.16, this.color});

  final double size;
  final double opacity;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [(color ?? const Color(0xFF38BDF8)).withOpacity(opacity), Colors.transparent],
          ),
        ),
      );
}

class _BarMoodPattern extends StatelessWidget {
  const _BarMoodPattern({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: CustomPaint(painter: _BarMoodPatternPainter(palette)),
      );
}

class _BarMoodPatternPainter extends CustomPainter {
  const _BarMoodPatternPainter(this.palette);

  final AppPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()..color = Colors.white.withOpacity(0.04);
    for (double x = 36; x < size.width; x += 34) {
      for (double y = 38; y < size.height; y += 34) {
        canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
      }
    }

    final guidePaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1.15
      ..style = PaintingStyle.stroke;
    for (double x = 54; x < size.width; x += 186) {
      final y = 86.0 + (x % 180);
      final path = Path()
        ..moveTo(x, y)
        ..lineTo(x + 68, y)
        ..lineTo(x + 108, y + 34)
        ..lineTo(x + 158, y + 34);
      canvas.drawPath(path, guidePaint);
      canvas.drawCircle(Offset(x + 164, y + 34), 3, Paint()..color = palette.secondary.withOpacity(0.15));
    }

    _drawBackBar(canvas, size);
    _drawServiceFlow(canvas, size);
    _drawCounterArc(canvas, size);
    _drawBottomIconRow(canvas, size);
  }

  void _drawBackBar(Canvas canvas, Size size) {
    final shelfPaint = Paint()..color = palette.secondary.withOpacity(0.10);
    final shelfTop = size.height * 0.22;
    final shelfLeft = size.width * 0.66;
    final shelfWidth = size.width * 0.22;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(shelfLeft, shelfTop, shelfWidth, 5), const Radius.circular(4)),
      shelfPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(shelfLeft + 32, shelfTop + 58, shelfWidth - 32, 5), const Radius.circular(4)),
      shelfPaint,
    );

    _drawBottle(canvas, Offset(shelfLeft + 16, shelfTop - 18), 0.92);
    _drawBottle(canvas, Offset(shelfLeft + 80, shelfTop - 14), 0.78);
    _drawBottle(canvas, Offset(shelfLeft + 56, shelfTop + 40), 0.84);
    _drawBottle(canvas, Offset(shelfLeft + 126, shelfTop + 34), 0.74);
  }

  void _drawServiceFlow(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = palette.secondary.withOpacity(0.17)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(size.width * 0.18, size.height * 0.78)
      ..lineTo(size.width * 0.28, size.height * 0.78)
      ..lineTo(size.width * 0.36, size.height * 0.70)
      ..lineTo(size.width * 0.50, size.height * 0.70)
      ..lineTo(size.width * 0.58, size.height * 0.61)
      ..lineTo(size.width * 0.75, size.height * 0.61)
      ..lineTo(size.width * 0.84, size.height * 0.69)
      ..lineTo(size.width * 0.93, size.height * 0.69);
    canvas.drawPath(path, linePaint);

    final nodePaint = Paint()..color = palette.secondary.withOpacity(0.20);
    for (final point in <Offset>[
      Offset(size.width * 0.18, size.height * 0.78),
      Offset(size.width * 0.36, size.height * 0.70),
      Offset(size.width * 0.58, size.height * 0.61),
      Offset(size.width * 0.84, size.height * 0.69),
    ]) {
      canvas.drawCircle(point, 4.2, nodePaint);
    }

    _drawGlass(canvas, Offset(size.width * 0.14, size.height * 0.71), 0.94);
    _drawBeer(canvas, Offset(size.width * 0.31, size.height * 0.63), 0.84);
    _drawCocktail(canvas, Offset(size.width * 0.54, size.height * 0.54), 0.88);
  }

  void _drawCounterArc(Canvas canvas, Size size) {
    final counterPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;
    final arcRect = Rect.fromLTWH(size.width * 0.03, size.height * 0.76, size.width * 0.26, size.height * 0.18);
    canvas.drawArc(arcRect, 0.2, 2.6, false, counterPaint);
  }

  void _drawBottomIconRow(Canvas canvas, Size size) {
    final iconColor = Colors.white.withOpacity(0.07);
    final items = <(IconData, double)>[
      (Icons.table_restaurant_rounded, 0.18),
      (Icons.receipt_long_rounded, 0.34),
      (Icons.point_of_sale_rounded, 0.52),
      (Icons.inventory_2_rounded, 0.70),
      (Icons.insights_rounded, 0.86),
    ];

    for (final item in items) {
      final builder = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.center, fontSize: 24))
        ..pushStyle(TextStyle(color: iconColor, fontFamily: item.$1.fontFamily, package: item.$1.fontPackage).getTextStyle())
        ..addText(String.fromCharCode(item.$1.codePoint));
      final paragraph = builder.build()..layout(const ui.ParagraphConstraints(width: 40));
      canvas.drawParagraph(paragraph, Offset(size.width * item.$2 - 20, size.height - 78));
    }
  }

  void _drawBottle(Canvas canvas, Offset origin, double scale) {
    final outline = Paint()
      ..color = palette.secondary.withOpacity(0.18)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final glow = Paint()..color = palette.secondary.withOpacity(0.12);

    final body = Rect.fromLTWH(origin.dx, origin.dy, 24 * scale, 64 * scale);
    canvas.drawRRect(RRect.fromRectAndRadius(body, Radius.circular(9 * scale)), outline);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(origin.dx + 7 * scale, origin.dy - 14 * scale, 10 * scale, 18 * scale), Radius.circular(4 * scale)),
      outline,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(origin.dx + 4 * scale, origin.dy + 22 * scale, 16 * scale, 16 * scale), Radius.circular(5 * scale)),
      glow,
    );
  }

  void _drawGlass(Canvas canvas, Offset origin, double scale) {
    final outline = Paint()
      ..color = palette.secondary.withOpacity(0.16)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(origin.dx, origin.dy)
      ..lineTo(origin.dx + 34 * scale, origin.dy)
      ..lineTo(origin.dx + 24 * scale, origin.dy + 30 * scale)
      ..lineTo(origin.dx + 10 * scale, origin.dy + 30 * scale)
      ..close();
    canvas.drawPath(path, outline);
    canvas.drawLine(Offset(origin.dx + 17 * scale, origin.dy + 30 * scale), Offset(origin.dx + 17 * scale, origin.dy + 50 * scale), outline);
    canvas.drawLine(Offset(origin.dx + 4 * scale, origin.dy + 50 * scale), Offset(origin.dx + 30 * scale, origin.dy + 50 * scale), outline);
    canvas.drawCircle(Offset(origin.dx + 28 * scale, origin.dy + 6 * scale), 2.4 * scale, Paint()..color = palette.secondary.withOpacity(0.18));
  }

  void _drawCocktail(Canvas canvas, Offset origin, double scale) {
    final outline = Paint()
      ..color = palette.secondary.withOpacity(0.16)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final liquid = Paint()..color = palette.secondary.withOpacity(0.10);
    final bowl = Path()
      ..moveTo(origin.dx, origin.dy)
      ..lineTo(origin.dx + 30 * scale, origin.dy)
      ..lineTo(origin.dx + 16 * scale, origin.dy + 20 * scale)
      ..close();
    canvas.drawPath(bowl, outline);
    canvas.drawPath(bowl, liquid);
    canvas.drawLine(Offset(origin.dx + 15 * scale, origin.dy + 20 * scale), Offset(origin.dx + 15 * scale, origin.dy + 43 * scale), outline);
    canvas.drawLine(Offset(origin.dx + 3 * scale, origin.dy + 43 * scale), Offset(origin.dx + 27 * scale, origin.dy + 43 * scale), outline);
    canvas.drawLine(Offset(origin.dx + 21 * scale, origin.dy - 10 * scale), Offset(origin.dx + 34 * scale, origin.dy + 4 * scale), outline);
    canvas.drawCircle(Offset(origin.dx + 35 * scale, origin.dy + 5 * scale), 3.2 * scale, outline);
  }

  void _drawBeer(Canvas canvas, Offset origin, double scale) {
    final outline = Paint()
      ..color = palette.secondary.withOpacity(0.16)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    final foam = Paint()..color = Colors.white.withOpacity(0.10);
    final mug = RRect.fromRectAndRadius(Rect.fromLTWH(origin.dx, origin.dy + 8 * scale, 28 * scale, 34 * scale), Radius.circular(8 * scale));
    canvas.drawRRect(mug, outline);
    final handleRect = Rect.fromLTWH(origin.dx + 21 * scale, origin.dy + 12 * scale, 18 * scale, 22 * scale);
    canvas.drawArc(handleRect, -1.1, 2.3, false, outline);
    canvas.drawCircle(Offset(origin.dx + 8 * scale, origin.dy + 8 * scale), 6 * scale, foam);
    canvas.drawCircle(Offset(origin.dx + 15 * scale, origin.dy + 4 * scale), 7 * scale, foam);
    canvas.drawCircle(Offset(origin.dx + 22 * scale, origin.dy + 8 * scale), 6 * scale, foam);
  }

  @override
  bool shouldRepaint(covariant _BarMoodPatternPainter oldDelegate) => oldDelegate.palette.id != palette.id;
}

/// Tarjeta tipo glass con borde transparente, inspirada en el diseño del login.
///
/// Mantiene el estilo tecnológico, pero recupera el borde translúcido que hacía
/// que el formulario se viera más liviano sobre el fondo oscuro.
class TechGlassPanel extends ConsumerWidget {
  const TechGlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(26),
    this.maxWidth,
    this.dark = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? maxWidth;
  final bool dark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final outerRadius = BorderRadius.circular(36);
    final innerRadius = BorderRadius.circular(28);

    final panel = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(dark || palette.darkBackground ? 0.11 : 0.16),
        borderRadius: outerRadius,
        border: Border.all(color: Colors.white.withOpacity(0.26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(palette.darkBackground ? 0.34 : 0.18),
            blurRadius: 38,
            offset: const Offset(0, 24),
          ),
          BoxShadow(
            color: palette.secondary.withOpacity(0.14),
            blurRadius: 46,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: dark || palette.darkBackground ? palette.surface.withOpacity(0.88) : Colors.white.withOpacity(0.94),
          borderRadius: innerRadius,
          border: Border.all(
            color: dark || palette.darkBackground ? Colors.white.withOpacity(0.12) : palette.cardBorder,
          ),
        ),
        child: child,
      ),
    );

    if (maxWidth == null) return panel;
    return ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth!), child: panel);
  }
}

class TechBrandMark extends ConsumerWidget {
  const TechBrandMark({super.key, this.size = 58, this.icon = Icons.local_bar_rounded});

  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [palette.primary, palette.secondary]),
        boxShadow: [
          BoxShadow(color: palette.secondary.withOpacity(0.28), blurRadius: 22, offset: const Offset(0, 8)),
        ],
      ),
      child: Icon(icon, color: palette.onPrimary, size: size * 0.52),
    );
  }
}

class TechSectionTitle extends ConsumerWidget {
  const TechSectionTitle({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.local_bar_rounded,
    this.dark = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool dark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Row(
        children: [
          TechBrandMark(icon: icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: dark ? Colors.white : palette.textPrimary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: dark ? Colors.white70 : palette.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
  }
}



/// Título glass reutilizable para cabeceras de módulos y pantallas internas.
class TechGlassTitlePanel extends ConsumerWidget {
  const TechGlassTitlePanel({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.local_bar_rounded,
    this.trailing,
    this.padding = const EdgeInsets.all(22),
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(1.3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(31),
        gradient: LinearGradient(
          colors: [palette.secondary.withOpacity(0.95), palette.secondary.withOpacity(0.88), palette.primary.withOpacity(0.74)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: palette.secondary.withOpacity(0.24), blurRadius: 32, offset: const Offset(0, 16)),
          BoxShadow(color: palette.secondary.withOpacity(0.16), blurRadius: 46, offset: const Offset(0, 0)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: palette.darkBackground ? Colors.white.withOpacity(0.08) : palette.surface.withOpacity(0.84),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.22)),
            ),
            child: Row(
              children: [
                TechBrandMark(icon: icon, size: 54),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: palette.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 12),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fondo global de páginas: aplica la paleta seleccionada y deja una textura
/// suave para que el cuerpo de la aplicación no se vea completamente blanco.
class AppPageBackground extends ConsumerWidget {
  const AppPageBackground({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return DecoratedBox(
      decoration: BoxDecoration(gradient: palette.pageGradient),
      child: Stack(
        children: [
          Positioned(top: -120, right: -110, child: GlowCircle(size: 320, opacity: palette.darkBackground ? 0.18 : 0.10, color: palette.primary)),
          Positioned(bottom: -150, left: -120, child: GlowCircle(size: 360, opacity: palette.darkBackground ? 0.16 : 0.08, color: palette.secondary)),
          Positioned.fill(child: _PagePattern(palette: palette)),
        ],
      ),
    );
  }
}

class _PagePattern extends StatelessWidget {
  const _PagePattern({required this.palette});
  final AppPalette palette;

  @override
  Widget build(BuildContext context) => IgnorePointer(child: CustomPaint(painter: _PagePatternPainter(palette)));
}

class _PagePatternPainter extends CustomPainter {
  const _PagePatternPainter(this.palette);
  final AppPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = palette.secondary.withOpacity(palette.darkBackground ? 0.075 : 0.045);
    for (double x = 28; x < size.width; x += 42) {
      for (double y = 28; y < size.height; y += 42) {
        canvas.drawCircle(Offset(x, y), 1.05, dotPaint);
      }
    }

    final accentPaint = Paint()
      ..color = palette.secondary.withOpacity(palette.darkBackground ? 0.075 : 0.045)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;

    final motifs = <Offset>[
      Offset(size.width * 0.18, size.height * 0.24),
      Offset(size.width * 0.72, size.height * 0.30),
      Offset(size.width * 0.34, size.height * 0.72),
      Offset(size.width * 0.82, size.height * 0.76),
    ];

    for (final origin in motifs) {
      final path = Path()
        ..moveTo(origin.dx - 44, origin.dy)
        ..lineTo(origin.dx - 12, origin.dy)
        ..lineTo(origin.dx + 8, origin.dy + 18)
        ..lineTo(origin.dx + 44, origin.dy + 18);
      canvas.drawPath(path, accentPaint);
      canvas.drawCircle(Offset(origin.dx + 49, origin.dy + 18), 2.4, accentPaint);
    }

    final icons = <(IconData, double, double)>[
      (Icons.table_restaurant_rounded, 0.13, 0.80),
      (Icons.receipt_long_rounded, 0.36, 0.84),
      (Icons.point_of_sale_rounded, 0.58, 0.80),
      (Icons.inventory_2_rounded, 0.80, 0.84),
    ];

    for (final item in icons) {
      _drawGlyph(
        canvas,
        item.$1,
        Offset(size.width * item.$2 - 15, size.height * item.$3 - 15),
        24,
      );
    }
  }

  void _drawGlyph(Canvas canvas, IconData icon, Offset offset, double fontSize) {
    final color = palette.textSecondary.withOpacity(palette.darkBackground ? 0.075 : 0.055);
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(textAlign: TextAlign.center, fontSize: fontSize),
    )
      ..pushStyle(
        TextStyle(
          color: color,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
        ).getTextStyle(),
      )
      ..addText(String.fromCharCode(icon.codePoint));
    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: fontSize + 12));
    canvas.drawParagraph(paragraph, offset);
  }

@override
  bool shouldRepaint(covariant _PagePatternPainter oldDelegate) => oldDelegate.palette != palette;
}
