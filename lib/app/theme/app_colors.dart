import 'package:flutter/material.dart';

/// Colores base de BarLytics.
///
/// La identidad visual usa el estilo BarTech inspirado en el proyecto de
/// referencia: fondo azul petróleo, superficies glass, menta, cian y dorado.
/// Las pantallas que todavía usan colores estáticos heredan esta misma línea,
/// mientras que las demás toman la paleta seleccionada por el usuario.
class AppColors {
  static const primaryDark = Color(0xFF04131E);
  static const primary = Color(0xFF082B3A);
  static const primaryLight = Color(0xFF0D3B4C);
  static const secondary = Color(0xFF21E6BE);
  static const secondaryDark = Color(0xFF0FBF9E);
  static const tertiary = Color(0xFFFFC857);
  static const accent = Color(0xFF38BDF8);
  static const accentAlt = Color(0xFF2DD4BF);
  static const accentSoft = Color(0xFFCCFBF1);

  static const success = Color(0xFF34D399);
  static const successSoft = Color(0xFFD1FAE5);
  static const warning = Color(0xFFFFC857);
  static const warningSoft = Color(0xFFFFF3C4);
  static const danger = Color(0xFFFF6B6B);
  static const dangerSoft = Color(0xFFFFE4E6);
  static const info = Color(0xFF38BDF8);
  static const infoSoft = Color(0xFFDDF5FF);

  static const background = Color(0xFF061723);
  static const backgroundDark = Color(0xFF04131E);
  static const surface = Color(0xFF0B2634);
  static const surfaceAlt = Color(0xFF123D4F);
  static const surfaceDark = Color(0xFF071E2A);
  static const border = Color(0xFF245264);
  static const borderGlow = Color(0xFF21E6BE);
  static const textPrimary = Color(0xFFF8FAFC);
  static const textSecondary = Color(0xFFCBD5E1);
  static const textMuted = Color(0xFF94A3B8);

  static const techGradient = LinearGradient(
    colors: [primaryDark, primary, Color(0xFF0E5960), Color(0xFF0B3342)],
    stops: [0.0, 0.42, 0.76, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const bluePurpleGradient = LinearGradient(
    colors: [secondary, accent, tertiary],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const softTechGradient = LinearGradient(
    colors: [background, primary, surface],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
