import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Fondo tecnológico reutilizable para mantener una identidad visual unificada.
class TechBackground extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.techGradient),
      child: Stack(
        children: [
          const Positioned(top: -120, right: -90, child: GlowCircle(size: 320, opacity: 0.22)),
          const Positioned(bottom: -140, left: -110, child: GlowCircle(size: 360, opacity: 0.16)),
          const Positioned(top: 140, left: -80, child: GlowCircle(size: 190, opacity: 0.12)),
          if (showPattern) const Positioned.fill(child: _AnalyticsPattern()),
          SafeArea(child: Padding(padding: padding, child: child)),
        ],
      ),
    );
  }
}

class GlowCircle extends StatelessWidget {
  const GlowCircle({super.key, required this.size, this.opacity = 0.16});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [AppColors.accent.withOpacity(opacity), Colors.transparent],
          ),
        ),
      );
}

class _AnalyticsPattern extends StatelessWidget {
  const _AnalyticsPattern();

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: CustomPaint(painter: _AnalyticsPatternPainter()),
      );
}

class _AnalyticsPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()..color = Colors.white.withOpacity(0.045);
    for (double x = 36; x < size.width; x += 34) {
      for (double y = 38; y < size.height; y += 34) {
        canvas.drawCircle(Offset(x, y), 1.3, dotPaint);
      }
    }

    final barPaint = Paint()..color = AppColors.secondary.withOpacity(0.11);
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
      ..color = AppColors.accent.withOpacity(0.18)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(size.width - 430, baseY - 20)
      ..cubicTo(size.width - 330, baseY - 98, size.width - 260, baseY + 24, size.width - 180, baseY - 54)
      ..cubicTo(size.width - 120, baseY - 116, size.width - 70, baseY - 92, size.width - 24, baseY - 152);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Tarjeta tipo glass con borde transparente, inspirada en el diseño del login.
///
/// Mantiene el estilo tecnológico, pero recupera el borde translúcido que hacía
/// que el formulario se viera más liviano sobre el fondo oscuro.
class TechGlassPanel extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final outerRadius = BorderRadius.circular(36);
    final innerRadius = BorderRadius.circular(28);

    final panel = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(dark ? 0.10 : 0.13),
        borderRadius: outerRadius,
        border: Border.all(color: Colors.white.withOpacity(0.24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.24),
            blurRadius: 36,
            offset: const Offset(0, 24),
          ),
          BoxShadow(
            color: AppColors.accent.withOpacity(0.10),
            blurRadius: 44,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: dark ? AppColors.surfaceDark.withOpacity(0.90) : Colors.white.withOpacity(0.96),
          borderRadius: innerRadius,
          border: Border.all(
            color: dark ? Colors.white.withOpacity(0.10) : AppColors.border.withOpacity(0.72),
          ),
        ),
        child: child,
      ),
    );

    if (maxWidth == null) return panel;
    return ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth!), child: panel);
  }
}

class TechBrandMark extends StatelessWidget {
  const TechBrandMark({super.key, this.size = 58, this.icon = Icons.analytics_rounded});

  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.bluePurpleGradient,
          boxShadow: [
            BoxShadow(color: AppColors.accent.withOpacity(0.28), blurRadius: 22, offset: const Offset(0, 8)),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.52),
      );
}

class TechSectionTitle extends StatelessWidget {
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
  Widget build(BuildContext context) => Row(
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
                        color: dark ? Colors.white : AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: dark ? Colors.white70 : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}
