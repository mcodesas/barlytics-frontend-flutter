import 'package:flutter/material.dart';

/// Paleta centralizada de BarLytics.
///
/// La identidad visual se alinea con el diseño tecnológico usado en login y
/// correo de recuperación: azul noche, azul eléctrico, cian y morado.
class AppColors {
  static const primaryDark = Color(0xFF020617);
  static const primary = Color(0xFF0B1B4D);
  static const primaryLight = Color(0xFF172A67);
  static const secondary = Color(0xFF0EA5E9);
  static const secondaryDark = Color(0xFF2563EB);
  static const tertiary = Color(0xFF7C3AED);
  static const accent = Color(0xFF22D3EE);
  static const accentAlt = Color(0xFFA855F7);
  static const accentSoft = Color(0xFFE0F2FE);

  static const success = Color(0xFF10B981);
  static const successSoft = Color(0xFFD1FAE5);
  static const warning = Color(0xFFF59E0B);
  static const warningSoft = Color(0xFFFEF3C7);
  static const danger = Color(0xFFEF4444);
  static const dangerSoft = Color(0xFFFEE2E2);
  static const info = Color(0xFF06B6D4);
  static const infoSoft = Color(0xFFCFFAFE);

  static const background = Color(0xFFF4F8FF);
  static const backgroundDark = Color(0xFF071126);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFEAF3FF);
  static const surfaceDark = Color(0xFF0B1530);
  static const border = Color(0xFFD7E5F5);
  static const borderGlow = Color(0xFF38BDF8);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const textMuted = Color(0xFF94A3B8);

  static const techGradient = LinearGradient(
    colors: [primaryDark, primary, secondaryDark, tertiary],
    stops: [0.0, 0.42, 0.72, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const bluePurpleGradient = LinearGradient(
    colors: [Color(0xFF0EA5E9), Color(0xFF2563EB), Color(0xFF7C3AED)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const softTechGradient = LinearGradient(
    colors: [Color(0xFFE0F2FE), Color(0xFFF5F3FF), Color(0xFFFFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
