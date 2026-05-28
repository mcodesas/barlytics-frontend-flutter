import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
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
    return Container(
      decoration: BoxDecoration(gradient: palette.mainGradient),
      child: Stack(
        children: [
          Positioned(top: -120, right: -90, child: GlowCircle(size: 340, opacity: 0.24, color: palette.accent)),
          Positioned(bottom: -140, left: -110, child: GlowCircle(size: 380, opacity: 0.18, color: palette.secondary)),
          Positioned(top: 120, left: -80, child: GlowCircle(size: 210, opacity: 0.14, color: palette.primary)),
          Positioned(bottom: 90, right: -60, child: GlowCircle(size: 190, opacity: 0.10, color: palette.accent)),
          if (showPattern) Positioned.fill(child: _AnalyticsPattern(palette: palette)),
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
            colors: [(color ?? AppColors.accent).withOpacity(opacity), Colors.transparent],
          ),
        ),
      );
}

class _AnalyticsPattern extends StatelessWidget {
  const _AnalyticsPattern({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: CustomPaint(painter: _AnalyticsPatternPainter(palette)),
      );
}

class _AnalyticsPatternPainter extends CustomPainter {
  const _AnalyticsPatternPainter(this.palette);

  final AppPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final neutralPattern = palette.darkBackground ? Colors.white : palette.textPrimary;
    final dotPaint = Paint()..color = neutralPattern.withOpacity(palette.darkBackground ? 0.052 : 0.040);
    for (double x = 26; x < size.width; x += 28) {
      for (double y = 28; y < size.height; y += 28) {
        canvas.drawCircle(Offset(x, y), 1.05 + ((x + y) % 3) * 0.18, dotPaint);
      }
    }

    final barPaint = Paint()..color = palette.secondary.withOpacity(0.13);
    final baseY = size.height * 0.24;
    for (int i = 0; i < 14; i++) {
      final height = 28.0 + (i % 5) * 13.0 + i * 1.5;
      final left = size.width - 420 + i * 24.0;
      if (left < 0 || left > size.width) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(left, baseY - height, 12, height), const Radius.circular(8)),
        barPaint,
      );
    }

    final linePaint = Paint()
      ..color = palette.accent.withOpacity(0.18)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(size.width - 430, baseY - 20)
      ..cubicTo(size.width - 330, baseY - 98, size.width - 260, baseY + 24, size.width - 180, baseY - 54)
      ..cubicTo(size.width - 120, baseY - 116, size.width - 70, baseY - 92, size.width - 24, baseY - 152);
    canvas.drawPath(path, linePaint);

    final circuitPaint = Paint()
      ..color = neutralPattern.withOpacity(palette.darkBackground ? 0.070 : 0.052)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (double x = 52; x < size.width; x += 132) {
      final y = 72.0 + (x % 240);
      final path = Path()
        ..moveTo(x, y)
        ..lineTo(x + 38, y)
        ..lineTo(x + 38, y + 26)
        ..lineTo(x + 86, y + 26)
        ..lineTo(x + 86, y + 54);
      canvas.drawPath(path, circuitPaint);
      canvas.drawCircle(Offset(x + 90, y + 54), 3, Paint()..color = palette.accent.withOpacity(0.15));
      canvas.drawCircle(Offset(x + 38, y), 2.2, Paint()..color = palette.secondary.withOpacity(0.12));
    }

    final hexPaint = Paint()
      ..color = palette.accent.withOpacity(palette.darkBackground ? 0.075 : 0.055)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;
    for (double x = 40; x < size.width; x += 180) {
      for (double y = 80; y < size.height; y += 220) {
        _drawHexagon(canvas, Offset(x + (y % 120), y), 18, hexPaint);
      }
    }

    final iconPaint = Paint()..color = neutralPattern.withOpacity(palette.darkBackground ? 0.090 : 0.065);
    final icons = <IconData>[
      Icons.local_bar_rounded,
      Icons.point_of_sale_rounded,
      Icons.qr_code_2_rounded,
      Icons.analytics_rounded,
      Icons.wifi_tethering_rounded,
      Icons.memory_rounded,
      Icons.hub_rounded,
      Icons.grid_view_rounded,
      Icons.sports_bar_rounded,
      Icons.terminal_rounded,
      Icons.table_bar_rounded,
      Icons.inventory_2_rounded,
      Icons.cloud_queue_rounded,
      Icons.schema_rounded,
      Icons.data_object_rounded,
      Icons.bar_chart_rounded,
    ];
    final safeIconWidth = size.width.clamp(180.0, 1400.0);
    for (int i = 0; i < icons.length; i++) {
      final builder = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.center, fontSize: 21 + (i % 4) * 3))
        ..pushStyle(TextStyle(color: iconPaint.color, fontFamily: icons[i].fontFamily, package: icons[i].fontPackage).getTextStyle())
        ..addText(String.fromCharCode(icons[i].codePoint));
      final paragraph = builder.build()..layout(const ui.ParagraphConstraints(width: 42));
      final dx = 28.0 + ((i * 104.0) % safeIconWidth);
      final dy = 68.0 + ((i * 73.0) % (size.height + 120)) - 60;
      canvas.drawParagraph(paragraph, Offset(dx, dy));
    }

    _drawNeuralMesh(canvas, size, neutralPattern);
    _drawMicroChips(canvas, size, neutralPattern);
    _drawWaveSignals(canvas, size);
  }

  void _drawNeuralMesh(Canvas canvas, Size size, Color neutralPattern) {
    final nodes = <Offset>[];
    for (double x = 64; x < size.width; x += 170) {
      for (double y = 120; y < size.height; y += 190) {
        nodes.add(Offset(x + ((y / 19) % 46), y + ((x / 23) % 42)));
      }
    }
    final nodePaint = Paint()..color = palette.accent.withOpacity(palette.darkBackground ? 0.13 : 0.08);
    final edgePaint = Paint()
      ..color = neutralPattern.withOpacity(palette.darkBackground ? 0.045 : 0.032)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < nodes.length; i++) {
      canvas.drawCircle(nodes[i], 3.2 + (i % 3), nodePaint);
      if (i + 1 < nodes.length && (i % 2 == 0)) canvas.drawLine(nodes[i], nodes[i + 1], edgePaint);
      if (i + 3 < nodes.length && (i % 4 == 0)) canvas.drawLine(nodes[i], nodes[i + 3], edgePaint);
    }
  }

  void _drawMicroChips(Canvas canvas, Size size, Color neutralPattern) {
    final chipPaint = Paint()
      ..color = palette.secondary.withOpacity(palette.darkBackground ? 0.080 : 0.052)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (double x = 110; x < size.width; x += 260) {
      for (double y = 170; y < size.height; y += 260) {
        final rect = RRect.fromRectAndRadius(Rect.fromLTWH(x, y, 34, 28), const Radius.circular(6));
        canvas.drawRRect(rect, chipPaint);
        for (int i = 0; i < 4; i++) {
          canvas.drawLine(Offset(x - 8, y + 6 + i * 5), Offset(x, y + 6 + i * 5), chipPaint);
          canvas.drawLine(Offset(x + 34, y + 6 + i * 5), Offset(x + 42, y + 6 + i * 5), chipPaint);
        }
      }
    }
  }

  void _drawWaveSignals(Canvas canvas, Size size) {
    final wavePaint = Paint()
      ..color = palette.accent.withOpacity(palette.darkBackground ? 0.09 : 0.055)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (int j = 0; j < 4; j++) {
      final y = size.height * (0.18 + j * 0.20);
      final wave = Path()..moveTo(-20, y);
      for (double x = 0; x <= size.width + 40; x += 80) {
        wave.quadraticBezierTo(x + 40, y - 18 + j * 5, x + 80, y);
      }
      canvas.drawPath(wave, wavePaint);
    }
  }

  void _drawHexagon(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = 1.0471975512 * i;
      final point = Offset(center.dx + radius * math.cos(angle), center.dy + radius * math.sin(angle));
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _AnalyticsPatternPainter oldDelegate) => oldDelegate.palette != palette;
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
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(dark || palette.darkBackground ? 0.13 : 0.28),
            palette.accent.withOpacity(dark || palette.darkBackground ? 0.08 : 0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: outerRadius,
        border: Border.all(color: palette.glassBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(palette.darkBackground ? 0.34 : 0.18),
            blurRadius: 38,
            offset: const Offset(0, 24),
          ),
          BoxShadow(
            color: palette.accent.withOpacity(0.14),
            blurRadius: 46,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          gradient: palette.glassGradient,
          borderRadius: innerRadius,
          border: Border.all(color: palette.translucentBorder),
        ),
        child: child,
      ),
    );

    if (maxWidth == null) return panel;
    return ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth!), child: panel);
  }
}

class TechBrandMark extends ConsumerWidget {
  const TechBrandMark({super.key, this.size = 58, this.icon = Icons.analytics_rounded});

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
        gradient: palette.mainGradient,
        boxShadow: [
          BoxShadow(color: palette.accent.withOpacity(0.28), blurRadius: 22, offset: const Offset(0, 8)),
        ],
      ),
      child: Icon(icon, color: palette.onTitle, size: size * 0.52),
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
                        color: dark ? palette.onTitle : palette.textPrimary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: dark ? palette.onTitle.withOpacity(0.78) : palette.textSecondary,
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
          Positioned(top: -120, right: -110, child: GlowCircle(size: 340, opacity: palette.darkBackground ? 0.20 : 0.12, color: palette.accent)),
          Positioned(bottom: -150, left: -120, child: GlowCircle(size: 390, opacity: palette.darkBackground ? 0.18 : 0.10, color: palette.secondary)),
          Positioned(top: 190, left: -90, child: GlowCircle(size: 220, opacity: palette.darkBackground ? 0.10 : 0.06, color: palette.primary)),
          Positioned(bottom: 130, right: -80, child: GlowCircle(size: 220, opacity: palette.darkBackground ? 0.12 : 0.07, color: palette.accent)),
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
    final baseOpacity = palette.darkBackground ? 0.12 : 0.06;
    final dotPaint = Paint()..color = palette.secondary.withOpacity(baseOpacity);
    for (double x = 24; x < size.width; x += 38) {
      for (double y = 24; y < size.height; y += 38) {
        canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
      }
    }

    final linePaint = Paint()
      ..color = palette.accent.withOpacity(palette.darkBackground ? 0.14 : 0.08)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    for (double y = 90; y < size.height; y += 150) {
      final path = Path()
        ..moveTo(-20, y)
        ..cubicTo(size.width * 0.25, y - 40, size.width * 0.55, y + 54, size.width + 20, y - 10);
      canvas.drawPath(path, linePaint);
    }

    final circuitPaint = Paint()
      ..color = palette.secondary.withOpacity(palette.darkBackground ? 0.10 : 0.055)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (double x = 42; x < size.width; x += 170) {
      for (double y = 58; y < size.height; y += 210) {
        final path = Path()
          ..moveTo(x, y)
          ..lineTo(x + 34, y)
          ..lineTo(x + 34, y + 34)
          ..lineTo(x + 82, y + 34);
        canvas.drawPath(path, circuitPaint);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + 86, y + 26, 18, 18), const Radius.circular(5)), circuitPaint);
      }
    }

    final hexPaint = Paint()
      ..color = palette.accent.withOpacity(palette.darkBackground ? 0.070 : 0.045)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    for (double x = 36; x < size.width; x += 190) {
      for (double y = 74; y < size.height; y += 240) {
        _drawHexagon(canvas, Offset(x + (y % 90), y), 14, hexPaint);
      }
    }

    final icons = <IconData>[
      Icons.local_bar_rounded,
      Icons.point_of_sale_rounded,
      Icons.qr_code_2_rounded,
      Icons.inventory_2_rounded,
      Icons.analytics_rounded,
      Icons.table_bar_rounded,
      Icons.memory_rounded,
      Icons.router_rounded,
      Icons.hub_rounded,
      Icons.data_object_rounded,
      Icons.terminal_rounded,
      Icons.grid_view_rounded,
      Icons.cloud_sync_rounded,
      Icons.data_thresholding_rounded,
      Icons.schema_rounded,
      Icons.device_hub_rounded,
      Icons.receipt_long_rounded,
      Icons.payments_rounded,
      Icons.settings_input_component_rounded,
    ];
    final iconColor = palette.textSecondary.withOpacity(palette.darkBackground ? 0.12 : 0.08);
    for (int i = 0; i < icons.length; i++) {
      final builder = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.center, fontSize: 28))
        ..pushStyle(TextStyle(color: iconColor, fontFamily: icons[i].fontFamily, package: icons[i].fontPackage).getTextStyle())
        ..addText(String.fromCharCode(icons[i].codePoint));
      final paragraph = builder.build()..layout(const ui.ParagraphConstraints(width: 40));
      final dx = (i * 148.0 + 48) % (size.width + 40);
      final dy = 86.0 + (i % 6) * 112.0;
      canvas.drawParagraph(paragraph, Offset(dx, dy));
    }
  }

  void _drawHexagon(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = math.pi / 3 * i;
      final point = Offset(center.dx + radius * math.cos(angle), center.dy + radius * math.sin(angle));
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PagePatternPainter oldDelegate) => oldDelegate.palette != palette;
}
