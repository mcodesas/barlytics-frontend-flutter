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
          Positioned(top: -120, right: -90, child: GlowCircle(size: 320, opacity: 0.22, color: palette.accent)),
          Positioned(bottom: -140, left: -110, child: GlowCircle(size: 360, opacity: 0.16, color: palette.secondary)),
          Positioned(top: 140, left: -80, child: GlowCircle(size: 190, opacity: 0.12, color: palette.accent)),
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
    final dotPaint = Paint()..color = Colors.white.withOpacity(0.045);
    for (double x = 36; x < size.width; x += 34) {
      for (double y = 38; y < size.height; y += 34) {
        canvas.drawCircle(Offset(x, y), 1.3, dotPaint);
      }
    }

    final barPaint = Paint()..color = palette.secondary.withOpacity(0.11);
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
      ..color = Colors.white.withOpacity(0.055)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (double x = 64; x < size.width; x += 148) {
      final y = 86.0 + (x % 210);
      final path = Path()
        ..moveTo(x, y)
        ..lineTo(x + 46, y)
        ..lineTo(x + 46, y + 28)
        ..lineTo(x + 94, y + 28);
      canvas.drawPath(path, circuitPaint);
      canvas.drawCircle(Offset(x + 100, y + 28), 3, Paint()..color = palette.accent.withOpacity(0.12));
    }

    final iconPaint = Paint()..color = Colors.white.withOpacity(0.080);
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
    ];
    final safeIconWidth = size.width.clamp(160.0, 1200.0);
    for (int i = 0; i < icons.length; i++) {
      final builder = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.center, fontSize: 24 + (i % 3) * 3))
        ..pushStyle(TextStyle(color: iconPaint.color, fontFamily: icons[i].fontFamily, package: icons[i].fontPackage).getTextStyle())
        ..addText(String.fromCharCode(icons[i].codePoint));
      final paragraph = builder.build()..layout(const ui.ParagraphConstraints(width: 40));
      final dx = 36.0 + ((i * 118.0) % safeIconWidth);
      final dy = size.height - 96.0 - (i % 4) * 54.0;
      canvas.drawParagraph(paragraph, Offset(dx, dy));
    }
  }

  @override
  bool shouldRepaint(covariant _AnalyticsPatternPainter oldDelegate) => oldDelegate.palette.id != palette.id;
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
            color: palette.accent.withOpacity(0.14),
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
    this.icon = Icons.analytics_rounded,
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
          colors: [palette.accent.withOpacity(0.95), palette.secondary.withOpacity(0.88), palette.primary.withOpacity(0.74)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: palette.secondary.withOpacity(0.24), blurRadius: 32, offset: const Offset(0, 16)),
          BoxShadow(color: palette.accent.withOpacity(0.16), blurRadius: 46, offset: const Offset(0, 0)),
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
          Positioned(top: -120, right: -110, child: GlowCircle(size: 320, opacity: palette.darkBackground ? 0.18 : 0.10, color: palette.accent)),
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

  @override
  bool shouldRepaint(covariant _PagePatternPainter oldDelegate) => oldDelegate.palette != palette;
}
