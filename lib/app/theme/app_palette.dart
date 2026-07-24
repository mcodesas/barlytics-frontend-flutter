import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppDensityPreset { compact, balanced, spacious }

enum AppSurfacePreset { flat, soft, glass }

extension AppDensityPresetX on AppDensityPreset {
  String get label => switch (this) {
        AppDensityPreset.compact => 'Compacta',
        AppDensityPreset.balanced => 'Equilibrada',
        AppDensityPreset.spacious => 'Amplia',
      };

  String get description => switch (this) {
        AppDensityPreset.compact => 'Más información visible y controles reducidos.',
        AppDensityPreset.balanced => 'Tamaño recomendado para operación diaria.',
        AppDensityPreset.spacious => 'Más aire y controles grandes para táctil.',
      };
}

extension AppSurfacePresetX on AppSurfacePreset {
  String get label => switch (this) {
        AppSurfacePreset.flat => 'Plano',
        AppSurfacePreset.soft => 'Suave',
        AppSurfacePreset.glass => 'Cristal',
      };

  String get description => switch (this) {
        AppSurfacePreset.flat => 'Superficies sólidas y sin degradados.',
        AppSurfacePreset.soft => 'Degradados discretos y sombras ligeras.',
        AppSurfacePreset.glass => 'Paneles translúcidos con mayor profundidad.',
      };
}

/// Paleta visual seleccionable y personalizable por el usuario.
///
/// Además de las paletas rápidas, el usuario puede ajustar si quiere fondo
/// claro/oscuro y cambiar colores principales de fondo, títulos y textos.
class AppPalette {
  const AppPalette({
    required this.id,
    required this.name,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.titleBackground,
    required this.titleText,
    required this.textPrimary,
    required this.textSecondary,
    required this.isDarkHeader,
    required this.darkBackground,
    this.fontFamily = 'Roboto',
    this.fontScale = 1.0,
    this.density = AppDensityPreset.balanced,
    this.surfaceStyle = AppSurfacePreset.soft,
    this.cornerScale = 1.0,
    this.showBackgroundPattern = true,
  });

  final String id;
  final String name;
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color background;
  final Color surface;
  final Color titleBackground;
  final Color titleText;
  final Color textPrimary;
  final Color textSecondary;
  final bool isDarkHeader;
  final bool darkBackground;
  final String fontFamily;
  final double fontScale;
  final AppDensityPreset density;
  final AppSurfacePreset surfaceStyle;
  final double cornerScale;
  final bool showBackgroundPattern;

  double get spacingScale => switch (density) {
        AppDensityPreset.compact => 0.84,
        AppDensityPreset.balanced => 1.0,
        AppDensityPreset.spacious => 1.16,
      };

  VisualDensity get visualDensity => switch (density) {
        AppDensityPreset.compact => const VisualDensity(horizontal: -2, vertical: -2),
        AppDensityPreset.balanced => VisualDensity.standard,
        AppDensityPreset.spacious => const VisualDensity(horizontal: 1, vertical: 1),
      };

  MaterialTapTargetSize get tapTargetSize => density == AppDensityPreset.compact
      ? MaterialTapTargetSize.shrinkWrap
      : MaterialTapTargetSize.padded;

  double radius(double base) => (base * cornerScale).clamp(8.0, 42.0).toDouble();

  EdgeInsets get pagePadding => EdgeInsets.all(18 * spacingScale);

  EdgeInsets panelPadding([double base = 18]) => EdgeInsets.all(base * spacingScale);

  LinearGradient get mainGradient => LinearGradient(
        colors: [primary, secondary, accent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  LinearGradient get softGradient => LinearGradient(
        colors: [background, _blend(background, surface, 0.45), surface],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  LinearGradient get pageGradient => LinearGradient(
        colors: darkBackground
            ? [
                background,
                _blend(background, primary, 0.16),
                _blend(background, secondary, 0.08),
              ]
            : [background, _blend(background, accent, 0.08), _blend(background, surface, 0.44)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  Color get onPrimary => primary.computeLuminance() > 0.55 ? const Color(0xFF06111F) : Colors.white;
  Color get onTitle => titleText;
  Color get cardBorder => darkBackground ? Colors.white.withOpacity(0.10) : accent.withOpacity(0.24);
  Color get cardShadow => darkBackground ? Colors.black.withOpacity(0.30) : secondary.withOpacity(0.12);

  /// Color semántico para estados correctos/cuadrados.
  /// Se mantiene estable para que no dependa de colores fijos en las pantallas.
  Color get success => darkBackground ? const Color(0xFF34D399) : const Color(0xFF059669);

  /// Color semántico para alertas/diferencias.
  /// Se usa en cierre de caja cuando hay diferencias o notas contables.
  Color get warning => darkBackground ? const Color(0xFFFBBF24) : const Color(0xFFD97706);

  /// Color principal para botones y acciones funcionales.
  /// Se calcula más oscuro/sólido que el acento para que las acciones no queden
  /// con tonos demasiado claros al cambiar de paleta.
  Color get actionColor => darkBackground
      ? _blend(primary, secondary, 0.58)
      : _blend(primary, secondary, 0.42);

  /// Color del texto/icono sobre botones de acción.
  Color get onAction => actionColor.computeLuminance() > 0.50
      ? const Color(0xFF0F172A)
      : Colors.white;

  Color get glassSurface => darkBackground
      ? Colors.white.withOpacity(0.075)
      : surface.withOpacity(0.72);

  Color get translucentBorder => darkBackground
      ? Colors.white.withOpacity(0.18)
      : primary.withOpacity(0.14);

  LinearGradient get glassGradient => LinearGradient(
        colors: darkBackground
            ? [Colors.white.withOpacity(0.10), Colors.white.withOpacity(0.045), secondary.withOpacity(0.08)]
            : [surface.withOpacity(0.86), _blend(surface, accent, 0.10).withOpacity(0.74), Colors.white.withOpacity(0.58)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  LinearGradient panelGradient({Color? tint}) {
    final tone = tint ?? secondary;
    return switch (surfaceStyle) {
      AppSurfacePreset.flat => LinearGradient(
          colors: [surface, surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      AppSurfacePreset.soft => LinearGradient(
          colors: [
            surface.withOpacity(darkBackground ? 0.98 : 1),
            _blend(surface, tone, darkBackground ? 0.10 : 0.045),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      AppSurfacePreset.glass => LinearGradient(
          colors: darkBackground
              ? [Colors.white.withOpacity(0.095), surface.withOpacity(0.90), tone.withOpacity(0.075)]
              : [surface.withOpacity(0.90), Colors.white.withOpacity(0.72), tone.withOpacity(0.075)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
    };
  }

  BoxDecoration panelDecoration({
    double baseRadius = 24,
    Color? tint,
    bool elevated = true,
  }) {
    final tone = tint ?? secondary;
    final useShadow = elevated && surfaceStyle != AppSurfacePreset.flat;
    return BoxDecoration(
      gradient: panelGradient(tint: tone),
      borderRadius: BorderRadius.circular(radius(baseRadius)),
      border: Border.all(
        color: surfaceStyle == AppSurfacePreset.glass
            ? translucentBorder
            : tone.withOpacity(darkBackground ? 0.18 : 0.13),
      ),
      boxShadow: useShadow
          ? [
              BoxShadow(
                color: cardShadow.withOpacity(surfaceStyle == AppSurfacePreset.glass ? 0.30 : 0.22),
                blurRadius: surfaceStyle == AppSurfacePreset.glass ? 30 : 20,
                offset: const Offset(0, 10),
              ),
            ]
          : const [],
    );
  }

  AppPalette copyWith({
    String? id,
    String? name,
    Color? primary,
    Color? secondary,
    Color? accent,
    Color? background,
    Color? surface,
    Color? titleBackground,
    Color? titleText,
    Color? textPrimary,
    Color? textSecondary,
    bool? isDarkHeader,
    bool? darkBackground,
    String? fontFamily,
    double? fontScale,
    AppDensityPreset? density,
    AppSurfacePreset? surfaceStyle,
    double? cornerScale,
    bool? showBackgroundPattern,
  }) =>
      AppPalette(
        id: id ?? this.id,
        name: name ?? this.name,
        primary: primary ?? this.primary,
        secondary: secondary ?? this.secondary,
        accent: accent ?? this.accent,
        background: background ?? this.background,
        surface: surface ?? this.surface,
        titleBackground: titleBackground ?? this.titleBackground,
        titleText: titleText ?? this.titleText,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        isDarkHeader: isDarkHeader ?? this.isDarkHeader,
        darkBackground: darkBackground ?? this.darkBackground,
        fontFamily: fontFamily ?? this.fontFamily,
        fontScale: fontScale ?? this.fontScale,
        density: density ?? this.density,
        surfaceStyle: surfaceStyle ?? this.surfaceStyle,
        cornerScale: cornerScale ?? this.cornerScale,
        showBackgroundPattern: showBackgroundPattern ?? this.showBackgroundPattern,
      );

  static Color _blend(Color a, Color b, double t) => Color.lerp(a, b, t) ?? a;
}

const List<AppPalette> appPalettes = <AppPalette>[
  AppPalette(id: 'barlytics_mint', name: 'BarLytics menta', primary: Color(0xFF21E6BE), secondary: Color(0xFF38BDF8), accent: Color(0xFFFFC857), background: Color(0xFF061723), surface: Color(0xFF0B2634), titleBackground: Color(0xFF0D3142), titleText: Color(0xFFF8FAFC), textPrimary: Color(0xFFF8FAFC), textSecondary: Color(0xFFCBD5E1), isDarkHeader: true, darkBackground: true),
  AppPalette(id: 'emerald_pos', name: 'Caja esmeralda', primary: Color(0xFF064E3B), secondary: Color(0xFF047857), accent: Color(0xFF34D399), background: Color(0xFFF1F8F5), surface: Color(0xFFFFFFFF), titleBackground: Color(0xFF064E3B), titleText: Color(0xFFFFFFFF), textPrimary: Color(0xFF052E2B), textSecondary: Color(0xFF4B635E), isDarkHeader: true, darkBackground: false),
  AppPalette(id: 'amber_lounge', name: 'Lounge ámbar', primary: Color(0xFF422006), secondary: Color(0xFFB45309), accent: Color(0xFFF59E0B), background: Color(0xFFFFF7E6), surface: Color(0xFFFFFCF5), titleBackground: Color(0xFF78350F), titleText: Color(0xFFFFFBEB), textPrimary: Color(0xFF2F1A04), textSecondary: Color(0xFF7C5A2A), isDarkHeader: true, darkBackground: false),
  AppPalette(id: 'graphite_cyan', name: 'Grafito cian', primary: Color(0xFF111827), secondary: Color(0xFF0E7490), accent: Color(0xFF22D3EE), background: Color(0xFFF2FBFC), surface: Color(0xFFFFFFFF), titleBackground: Color(0xFF111827), titleText: Color(0xFFE0F2FE), textPrimary: Color(0xFF111827), textSecondary: Color(0xFF52616B), isDarkHeader: true, darkBackground: false),
  AppPalette(id: 'wine_cash', name: 'Vino caja', primary: Color(0xFF4A044E), secondary: Color(0xFF9D174D), accent: Color(0xFFFB7185), background: Color(0xFFFFF1F5), surface: Color(0xFFFFFFFF), titleBackground: Color(0xFF701A75), titleText: Color(0xFFFFF1F2), textPrimary: Color(0xFF31102F), textSecondary: Color(0xFF7C506F), isDarkHeader: true, darkBackground: false),
  AppPalette(id: 'royal_violet', name: 'Royal violeta', primary: Color(0xFF312E81), secondary: Color(0xFF6D28D9), accent: Color(0xFFA78BFA), background: Color(0xFFF5F3FF), surface: Color(0xFFFFFFFF), titleBackground: Color(0xFF312E81), titleText: Color(0xFFFFFFFF), textPrimary: Color(0xFF1F1B4D), textSecondary: Color(0xFF68618A), isDarkHeader: true, darkBackground: false),
  AppPalette(id: 'ocean_table', name: 'Océano operativo', primary: Color(0xFF082F49), secondary: Color(0xFF0369A1), accent: Color(0xFF38BDF8), background: Color(0xFFF0F9FF), surface: Color(0xFFFFFFFF), titleBackground: Color(0xFF075985), titleText: Color(0xFFE0F2FE), textPrimary: Color(0xFF082F49), textSecondary: Color(0xFF476174), isDarkHeader: true, darkBackground: false),
  AppPalette(id: 'mint_clean', name: 'Menta limpia', primary: Color(0xFF134E4A), secondary: Color(0xFF0F766E), accent: Color(0xFF5EEAD4), background: Color(0xFFF0FDFA), surface: Color(0xFFFFFFFF), titleBackground: Color(0xFF134E4A), titleText: Color(0xFFFFFFFF), textPrimary: Color(0xFF0F2F2C), textSecondary: Color(0xFF52706C), isDarkHeader: true, darkBackground: false),
  AppPalette(id: 'stone_green', name: 'Piedra verde', primary: Color(0xFF1C1917), secondary: Color(0xFF4D7C0F), accent: Color(0xFFA3E635), background: Color(0xFFFAFAF4), surface: Color(0xFFFFFFFF), titleBackground: Color(0xFF365314), titleText: Color(0xFFECFCCB), textPrimary: Color(0xFF1C1917), textSecondary: Color(0xFF626054), isDarkHeader: true, darkBackground: false),
  AppPalette(id: 'copper_soft', name: 'Cobre suave', primary: Color(0xFF431407), secondary: Color(0xFFC2410C), accent: Color(0xFFFB923C), background: Color(0xFFFFF7ED), surface: Color(0xFFFFFFFF), titleBackground: Color(0xFF7C2D12), titleText: Color(0xFFFFF7ED), textPrimary: Color(0xFF2E1609), textSecondary: Color(0xFF805B46), isDarkHeader: true, darkBackground: false),
  AppPalette(id: 'midnight_blue', name: 'Azul medianoche', primary: Color(0xFF020617), secondary: Color(0xFF1D4ED8), accent: Color(0xFF22D3EE), background: Color(0xFF020617), surface: Color(0xFF0F172A), titleBackground: Color(0xFF0B1120), titleText: Color(0xFFE0F2FE), textPrimary: Color(0xFFF8FAFC), textSecondary: Color(0xFFCBD5E1), isDarkHeader: true, darkBackground: true),
  AppPalette(id: 'cyber_lime', name: 'Cyber lima', primary: Color(0xFF030712), secondary: Color(0xFF3F6212), accent: Color(0xFFA3E635), background: Color(0xFF050A06), surface: Color(0xFF111827), titleBackground: Color(0xFF0F1F0A), titleText: Color(0xFFECFCCB), textPrimary: Color(0xFFF7FEE7), textSecondary: Color(0xFFBEF264), isDarkHeader: true, darkBackground: true),
  AppPalette(id: 'night_teal', name: 'Noche teal', primary: Color(0xFF042F2E), secondary: Color(0xFF0F766E), accent: Color(0xFF2DD4BF), background: Color(0xFF031A1A), surface: Color(0xFF082F2D), titleBackground: Color(0xFF042F2E), titleText: Color(0xFFCCFBF1), textPrimary: Color(0xFFF0FDFA), textSecondary: Color(0xFF99F6E4), isDarkHeader: true, darkBackground: true),
  AppPalette(id: 'neon_violet', name: 'Neón violeta', primary: Color(0xFF111827), secondary: Color(0xFF7E22CE), accent: Color(0xFFE879F9), background: Color(0xFF140A24), surface: Color(0xFF211132), titleBackground: Color(0xFF2E1065), titleText: Color(0xFFF5D0FE), textPrimary: Color(0xFFFDF4FF), textSecondary: Color(0xFFD8B4FE), isDarkHeader: true, darkBackground: true),
  AppPalette(id: 'burgundy_night', name: 'Borgoña nocturno', primary: Color(0xFF450A0A), secondary: Color(0xFF9F1239), accent: Color(0xFFFB7185), background: Color(0xFF19070A), surface: Color(0xFF2A1016), titleBackground: Color(0xFF4C0519), titleText: Color(0xFFFFE4E6), textPrimary: Color(0xFFFFF1F2), textSecondary: Color(0xFFFDA4AF), isDarkHeader: true, darkBackground: true),
  AppPalette(id: 'whisky_dark', name: 'Whisky oscuro', primary: Color(0xFF1C1917), secondary: Color(0xFF92400E), accent: Color(0xFFFBBF24), background: Color(0xFF120D08), surface: Color(0xFF241A10), titleBackground: Color(0xFF451A03), titleText: Color(0xFFFFF7ED), textPrimary: Color(0xFFFFFBEB), textSecondary: Color(0xFFFCD34D), isDarkHeader: true, darkBackground: true),
  AppPalette(id: 'slate_pink', name: 'Slate rosa', primary: Color(0xFF0F172A), secondary: Color(0xFFBE185D), accent: Color(0xFFF472B6), background: Color(0xFF0F1220), surface: Color(0xFF1E293B), titleBackground: Color(0xFF831843), titleText: Color(0xFFFCE7F3), textPrimary: Color(0xFFF8FAFC), textSecondary: Color(0xFFF9A8D4), isDarkHeader: true, darkBackground: true),
  AppPalette(id: 'black_gold', name: 'Negro dorado', primary: Color(0xFF030712), secondary: Color(0xFFA16207), accent: Color(0xFFEAB308), background: Color(0xFF070707), surface: Color(0xFF171717), titleBackground: Color(0xFF1C1917), titleText: Color(0xFFFEF3C7), textPrimary: Color(0xFFFAFAFA), textSecondary: Color(0xFFE7C873), isDarkHeader: true, darkBackground: true),
  AppPalette(id: 'electric_indigo', name: 'Índigo eléctrico', primary: Color(0xFF1E1B4B), secondary: Color(0xFF4338CA), accent: Color(0xFF818CF8), background: Color(0xFF0B1027), surface: Color(0xFF171A3A), titleBackground: Color(0xFF312E81), titleText: Color(0xFFE0E7FF), textPrimary: Color(0xFFF8FAFC), textSecondary: Color(0xFFC7D2FE), isDarkHeader: true, darkBackground: true),
  AppPalette(id: 'forest_terminal', name: 'Terminal bosque', primary: Color(0xFF022C22), secondary: Color(0xFF166534), accent: Color(0xFF4ADE80), background: Color(0xFF03110C), surface: Color(0xFF092016), titleBackground: Color(0xFF052E16), titleText: Color(0xFFDCFCE7), textPrimary: Color(0xFFF0FDF4), textSecondary: Color(0xFFBBF7D0), isDarkHeader: true, darkBackground: true),
  AppPalette(id: 'ice_corporate', name: 'Hielo corporativo', primary: Color(0xFFEFF6FF), secondary: Color(0xFF1E40AF), accent: Color(0xFF60A5FA), background: Color(0xFFF8FAFC), surface: Color(0xFFFFFFFF), titleBackground: Color(0xFFEFF6FF), titleText: Color(0xFF0F172A), textPrimary: Color(0xFF0F172A), textSecondary: Color(0xFF475569), isDarkHeader: false, darkBackground: false),
  AppPalette(id: 'rose_light', name: 'Rosa ejecutivo', primary: Color(0xFFFFF1F2), secondary: Color(0xFFBE123C), accent: Color(0xFFFB7185), background: Color(0xFFFFF7F7), surface: Color(0xFFFFFFFF), titleBackground: Color(0xFFFFE4E6), titleText: Color(0xFF4C0519), textPrimary: Color(0xFF37111A), textSecondary: Color(0xFF7F5A63), isDarkHeader: false, darkBackground: false),
  AppPalette(id: 'lavender_light', name: 'Lavanda clara', primary: Color(0xFFF5F3FF), secondary: Color(0xFF5B21B6), accent: Color(0xFFA78BFA), background: Color(0xFFFBFAFF), surface: Color(0xFFFFFFFF), titleBackground: Color(0xFFF5F3FF), titleText: Color(0xFF2E1065), textPrimary: Color(0xFF211C4D), textSecondary: Color(0xFF675E86), isDarkHeader: false, darkBackground: false),
  AppPalette(id: 'aqua_light', name: 'Aqua premium', primary: Color(0xFFECFEFF), secondary: Color(0xFF0E7490), accent: Color(0xFF22D3EE), background: Color(0xFFF0FDFF), surface: Color(0xFFFFFFFF), titleBackground: Color(0xFFECFEFF), titleText: Color(0xFF083344), textPrimary: Color(0xFF083344), textSecondary: Color(0xFF4B6570), isDarkHeader: false, darkBackground: false),
  AppPalette(id: 'sand_bar', name: 'Arena bar', primary: Color(0xFFFEF3C7), secondary: Color(0xFF92400E), accent: Color(0xFFFBBF24), background: Color(0xFFFFFBEB), surface: Color(0xFFFFFFFF), titleBackground: Color(0xFFFEF3C7), titleText: Color(0xFF451A03), textPrimary: Color(0xFF2A1605), textSecondary: Color(0xFF7A6045), isDarkHeader: false, darkBackground: false),
  AppPalette(id: 'olive_light', name: 'Oliva claro', primary: Color(0xFFECFCCB), secondary: Color(0xFF3F6212), accent: Color(0xFFA3E635), background: Color(0xFFFAFFF0), surface: Color(0xFFFFFFFF), titleBackground: Color(0xFFECFCCB), titleText: Color(0xFF1A2E05), textPrimary: Color(0xFF1A2E05), textSecondary: Color(0xFF5F6F3D), isDarkHeader: false, darkBackground: false),
  AppPalette(id: 'platinum_blue', name: 'Platino azul', primary: Color(0xFFE2E8F0), secondary: Color(0xFF334155), accent: Color(0xFF38BDF8), background: Color(0xFFF8FAFC), surface: Color(0xFFFFFFFF), titleBackground: Color(0xFFE2E8F0), titleText: Color(0xFF0F172A), textPrimary: Color(0xFF0F172A), textSecondary: Color(0xFF64748B), isDarkHeader: false, darkBackground: false),
];

final selectedAppPaletteProvider = StateNotifierProvider<AppPaletteController, AppPalette>((ref) {
  return AppPaletteController();
});

class AppPaletteController extends StateNotifier<AppPalette> {
  AppPaletteController() : super(appPalettes.first) {
    _load();
  }

  static const String _idKey = 'barlytics.palette.v2.id';
  static const String _customKey = 'barlytics.palette.v2.custom.enabled';
  static const String _primaryKey = 'barlytics.palette.custom.primary';
  static const String _secondaryKey = 'barlytics.palette.custom.secondary';
  static const String _accentKey = 'barlytics.palette.custom.accent';
  static const String _backgroundKey = 'barlytics.palette.custom.background';
  static const String _surfaceKey = 'barlytics.palette.custom.surface';
  static const String _titleBackgroundKey = 'barlytics.palette.custom.titleBackground';
  static const String _titleTextKey = 'barlytics.palette.custom.titleText';
  static const String _textPrimaryKey = 'barlytics.palette.custom.textPrimary';
  static const String _textSecondaryKey = 'barlytics.palette.custom.textSecondary';
  static const String _darkBackgroundKey = 'barlytics.palette.custom.darkBackground';
  static const String _fontFamilyKey = 'barlytics.appearance.fontFamily';
  static const String _fontScaleKey = 'barlytics.appearance.fontScale';
  static const String _densityKey = 'barlytics.appearance.density';
  static const String _surfaceStyleKey = 'barlytics.appearance.surfaceStyle';
  static const String _cornerScaleKey = 'barlytics.appearance.cornerScale';
  static const String _showPatternKey = 'barlytics.appearance.showPattern';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final customEnabled = prefs.getBool(_customKey) ?? false;
    AppPalette selected;

    if (customEnabled) {
      final baseId = prefs.getString(_idKey) ?? appPalettes.first.id;
      final base = _firstOrNull(appPalettes.where((palette) => palette.id == baseId)) ?? appPalettes.first;
      selected = _readCustom(prefs, base);
    } else {
      final id = prefs.getString(_idKey);
      selected = _firstOrNull(appPalettes.where((palette) => palette.id == id)) ?? appPalettes.first;
    }

    state = _readAppearance(prefs, selected);
  }

  Future<void> select(AppPalette palette) async {
    state = palette.copyWith(
      fontFamily: state.fontFamily,
      fontScale: state.fontScale,
      density: state.density,
      surfaceStyle: state.surfaceStyle,
      cornerScale: state.cornerScale,
      showBackgroundPattern: state.showBackgroundPattern,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_idKey, palette.id);
    await prefs.setBool(_customKey, false);
    await _persistAppearance(prefs);
  }

  Future<void> customize({
    Color? primary,
    Color? secondary,
    Color? accent,
    Color? background,
    Color? surface,
    Color? titleBackground,
    Color? titleText,
    Color? textPrimary,
    Color? textSecondary,
    bool? darkBackground,
    bool autoTitleText = false,
  }) async {
    final nextDark = darkBackground ?? state.darkBackground;
    final nextBackground = background ?? (darkBackground == null ? state.background : (nextDark ? const Color(0xFF061723) : const Color(0xFFF8FAFC)));
    final nextSurface = surface ?? (darkBackground == null ? state.surface : (nextDark ? const Color(0xFF0B2634) : Colors.white));
    final nextTextPrimary = textPrimary ?? (darkBackground == null ? state.textPrimary : (nextDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A)));
    final nextTextSecondary = textSecondary ?? (darkBackground == null ? state.textSecondary : (nextDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B)));

    state = state.copyWith(
      id: 'custom',
      name: 'Personalizada',
      primary: primary,
      secondary: secondary,
      accent: accent,
      background: nextBackground,
      surface: nextSurface,
      titleBackground: titleBackground,
      titleText: autoTitleText && titleBackground != null ? _contrastTitleText(titleBackground) : titleText,
      textPrimary: nextTextPrimary,
      textSecondary: nextTextSecondary,
      isDarkHeader: _isDark(titleBackground ?? state.titleBackground),
      darkBackground: nextDark,
    );
    await _persistCustom();
  }

  Future<void> updateAppearance({
    String? fontFamily,
    double? fontScale,
    AppDensityPreset? density,
    AppSurfacePreset? surfaceStyle,
    double? cornerScale,
    bool? showBackgroundPattern,
  }) async {
    state = state.copyWith(
      fontFamily: fontFamily,
      fontScale: fontScale?.clamp(0.88, 1.20).toDouble(),
      density: density,
      surfaceStyle: surfaceStyle,
      cornerScale: cornerScale?.clamp(0.78, 1.28).toDouble(),
      showBackgroundPattern: showBackgroundPattern,
    );
    final prefs = await SharedPreferences.getInstance();
    await _persistAppearance(prefs);
  }

  Future<void> resetAppearance() async {
    state = state.copyWith(
      fontFamily: 'Roboto',
      fontScale: 1.0,
      density: AppDensityPreset.balanced,
      surfaceStyle: AppSurfacePreset.soft,
      cornerScale: 1.0,
      showBackgroundPattern: true,
    );
    final prefs = await SharedPreferences.getInstance();
    await _persistAppearance(prefs);
  }

  Future<void> reset() async {
    state = appPalettes.first;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_idKey, appPalettes.first.id);
    await prefs.setBool(_customKey, false);
    await _persistAppearance(prefs);
  }

  Future<void> _persistCustom() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_customKey, true);
    await prefs.setString(_idKey, state.id == 'custom' ? appPalettes.first.id : state.id);
    await prefs.setInt(_primaryKey, state.primary.value);
    await prefs.setInt(_secondaryKey, state.secondary.value);
    await prefs.setInt(_accentKey, state.accent.value);
    await prefs.setInt(_backgroundKey, state.background.value);
    await prefs.setInt(_surfaceKey, state.surface.value);
    await prefs.setInt(_titleBackgroundKey, state.titleBackground.value);
    await prefs.setInt(_titleTextKey, state.titleText.value);
    await prefs.setInt(_textPrimaryKey, state.textPrimary.value);
    await prefs.setInt(_textSecondaryKey, state.textSecondary.value);
    await prefs.setBool(_darkBackgroundKey, state.darkBackground);
    await _persistAppearance(prefs);
  }

  Future<void> _persistAppearance(SharedPreferences prefs) async {
    await prefs.setString(_fontFamilyKey, state.fontFamily);
    await prefs.setDouble(_fontScaleKey, state.fontScale);
    await prefs.setString(_densityKey, state.density.name);
    await prefs.setString(_surfaceStyleKey, state.surfaceStyle.name);
    await prefs.setDouble(_cornerScaleKey, state.cornerScale);
    await prefs.setBool(_showPatternKey, state.showBackgroundPattern);
  }

  AppPalette _readAppearance(SharedPreferences prefs, AppPalette base) => base.copyWith(
        fontFamily: prefs.getString(_fontFamilyKey) ?? base.fontFamily,
        fontScale: (prefs.getDouble(_fontScaleKey) ?? base.fontScale).clamp(0.88, 1.20).toDouble(),
        density: AppDensityPreset.values.firstWhere(
          (value) => value.name == prefs.getString(_densityKey),
          orElse: () => base.density,
        ),
        surfaceStyle: AppSurfacePreset.values.firstWhere(
          (value) => value.name == prefs.getString(_surfaceStyleKey),
          orElse: () => base.surfaceStyle,
        ),
        cornerScale: (prefs.getDouble(_cornerScaleKey) ?? base.cornerScale).clamp(0.78, 1.28).toDouble(),
        showBackgroundPattern: prefs.getBool(_showPatternKey) ?? base.showBackgroundPattern,
      );

  AppPalette _readCustom(SharedPreferences prefs, AppPalette base) => base.copyWith(
        id: 'custom',
        name: 'Personalizada',
        primary: _readColor(prefs, _primaryKey, base.primary),
        secondary: _readColor(prefs, _secondaryKey, base.secondary),
        accent: _readColor(prefs, _accentKey, base.accent),
        background: _readColor(prefs, _backgroundKey, base.background),
        surface: _readColor(prefs, _surfaceKey, base.surface),
        titleBackground: _readColor(prefs, _titleBackgroundKey, base.titleBackground),
        titleText: _readColor(prefs, _titleTextKey, base.titleText),
        textPrimary: _readColor(prefs, _textPrimaryKey, base.textPrimary),
        textSecondary: _readColor(prefs, _textSecondaryKey, base.textSecondary),
        isDarkHeader: _isDark(_readColor(prefs, _titleBackgroundKey, base.titleBackground)),
        darkBackground: prefs.getBool(_darkBackgroundKey) ?? base.darkBackground,
      );

  static Color _readColor(SharedPreferences prefs, String key, Color fallback) => Color(prefs.getInt(key) ?? fallback.value);

  static bool _isDark(Color color) => ThemeData.estimateBrightnessForColor(color) == Brightness.dark;
}

T? _firstOrNull<T>(Iterable<T> values) {
  final iterator = values.iterator;
  if (iterator.moveNext()) return iterator.current;
  return null;
}

Future<void> showPaletteSettingsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => const _PaletteSettingsDialog(),
  );
}

class _PaletteSettingsDialog extends ConsumerWidget {
  const _PaletteSettingsDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedAppPaletteProvider);
    final screen = MediaQuery.sizeOf(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: screen.height * 0.86,
        ),
        child: Material(
          color: selected.surface.withOpacity(selected.darkBackground ? 0.98 : 0.99),
          borderRadius: BorderRadius.circular(selected.radius(28)),
          elevation: 20,
          shadowColor: selected.cardShadow,
          clipBehavior: Clip.antiAlias,
          child: PaletteSettingsPanel(
            onClose: () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
    );
  }
}

enum _AppearancePanelSection { themes, typography, components, colors }

class PaletteSettingsPanel extends ConsumerStatefulWidget {
  const PaletteSettingsPanel({super.key, this.onClose, this.onHide});

  final VoidCallback? onClose;
  final VoidCallback? onHide;

  @override
  ConsumerState<PaletteSettingsPanel> createState() => _PaletteSettingsPanelState();
}

class _PaletteSettingsPanelState extends ConsumerState<PaletteSettingsPanel> {
  _AppearancePanelSection _section = _AppearancePanelSection.themes;

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedAppPaletteProvider);
    final controller = ref.read(selectedAppPaletteProvider.notifier);

    return SingleChildScrollView(
      primary: false,
      padding: EdgeInsets.all(16 * selected.spacingScale),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AppearanceHeader(
            palette: selected,
            onHide: widget.onHide,
            onClose: widget.onClose,
          ),
          const SizedBox(height: 14),
          _AppearancePreview(palette: selected),
          const SizedBox(height: 14),
          _AppearanceSectionSelector(
            selected: _section,
            palette: selected,
            onSelected: (value) => setState(() => _section = value),
          ),
          const SizedBox(height: 16),
          switch (_section) {
            _AppearancePanelSection.themes => _ThemePresetSection(
                selected: selected,
                controller: controller,
              ),
            _AppearancePanelSection.typography => _TypographySection(
                selected: selected,
                controller: controller,
              ),
            _AppearancePanelSection.components => _ComponentsSection(
                selected: selected,
                controller: controller,
              ),
            _AppearancePanelSection.colors => _AdvancedColorsSection(
                selected: selected,
                controller: controller,
              ),
          },
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: controller.resetAppearance,
                  icon: const Icon(Icons.text_fields_rounded, size: 18),
                  label: const Text('Restablecer diseño'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextButton.icon(
                  onPressed: controller.reset,
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text('Restablecer todo'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppearanceHeader extends StatelessWidget {
  const _AppearanceHeader({required this.palette, this.onClose, this.onHide});

  final AppPalette palette;
  final VoidCallback? onClose;
  final VoidCallback? onHide;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(palette.radius(15)),
            gradient: palette.mainGradient,
            boxShadow: [
              BoxShadow(
                color: palette.secondary.withOpacity(0.22),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(Icons.tune_rounded, color: palette.onPrimary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Apariencia',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                'La configuración se aplica a menús, tableros, formularios y operación.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: palette.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
        if (onHide != null)
          IconButton(
            onPressed: onHide,
            icon: const Icon(Icons.visibility_off_rounded),
            color: palette.textSecondary,
          ),
        if (onClose != null)
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
            color: palette.textSecondary,
          ),
      ],
    );
  }
}

class _AppearancePreview extends StatelessWidget {
  const _AppearancePreview({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: palette.panelPadding(14),
      decoration: palette.panelDecoration(baseRadius: 20, tint: palette.secondary),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: palette.actionColor,
              borderRadius: BorderRadius.circular(palette.radius(15)),
            ),
            child: Icon(Icons.dashboard_customize_rounded, color: palette.onAction),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  palette.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontFamily: palette.fontFamily,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${palette.density.label} · ${palette.surfaceStyle.label} · ${_fontLabel(palette.fontFamily)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: palette.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontFamily: palette.fontFamily,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ColorDot(color: palette.primary),
              _ColorDot(color: palette.secondary),
              _ColorDot(color: palette.accent),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppearanceSectionSelector extends StatelessWidget {
  const _AppearanceSectionSelector({required this.selected, required this.palette, required this.onSelected});

  final _AppearancePanelSection selected;
  final AppPalette palette;
  final ValueChanged<_AppearancePanelSection> onSelected;

  @override
  Widget build(BuildContext context) {
    const items = <(_AppearancePanelSection, IconData, String)>[
      (_AppearancePanelSection.themes, Icons.palette_outlined, 'Temas'),
      (_AppearancePanelSection.typography, Icons.text_fields_rounded, 'Letra'),
      (_AppearancePanelSection.components, Icons.widgets_outlined, 'Diseño'),
      (_AppearancePanelSection.colors, Icons.color_lens_outlined, 'Colores'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(palette.darkBackground ? 0.48 : 0.72),
        borderRadius: BorderRadius.circular(palette.radius(16)),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final item in items)
            _AppearanceSectionButton(
              icon: item.$2,
              label: item.$3,
              selected: selected == item.$1,
              palette: palette,
              onTap: () => onSelected(item.$1),
            ),
        ],
      ),
    );
  }
}

class _AppearanceSectionButton extends StatelessWidget {
  const _AppearanceSectionButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final AppPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(palette.radius(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(palette.radius(12)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? palette.secondary.withOpacity(0.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(palette.radius(12)),
            border: Border.all(
              color: selected ? palette.secondary.withOpacity(0.26) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: selected ? palette.secondary : palette.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? palette.textPrimary : palette.textSecondary,
                  fontWeight: FontWeight.w900,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemePresetSection extends StatelessWidget {
  const _ThemePresetSection({required this.selected, required this.controller});

  final AppPalette selected;
  final AppPaletteController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AppearanceSectionTitle(
          title: 'Paleta principal',
          subtitle: 'Cambia la identidad de toda la aplicación.',
          palette: selected,
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          primary: false,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: appPalettes.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 9,
            crossAxisSpacing: 9,
            mainAxisExtent: 96,
          ),
          itemBuilder: (context, index) {
            final palette = appPalettes[index];
            return _ThemePresetCard(
              palette: palette,
              selected: selected.id == palette.id,
              onTap: () => controller.select(palette),
            );
          },
        ),
        const SizedBox(height: 14),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: selected.darkBackground,
          activeColor: selected.secondary,
          title: Text('Modo oscuro', style: TextStyle(color: selected.textPrimary, fontWeight: FontWeight.w900)),
          subtitle: Text(
            'Ajusta fondo, superficies y contraste de forma coordinada.',
            style: TextStyle(color: selected.textSecondary, fontWeight: FontWeight.w700, fontSize: 12),
          ),
          onChanged: (value) => controller.customize(darkBackground: value),
        ),
      ],
    );
  }
}

class _ThemePresetCard extends StatelessWidget {
  const _ThemePresetCard({required this.palette, required this.selected, required this.onTap});

  final AppPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: palette.panelGradient(tint: palette.secondary),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? palette.secondary : palette.cardBorder,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _ColorDot(color: palette.primary),
                  _ColorDot(color: palette.secondary),
                  _ColorDot(color: palette.accent),
                  const Spacer(),
                  if (selected) Icon(Icons.check_circle_rounded, size: 18, color: palette.secondary),
                ],
              ),
              const Spacer(),
              Text(
                palette.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 11.5),
              ),
              const SizedBox(height: 2),
              Text(
                palette.darkBackground ? 'Oscura' : 'Clara',
                style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypographySection extends StatelessWidget {
  const _TypographySection({required this.selected, required this.controller});

  final AppPalette selected;
  final AppPaletteController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AppearanceSectionTitle(
          title: 'Tipografía',
          subtitle: 'La letra cambia en menús, tableros, tablas, botones y formularios.',
          palette: selected,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _fontOptions.any((item) => item.family == selected.fontFamily) ? selected.fontFamily : 'Roboto',
          decoration: const InputDecoration(
            labelText: 'Familia de letra',
            prefixIcon: Icon(Icons.font_download_outlined),
          ),
          items: [
            for (final option in _fontOptions)
              DropdownMenuItem(
                value: option.family,
                child: Text(option.label, style: TextStyle(fontFamily: option.family)),
              ),
          ],
          onChanged: (value) {
            if (value != null) controller.updateAppearance(fontFamily: value);
          },
        ),
        const SizedBox(height: 16),
        _SliderSetting(
          title: 'Tamaño de letra',
          valueLabel: '${(selected.fontScale * 100).round()} %',
          value: selected.fontScale,
          min: 0.88,
          max: 1.20,
          divisions: 8,
          palette: selected,
          onChanged: (value) => controller.updateAppearance(fontScale: value),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: selected.panelPadding(16),
          decoration: selected.panelDecoration(baseRadius: 20, tint: selected.primary, elevated: false),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vista previa del tablero',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontFamily: selected.fontFamily,
                      color: selected.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 5),
              Text(
                'Ventas del turno · 12 mesas activas · Caja cuadrada',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontFamily: selected.fontFamily,
                      color: selected.textSecondary,
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

class _ComponentsSection extends StatelessWidget {
  const _ComponentsSection({required this.selected, required this.controller});

  final AppPalette selected;
  final AppPaletteController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AppearanceSectionTitle(
          title: 'Estructura visual',
          subtitle: 'Controla densidad, tarjetas, bordes y fondos desde una sola parametrización.',
          palette: selected,
        ),
        const SizedBox(height: 12),
        Text('Densidad', style: TextStyle(color: selected.textPrimary, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        for (final density in AppDensityPreset.values) ...[
          _AppearanceOptionTile(
            title: density.label,
            subtitle: density.description,
            icon: switch (density) {
              AppDensityPreset.compact => Icons.density_small_rounded,
              AppDensityPreset.balanced => Icons.density_medium_rounded,
              AppDensityPreset.spacious => Icons.density_large_rounded,
            },
            selected: selected.density == density,
            palette: selected,
            onTap: () => controller.updateAppearance(density: density),
          ),
          const SizedBox(height: 7),
        ],
        const SizedBox(height: 10),
        Text('Estilo de paneles', style: TextStyle(color: selected.textPrimary, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        for (final style in AppSurfacePreset.values) ...[
          _AppearanceOptionTile(
            title: style.label,
            subtitle: style.description,
            icon: switch (style) {
              AppSurfacePreset.flat => Icons.crop_square_rounded,
              AppSurfacePreset.soft => Icons.gradient_rounded,
              AppSurfacePreset.glass => Icons.blur_on_rounded,
            },
            selected: selected.surfaceStyle == style,
            palette: selected,
            onTap: () => controller.updateAppearance(surfaceStyle: style),
          ),
          const SizedBox(height: 7),
        ],
        const SizedBox(height: 12),
        _SliderSetting(
          title: 'Redondeo de tarjetas',
          valueLabel: '${(selected.cornerScale * 100).round()} %',
          value: selected.cornerScale,
          min: 0.78,
          max: 1.28,
          divisions: 10,
          palette: selected,
          onChanged: (value) => controller.updateAppearance(cornerScale: value),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: selected.showBackgroundPattern,
          activeColor: selected.secondary,
          title: Text('Decoración de fondo', style: TextStyle(color: selected.textPrimary, fontWeight: FontWeight.w900)),
          subtitle: Text(
            'Muestra puntos, íconos y líneas sutiles en las pantallas.',
            style: TextStyle(color: selected.textSecondary, fontWeight: FontWeight.w700, fontSize: 12),
          ),
          onChanged: (value) => controller.updateAppearance(showBackgroundPattern: value),
        ),
      ],
    );
  }
}

class _AdvancedColorsSection extends StatelessWidget {
  const _AdvancedColorsSection({required this.selected, required this.controller});

  final AppPalette selected;
  final AppPaletteController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AppearanceSectionTitle(
          title: 'Colores avanzados',
          subtitle: 'Ajusta los colores base; todos los componentes se recalculan desde aquí.',
          palette: selected,
        ),
        const SizedBox(height: 12),
        _ColorSection(
          title: 'Color principal',
          colors: _actionColors,
          selected: selected.primary,
          textColor: selected.textPrimary,
          onColor: (color) => controller.customize(primary: color),
        ),
        _ColorSection(
          title: 'Color secundario',
          colors: _actionColors,
          selected: selected.secondary,
          textColor: selected.textPrimary,
          onColor: (color) => controller.customize(secondary: color),
        ),
        _ColorSection(
          title: 'Acento',
          colors: _actionColors,
          selected: selected.accent,
          textColor: selected.textPrimary,
          onColor: (color) => controller.customize(accent: color),
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: Text('Fondos y superficies', style: TextStyle(color: selected.textPrimary, fontWeight: FontWeight.w900)),
          subtitle: Text('Páginas, tarjetas y encabezados', style: TextStyle(color: selected.textSecondary, fontWeight: FontWeight.w700, fontSize: 12)),
          children: [
            _ColorSection(
              title: 'Fondo de páginas',
              colors: selected.darkBackground ? _darkBackgroundColors : _lightBackgroundColors,
              selected: selected.background,
              textColor: selected.textPrimary,
              onColor: (color) => controller.customize(background: color),
            ),
            _ColorSection(
              title: 'Fondo de tarjetas',
              colors: selected.darkBackground ? _darkBackgroundColors : _lightBackgroundColors,
              selected: selected.surface,
              textColor: selected.textPrimary,
              onColor: (color) => controller.customize(surface: color),
            ),
            _ColorSection(
              title: 'Fondo de encabezados',
              colors: _titleColors,
              selected: selected.titleBackground,
              textColor: selected.textPrimary,
              onColor: (color) => controller.customize(titleBackground: color, autoTitleText: true),
            ),
          ],
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: Text('Letras y contraste', style: TextStyle(color: selected.textPrimary, fontWeight: FontWeight.w900)),
          subtitle: Text('Texto principal, secundario y títulos', style: TextStyle(color: selected.textSecondary, fontWeight: FontWeight.w700, fontSize: 12)),
          children: [
            _ColorSection(
              title: 'Texto principal',
              colors: selected.darkBackground ? _darkTextColors : _lightTextColors,
              selected: selected.textPrimary,
              textColor: selected.textPrimary,
              onColor: (color) => controller.customize(textPrimary: color),
            ),
            _ColorSection(
              title: 'Texto secundario',
              colors: selected.darkBackground ? _darkSecondaryTextColors : _lightSecondaryTextColors,
              selected: selected.textSecondary,
              textColor: selected.textPrimary,
              onColor: (color) => controller.customize(textSecondary: color),
            ),
            _ColorSection(
              title: 'Texto de encabezados',
              colors: _titleTextColors,
              selected: selected.titleText,
              textColor: selected.textPrimary,
              onColor: (color) => controller.customize(titleText: color),
            ),
          ],
        ),
      ],
    );
  }
}

class _AppearanceSectionTitle extends StatelessWidget {
  const _AppearanceSectionTitle({required this.title, required this.subtitle, required this.palette});

  final String title;
  final String subtitle;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: palette.textPrimary, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: palette.textSecondary, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _AppearanceOptionTile extends StatelessWidget {
  const _AppearanceOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final AppPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(palette.radius(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(palette.radius(16)),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? palette.secondary.withOpacity(0.12) : palette.background.withOpacity(palette.darkBackground ? 0.38 : 0.68),
            borderRadius: BorderRadius.circular(palette.radius(16)),
            border: Border.all(color: selected ? palette.secondary.withOpacity(0.34) : palette.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: selected ? palette.secondary.withOpacity(0.17) : palette.surface.withOpacity(0.70),
                  borderRadius: BorderRadius.circular(palette.radius(12)),
                ),
                child: Icon(icon, color: selected ? palette.secondary : palette.textSecondary, size: 20),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 11.5)),
                  ],
                ),
              ),
              if (selected) Icon(Icons.check_circle_rounded, color: palette.secondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _SliderSetting extends StatelessWidget {
  const _SliderSetting({
    required this.title,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.palette,
    required this.onChanged,
  });

  final String title;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final AppPalette palette;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(palette.darkBackground ? 0.38 : 0.68),
        borderRadius: BorderRadius.circular(palette.radius(16)),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900))),
              Text(valueLabel, style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900)),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: palette.secondary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _FontOptionData {
  const _FontOptionData(this.family, this.label);

  final String family;
  final String label;
}

const _fontOptions = <_FontOptionData>[
  _FontOptionData('Roboto', 'Roboto · Moderna'),
  _FontOptionData('Arial', 'Arial · Clara'),
  _FontOptionData('Verdana', 'Verdana · Amplia'),
  _FontOptionData('Trebuchet MS', 'Trebuchet · Dinámica'),
  _FontOptionData('Georgia', 'Georgia · Editorial'),
  _FontOptionData('monospace', 'Monoespaciada · Técnica'),
];

String _fontLabel(String family) {
  for (final option in _fontOptions) {
    if (option.family == family) return option.label.split(' · ').first;
  }
  return family;
}

class PaletteFloatingButton extends ConsumerStatefulWidget {
  const PaletteFloatingButton({super.key});

  @override
  ConsumerState<PaletteFloatingButton> createState() =>
      _PaletteFloatingButtonState();
}

class _PaletteFloatingButtonState extends ConsumerState<PaletteFloatingButton> {
  static const double _buttonSize = 58;

  bool _open = false;
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedAppPaletteProvider);
    final media = MediaQuery.sizeOf(context);
    final safePadding = MediaQuery.paddingOf(context);
    final rightOffset = media.width < 380 ? 12.0 : 18.0;
    final bottomOffset = safePadding.bottom + 18.0;

    if (_hidden) {
      return Positioned(
        right: 8,
        bottom: safePadding.bottom + 18,
        child: _buildFloatingCircle(
          selected: selected,
          semanticsLabel: 'Mostrar personalización',
          icon: Icons.tune_rounded,
          onTap: () => setState(() => _hidden = false),
        ),
      );
    }

    if (!_open) {
      return Positioned(
        right: rightOffset,
        bottom: bottomOffset,
        child: _buildFloatingCircle(
          selected: selected,
          semanticsLabel: 'Personalizar colores',
          icon: Icons.palette_outlined,
          onTap: () => setState(() => _open = true),
        ),
      );
    }

    final panelWidth = _resolvePanelWidth(media.width);
    final panelHeight = _resolvePanelHeight(media.height, safePadding);

    return Positioned(
      right: rightOffset,
      bottom: bottomOffset,
      child: SizedBox(
        width: panelWidth,
        height: panelHeight,
        child: Material(
          color: selected.surface.withOpacity(selected.darkBackground ? 0.97 : 0.99),
          borderRadius: BorderRadius.circular(26),
          clipBehavior: Clip.antiAlias,
          elevation: 18,
          shadowColor: selected.cardShadow,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: selected.cardBorder),
            ),
            child: PaletteSettingsPanel(
              onHide: () => setState(() {
                _hidden = true;
                _open = false;
              }),
              onClose: () => setState(() => _open = false),
            ),
          ),
        ),
      ),
    );
  }

  double _resolvePanelWidth(double screenWidth) {
    final available = screenWidth - 24;
    if (available <= 280) return available.clamp(220.0, 360.0).toDouble();
    if (screenWidth < 420) return available;
    return 360;
  }

  double _resolvePanelHeight(double screenHeight, EdgeInsets safePadding) {
    final available = screenHeight - safePadding.top - safePadding.bottom - 36;
    if (available <= 300) return available.clamp(260.0, 650.0).toDouble();
    return available.clamp(300.0, 650.0).toDouble();
  }

  Widget _buildFloatingCircle({
    required AppPalette selected,
    required String semanticsLabel,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: _buttonSize,
            height: _buttonSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: selected.mainGradient,
              border: Border.all(color: selected.textPrimary.withOpacity(0.16)),
              boxShadow: [
                BoxShadow(
                  color: selected.primary.withOpacity(0.34),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Icon(icon, color: selected.onPrimary),
          ),
        ),
      ),
    );
  }
}

const _lightBackgroundColors = [Color(0xFFF8FAFC), Color(0xFFF2F7FF), Color(0xFFF0F9FF), Color(0xFFEFF6FF), Color(0xFFFFF7E6), Color(0xFFFFFBEB), Color(0xFFF0FDF4), Color(0xFFF0FDFA), Color(0xFFFFF1F2), Color(0xFFFDF2F8), Color(0xFFF5F3FF), Color(0xFFFAF5FF), Color(0xFFFFF7ED), Color(0xFFECFCCB), Color(0xFFE2E8F0)];
const _darkBackgroundColors = [Color(0xFF061723), Color(0xFF0B2634), Color(0xFF0D3142), Color(0xFF123D4F), Color(0xFF020617), Color(0xFF030712), Color(0xFF111827), Color(0xFF160B24), Color(0xFF1C1917), Color(0xFF052E2B), Color(0xFF022C22), Color(0xFF172554), Color(0xFF1E1B4B), Color(0xFF082F49), Color(0xFF23030A), Color(0xFF18181B), Color(0xFF020F08)];
const _titleColors = [Color(0xFF0D3142), Color(0xFF123D4F), Color(0xFF155B66), Color(0xFF020617), Color(0xFF111827), Color(0xFF1C1917), Color(0xFF064E3B), Color(0xFF312E81), Color(0xFF450A0A), Color(0xFF082F49), Color(0xFF022C22), Color(0xFFEFF6FF), Color(0xFFE0F2FE), Color(0xFFFFFBEB), Color(0xFFECFCCB), Color(0xFFF3E8FF), Color(0xFFFCE7F3), Color(0xFFE2E8F0)];
const _actionColors = [Color(0xFF21E6BE), Color(0xFF38BDF8), Color(0xFFFFC857), Color(0xFF2563EB), Color(0xFF0284C7), Color(0xFF06B6D4), Color(0xFF0F766E), Color(0xFF059669), Color(0xFF65A30D), Color(0xFF7C3AED), Color(0xFF9333EA), Color(0xFF4F46E5), Color(0xFFEC4899), Color(0xFFDB2777), Color(0xFFF59E0B), Color(0xFFD97706), Color(0xFFEA580C), Color(0xFFDC2626), Color(0xFF475569)];
const _lightTextColors = [Color(0xFF0F172A), Color(0xFF1C1917), Color(0xFF052E2B), Color(0xFF042F2E), Color(0xFF312E81), Color(0xFF581C87), Color(0xFF831843), Color(0xFF7C2D12), Color(0xFF365314), Color(0xFF374151)];
const _lightSecondaryTextColors = [Color(0xFF64748B), Color(0xFF78716C), Color(0xFF6B7280), Color(0xFF475569), Color(0xFF4B5563), Color(0xFF0F766E), Color(0xFF7E22CE), Color(0xFF9D174D), Color(0xFF854D0E)];
const _titleTextColors = [Colors.white, Color(0xFF0F172A), Color(0xFF111827), Color(0xFFFFFBEB), Color(0xFFE0F2FE), Color(0xFFECFDF5), Color(0xFFFDE68A), Color(0xFFFDF2F8), Color(0xFFF3E8FF), Color(0xFFDCFCE7)];
const _darkTextColors = [Color(0xFFF8FAFC), Color(0xFFE0F2FE), Color(0xFFFFFBEB), Color(0xFFF0FDF4), Color(0xFFFDF2F8), Color(0xFFF5F3FF), Color(0xFFDCFCE7), Color(0xFFFAFAFA)];
const _darkSecondaryTextColors = [Color(0xFFCBD5E1), Color(0xFFBAE6FD), Color(0xFFD8B4FE), Color(0xFFFDE68A), Color(0xFFA7F3D0), Color(0xFFFBCFE8), Color(0xFFFED7AA), Color(0xFFBBF7D0)];

Color _contrastTitleText(Color titleBackground) => ThemeData.estimateBrightnessForColor(titleBackground) == Brightness.dark ? Colors.white : const Color(0xFF0F172A);

class _ColorSection extends StatelessWidget {
  const _ColorSection({required this.title, required this.colors, required this.selected, required this.textColor, required this.onColor});

  final String title;
  final List<Color> colors;
  final Color selected;
  final Color textColor;
  final ValueChanged<Color> onColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: textColor, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final color in colors)
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onColor(color),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: selected.value == color.value ? Colors.black87 : Colors.white, width: selected.value == color.value ? 2.4 : 1.4),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: selected.value == color.value ? Icon(Icons.check_rounded, size: 16, color: _contrastTitleText(color)) : null,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaletteOption extends StatelessWidget {
  const _PaletteOption({required this.palette, required this.selected, required this.onTap});

  final AppPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 138,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: selected ? palette.accent.withOpacity(0.14) : palette.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? palette.secondary : palette.cardBorder, width: selected ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _ColorDot(color: palette.titleBackground),
                  _ColorDot(color: palette.background),
                  _ColorDot(color: palette.textPrimary),
                  const Spacer(),
                  if (selected) Icon(Icons.check_circle_rounded, size: 17, color: palette.secondary),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                palette.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: palette.textPrimary, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      );
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 18,
        height: 18,
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.4)),
      );
}
