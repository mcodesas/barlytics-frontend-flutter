import 'package:flutter/material.dart';

/// Recursos oficiales de identidad visual de BarLytics.
///
/// Todos los PNG de interfaz tienen transparencia real. No incluyen un fondo
/// horneado para que el logo se integre con cualquier tarjeta, menú o pantalla.
abstract final class BarLyticsBrandAssets {
  /// Isotipo B + copa + analítica en 2048x2048 con fondo transparente.
  static const mark = 'assets/branding/barlytics_mark.png';
  static const markTrim = 'assets/branding/barlytics_mark_trim.png';

  /// Versión completa para superficies CLARAS: incluye isotipo, wordmark y lema.
  static const logoForLightBackground = 'assets/branding/barlytics_logo_dark.png';

  /// Versión completa para superficies OSCURAS: incluye isotipo, wordmark y lema.
  static const logoForDarkBackground = 'assets/branding/barlytics_logo_light.png';

  /// Lockup compacto para superficies CLARAS: el isotipo funciona como la B y se completa con “arLytics”.
  static const logoCompactForLightBackground = 'assets/branding/barlytics_logo_dark_compact.png';

  /// Lockup compacto para superficies OSCURAS: el isotipo funciona como la B y se completa con “arLytics”.
  static const logoCompactForDarkBackground = 'assets/branding/barlytics_logo_light_compact.png';

  /// Icono de alta resolución y fondo transparente.
  static const appIcon = 'assets/branding/barlytics_app_icon_1024.png';
}

/// Isotipo oficial para navegación y espacios compactos.
///
/// No agrega Container, color de fondo, borde ni sombra: únicamente pinta el
/// PNG transparente, evitando el cuadro oscuro que se veía alrededor del logo.
class BarLyticsBrandMark extends StatelessWidget {
  const BarLyticsBrandMark({
    super.key,
    this.size = 56,
    this.padding = EdgeInsets.zero,
    this.fit = BoxFit.contain,
  });

  final double size;
  final EdgeInsetsGeometry padding;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Padding(
        padding: padding,
        child: Image.asset(
          BarLyticsBrandAssets.markTrim,
          fit: fit,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
          semanticLabel: 'BarLytics',
        ),
      ),
    );
  }
}

/// Logotipo horizontal oficial con selección automática de contraste.
///
/// Regla de marca:
/// - fondo oscuro -> logo claro;
/// - fondo claro  -> logo oscuro.
///
/// [darkBackground] permite indicar el color real de la superficie. Si no se
/// envía, se usa el brillo del tema actual.
class BarLyticsBrandLockup extends StatelessWidget {
  const BarLyticsBrandLockup({
    super.key,
    this.height = 72,
    this.width,
    this.darkBackground,
    this.showTagline = false,
    this.alignment = Alignment.centerLeft,
    this.fit = BoxFit.contain,
  });

  final double height;
  final double? width;
  final bool? darkBackground;
  final bool showTagline;
  final Alignment alignment;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final isDarkSurface = darkBackground ?? Theme.of(context).brightness == Brightness.dark;
    final asset = showTagline
        ? (isDarkSurface
            ? BarLyticsBrandAssets.logoForDarkBackground
            : BarLyticsBrandAssets.logoForLightBackground)
        : (isDarkSurface
            ? BarLyticsBrandAssets.logoCompactForDarkBackground
            : BarLyticsBrandAssets.logoCompactForLightBackground);

    return SizedBox(
      height: height,
      width: width,
      child: Align(
        alignment: alignment,
        child: Image.asset(
          asset,
          height: height,
          width: width,
          fit: fit,
          alignment: alignment,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
          semanticLabel: showTagline
              ? 'BarLytics - Gestión inteligente para tu negocio'
              : 'BarLytics',
        ),
      ),
    );
  }
}
