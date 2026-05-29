import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  LinearGradient get mainGradient => LinearGradient(
        colors: [titleBackground, secondary, accent],
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
            ? [background, _blend(background, primary, 0.36), _blend(background, secondary, 0.18)]
            : [background, _blend(background, accent, 0.10), _blend(background, surface, 0.50)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  Color get onPrimary => isDarkHeader ? Colors.white : textPrimary;
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
      );

  static Color _blend(Color a, Color b, double t) => Color.lerp(a, b, t) ?? a;
}

const List<AppPalette> appPalettes = <AppPalette>[
  AppPalette(id: 'executive_ink', name: 'Ejecutivo tinta', primary: Color(0xFF0F172A), secondary: Color(0xFF1D4ED8), accent: Color(0xFF38BDF8), background: Color(0xFFF6F8FC), surface: Color(0xFFFFFFFF), titleBackground: Color(0xFF0F172A), titleText: Color(0xFFFFFFFF), textPrimary: Color(0xFF111827), textSecondary: Color(0xFF64748B), isDarkHeader: true, darkBackground: false),
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

  static const String _idKey = 'barlytics.palette.id';
  static const String _customKey = 'barlytics.palette.custom.enabled';
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

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final customEnabled = prefs.getBool(_customKey) ?? false;
    if (customEnabled) {
      final baseId = prefs.getString(_idKey) ?? appPalettes.first.id;
      final base = _firstOrNull(appPalettes.where((palette) => palette.id == baseId)) ?? appPalettes.first;
      state = _readCustom(prefs, base);
      return;
    }

    final id = prefs.getString(_idKey);
    final selected = _firstOrNull(appPalettes.where((palette) => palette.id == id));
    if (selected != null) state = selected;
  }

  Future<void> select(AppPalette palette) async {
    state = palette;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_idKey, palette.id);
    await prefs.setBool(_customKey, false);
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
    final nextBackground = background ?? (darkBackground == null ? state.background : (nextDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC)));
    final nextSurface = surface ?? (darkBackground == null ? state.surface : (nextDark ? const Color(0xFF1F2937) : Colors.white));
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

  Future<void> reset() async {
    await select(appPalettes.first);
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
  }

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
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: screen.height * 0.86,
        ),
        child: Material(
          color: selected.surface.withOpacity(selected.darkBackground ? 0.98 : 0.99),
          borderRadius: BorderRadius.circular(28),
          elevation: 20,
          shadowColor: selected.cardShadow,
          clipBehavior: Clip.antiAlias,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: selected.cardBorder),
            ),
            child: PaletteSettingsPanel(
              onClose: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
      ),
    );
  }
}

class PaletteSettingsPanel extends ConsumerWidget {
  const PaletteSettingsPanel({super.key, this.onClose, this.onHide});

  final VoidCallback? onClose;
  final VoidCallback? onHide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedAppPaletteProvider);
    final controller = ref.read(selectedAppPaletteProvider.notifier);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          primary: false,
          padding: const EdgeInsets.all(14),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth - 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.tune_rounded, color: selected.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Personalizar vista',
                        style: TextStyle(color: selected.textPrimary, fontWeight: FontWeight.w900),
                      ),
                    ),
                    if (onHide != null)
                      IconButton(
                        tooltip: 'Ocultar',
                        onPressed: onHide,
                        icon: const Icon(Icons.visibility_off_rounded),
                        color: selected.textSecondary,
                      ),
                    if (onClose != null)
                      IconButton(
                        tooltip: 'Cerrar',
                        onPressed: onClose,
                        icon: const Icon(Icons.close_rounded),
                        color: selected.textSecondary,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Paletas rápidas',
                  style: TextStyle(color: selected.textSecondary, fontSize: 12, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final palette in appPalettes)
                      _PaletteOption(
                        palette: palette,
                        selected: palette.id == selected.id,
                        onTap: () => controller.select(palette),
                      ),
                  ],
                ),
                const Divider(height: 22),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: selected.darkBackground,
                  activeColor: selected.secondary,
                  title: Text('Fondo oscuro', style: TextStyle(color: selected.textPrimary, fontWeight: FontWeight.w900)),
                  subtitle: Text(
                    'Cambia fondo, tarjetas y contraste de letras.',
                    style: TextStyle(color: selected.textSecondary, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  onChanged: (value) => controller.customize(darkBackground: value),
                ),
                const SizedBox(height: 8),
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
                  title: 'Fondos de títulos',
                  colors: _titleColors,
                  selected: selected.titleBackground,
                  textColor: selected.textPrimary,
                  onColor: (color) => controller.customize(titleBackground: color, autoTitleText: true),
                ),
                _ColorSection(
                  title: 'Color principal',
                  colors: _actionColors,
                  selected: selected.secondary,
                  textColor: selected.textPrimary,
                  onColor: (color) => controller.customize(secondary: color),
                ),
                _ColorSection(
                  title: 'Color de acento',
                  colors: _actionColors,
                  selected: selected.accent,
                  textColor: selected.textPrimary,
                  onColor: (color) => controller.customize(accent: color),
                ),
                _ColorSection(
                  title: 'Color de letras',
                  colors: selected.darkBackground ? _darkTextColors : _lightTextColors,
                  selected: selected.textPrimary,
                  textColor: selected.textPrimary,
                  onColor: (color) => controller.customize(textPrimary: color),
                ),
                _ColorSection(
                  title: 'Color de títulos',
                  colors: _titleTextColors,
                  selected: selected.titleText,
                  textColor: selected.textPrimary,
                  onColor: (color) => controller.customize(titleText: color),
                ),
                _ColorSection(
                  title: 'Color de subtítulos',
                  colors: selected.darkBackground ? _darkSecondaryTextColors : _lightSecondaryTextColors,
                  selected: selected.textSecondary,
                  textColor: selected.textPrimary,
                  onColor: (color) => controller.customize(textSecondary: color),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: controller.reset,
                    icon: const Icon(Icons.restart_alt_rounded, size: 18),
                    label: const Text('Restablecer'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class PaletteFloatingButton extends ConsumerStatefulWidget {
  const PaletteFloatingButton({super.key});

  @override
  ConsumerState<PaletteFloatingButton> createState() => _PaletteFloatingButtonState();
}

class _PaletteFloatingButtonState extends ConsumerState<PaletteFloatingButton> {
  static const double _buttonSize = 58;

  bool _open = false;
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedAppPaletteProvider);
    final media = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final topOffset = padding.top + 72;
    final rightOffset = media.width < 380 ? 12.0 : 16.0;

    if (_hidden) {
      return Positioned(
        right: 8,
        top: padding.top + 74,
        child: _buildFloatingCircle(
          selected: selected,
          tooltip: 'Mostrar personalización',
          icon: Icons.tune_rounded,
          onTap: () => setState(() => _hidden = false),
        ),
      );
    }

    if (!_open) {
      return Positioned(
        right: rightOffset,
        top: topOffset,
        child: _buildFloatingCircle(
          selected: selected,
          tooltip: 'Personalizar colores',
          icon: Icons.tune_rounded,
          onTap: () => setState(() => _open = true),
        ),
      );
    }

    final panelWidth = _resolvePanelWidth(media.width);
    final panelHeight = _resolvePanelHeight(media.height, topOffset);

    return Positioned(
      right: rightOffset,
      top: topOffset,
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
            child: _buildPanel(selected),
          ),
        ),
      ),
    );
  }

  double _resolvePanelWidth(double screenWidth) {
    final available = screenWidth - 24;
    if (available <= 280) return available < 220 ? 220 : available;
    if (screenWidth < 420) return available;
    return 360;
  }

  double _resolvePanelHeight(double screenHeight, double topOffset) {
    final available = screenHeight - topOffset - 18;
    if (available <= 280) return screenHeight * 0.72;
    if (available > 650) return 650;
    return available;
  }

  Widget _buildFloatingCircle({
    required AppPalette selected,
    required String tooltip,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: _buttonSize,
      height: _buttonSize,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: selected.surface.withOpacity(selected.darkBackground ? 0.96 : 0.99),
          shape: CircleBorder(side: BorderSide(color: selected.cardBorder)),
          elevation: 10,
          shadowColor: selected.cardShadow,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Center(child: Icon(icon, color: selected.secondary)),
          ),
        ),
      ),
    );
  }

  Widget _buildPanel(AppPalette selected) {
    return PaletteSettingsPanel(
      onHide: () => setState(() {
        _hidden = true;
        _open = false;
      }),
      onClose: () => setState(() => _open = false),
    );
  }
}

const _lightBackgroundColors = [Color(0xFFF8FAFC), Color(0xFFF2F7FF), Color(0xFFF0F9FF), Color(0xFFEFF6FF), Color(0xFFFFF7E6), Color(0xFFFFFBEB), Color(0xFFF0FDF4), Color(0xFFF0FDFA), Color(0xFFFFF1F2), Color(0xFFFDF2F8), Color(0xFFF5F3FF), Color(0xFFFAF5FF), Color(0xFFFFF7ED), Color(0xFFECFCCB), Color(0xFFE2E8F0)];
const _darkBackgroundColors = [Color(0xFF020617), Color(0xFF030712), Color(0xFF111827), Color(0xFF160B24), Color(0xFF1C1917), Color(0xFF052E2B), Color(0xFF022C22), Color(0xFF172554), Color(0xFF1E1B4B), Color(0xFF082F49), Color(0xFF23030A), Color(0xFF18181B), Color(0xFF020F08)];
const _titleColors = [Color(0xFF020617), Color(0xFF111827), Color(0xFF1C1917), Color(0xFF064E3B), Color(0xFF312E81), Color(0xFF450A0A), Color(0xFF082F49), Color(0xFF022C22), Color(0xFFEFF6FF), Color(0xFFE0F2FE), Color(0xFFFFFBEB), Color(0xFFECFCCB), Color(0xFFF3E8FF), Color(0xFFFCE7F3), Color(0xFFE2E8F0)];
const _actionColors = [Color(0xFF2563EB), Color(0xFF0284C7), Color(0xFF06B6D4), Color(0xFF0F766E), Color(0xFF059669), Color(0xFF65A30D), Color(0xFF7C3AED), Color(0xFF9333EA), Color(0xFF4F46E5), Color(0xFFEC4899), Color(0xFFDB2777), Color(0xFFF59E0B), Color(0xFFD97706), Color(0xFFEA580C), Color(0xFFDC2626), Color(0xFF475569)];
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
