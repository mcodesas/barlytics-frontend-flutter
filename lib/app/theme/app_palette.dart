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
  AppPalette(
    id: 'tech_blue',
    name: 'Tecnológico azul',
    primary: Color(0xFF020617),
    secondary: Color(0xFF2563EB),
    accent: Color(0xFF22D3EE),
    background: Color(0xFFF2F7FF),
    surface: Color(0xFFFFFFFF),
    titleBackground: Color(0xFF020617),
    titleText: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
    isDarkHeader: true,
    darkBackground: false,
  ),
  AppPalette(
    id: 'bar_gold',
    name: 'Bar dorado',
    primary: Color(0xFF1C1917),
    secondary: Color(0xFFB45309),
    accent: Color(0xFFF59E0B),
    background: Color(0xFFFFF7E6),
    surface: Color(0xFFFFFFFF),
    titleBackground: Color(0xFF1C1917),
    titleText: Color(0xFFFFFBEB),
    textPrimary: Color(0xFF1C1917),
    textSecondary: Color(0xFF78716C),
    isDarkHeader: true,
    darkBackground: false,
  ),
  AppPalette(
    id: 'neon_pub',
    name: 'Neón pub',
    primary: Color(0xFF111827),
    secondary: Color(0xFF7C3AED),
    accent: Color(0xFFEC4899),
    background: Color(0xFF160B24),
    surface: Color(0xFF21132F),
    titleBackground: Color(0xFF111827),
    titleText: Color(0xFFFFFFFF),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFFD8B4FE),
    isDarkHeader: true,
    darkBackground: true,
  ),
  AppPalette(
    id: 'fresh_mint',
    name: 'Verde fresco',
    primary: Color(0xFF064E3B),
    secondary: Color(0xFF059669),
    accent: Color(0xFF34D399),
    background: Color(0xFFF0FDF4),
    surface: Color(0xFFFFFFFF),
    titleBackground: Color(0xFF064E3B),
    titleText: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF052E2B),
    textSecondary: Color(0xFF64748B),
    isDarkHeader: true,
    darkBackground: false,
  ),
  AppPalette(
    id: 'clean_light',
    name: 'Claro elegante',
    primary: Color(0xFFEFF6FF),
    secondary: Color(0xFF3B82F6),
    accent: Color(0xFF60A5FA),
    background: Color(0xFFF8FAFC),
    surface: Color(0xFFFFFFFF),
    titleBackground: Color(0xFFEFF6FF),
    titleText: Color(0xFF0F172A),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    isDarkHeader: false,
    darkBackground: false,
  ),

  AppPalette(
    id: 'cyber_night',
    name: 'Cyber night',
    primary: Color(0xFF020617),
    secondary: Color(0xFF06B6D4),
    accent: Color(0xFF84CC16),
    background: Color(0xFF030712),
    surface: Color(0xFF0F172A),
    titleBackground: Color(0xFF020617),
    titleText: Color(0xFFE0F2FE),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFFBAE6FD),
    isDarkHeader: true,
    darkBackground: true,
  ),
  AppPalette(
    id: 'midnight_violet',
    name: 'Medianoche violeta',
    primary: Color(0xFF1E1B4B),
    secondary: Color(0xFF8B5CF6),
    accent: Color(0xFF22D3EE),
    background: Color(0xFF0F1029),
    surface: Color(0xFF1E1B4B),
    titleBackground: Color(0xFF111827),
    titleText: Color(0xFFF5F3FF),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFFC4B5FD),
    isDarkHeader: true,
    darkBackground: true,
  ),
  AppPalette(
    id: 'emerald_dark',
    name: 'Esmeralda dark',
    primary: Color(0xFF022C22),
    secondary: Color(0xFF10B981),
    accent: Color(0xFF67E8F9),
    background: Color(0xFF031A16),
    surface: Color(0xFF063B32),
    titleBackground: Color(0xFF022C22),
    titleText: Color(0xFFECFDF5),
    textPrimary: Color(0xFFF0FDF4),
    textSecondary: Color(0xFFA7F3D0),
    isDarkHeader: true,
    darkBackground: true,
  ),
  AppPalette(
    id: 'graphite_orange',
    name: 'Grafito naranja',
    primary: Color(0xFF18181B),
    secondary: Color(0xFFEA580C),
    accent: Color(0xFFFACC15),
    background: Color(0xFF111111),
    surface: Color(0xFF27272A),
    titleBackground: Color(0xFF18181B),
    titleText: Color(0xFFFFF7ED),
    textPrimary: Color(0xFFFAFAFA),
    textSecondary: Color(0xFFFED7AA),
    isDarkHeader: true,
    darkBackground: true,
  ),
  AppPalette(
    id: 'deep_wine',
    name: 'Vino premium',
    primary: Color(0xFF450A0A),
    secondary: Color(0xFFBE123C),
    accent: Color(0xFFF59E0B),
    background: Color(0xFF23030A),
    surface: Color(0xFF3F0B17),
    titleBackground: Color(0xFF450A0A),
    titleText: Color(0xFFFFF1F2),
    textPrimary: Color(0xFFFFF7ED),
    textSecondary: Color(0xFFFDA4AF),
    isDarkHeader: true,
    darkBackground: true,
  ),
  AppPalette(
    id: 'ocean_dark',
    name: 'Océano dark',
    primary: Color(0xFF082F49),
    secondary: Color(0xFF0284C7),
    accent: Color(0xFF2DD4BF),
    background: Color(0xFF061A2D),
    surface: Color(0xFF0C2A3C),
    titleBackground: Color(0xFF082F49),
    titleText: Color(0xFFE0F2FE),
    textPrimary: Color(0xFFF0F9FF),
    textSecondary: Color(0xFFBAE6FD),
    isDarkHeader: true,
    darkBackground: true,
  ),
  AppPalette(
    id: 'ice_blue',
    name: 'Azul hielo',
    primary: Color(0xFFE0F2FE),
    secondary: Color(0xFF0284C7),
    accent: Color(0xFF22D3EE),
    background: Color(0xFFF0F9FF),
    surface: Color(0xFFFFFFFF),
    titleBackground: Color(0xFFE0F2FE),
    titleText: Color(0xFF0C4A6E),
    textPrimary: Color(0xFF082F49),
    textSecondary: Color(0xFF475569),
    isDarkHeader: false,
    darkBackground: false,
  ),
  AppPalette(
    id: 'pearl_lime',
    name: 'Perla lima',
    primary: Color(0xFFECFCCB),
    secondary: Color(0xFF65A30D),
    accent: Color(0xFFA3E635),
    background: Color(0xFFFAFFF2),
    surface: Color(0xFFFFFFFF),
    titleBackground: Color(0xFFECFCCB),
    titleText: Color(0xFF365314),
    textPrimary: Color(0xFF1A2E05),
    textSecondary: Color(0xFF64748B),
    isDarkHeader: false,
    darkBackground: false,
  ),
  AppPalette(
    id: 'rose_light',
    name: 'Rosa ejecutivo',
    primary: Color(0xFFFCE7F3),
    secondary: Color(0xFFDB2777),
    accent: Color(0xFFF472B6),
    background: Color(0xFFFFF7FB),
    surface: Color(0xFFFFFFFF),
    titleBackground: Color(0xFFFCE7F3),
    titleText: Color(0xFF831843),
    textPrimary: Color(0xFF3B1225),
    textSecondary: Color(0xFF6B7280),
    isDarkHeader: false,
    darkBackground: false,
  ),
  AppPalette(
    id: 'sand_coffee',
    name: 'Arena café',
    primary: Color(0xFFFEF3C7),
    secondary: Color(0xFFD97706),
    accent: Color(0xFFFBBF24),
    background: Color(0xFFFFFBEB),
    surface: Color(0xFFFFFFFF),
    titleBackground: Color(0xFFFEF3C7),
    titleText: Color(0xFF78350F),
    textPrimary: Color(0xFF1C1917),
    textSecondary: Color(0xFF78716C),
    isDarkHeader: false,
    darkBackground: false,
  ),
  AppPalette(
    id: 'silver_slate',
    name: 'Plata ejecutiva',
    primary: Color(0xFFE2E8F0),
    secondary: Color(0xFF475569),
    accent: Color(0xFF38BDF8),
    background: Color(0xFFF8FAFC),
    surface: Color(0xFFFFFFFF),
    titleBackground: Color(0xFFE2E8F0),
    titleText: Color(0xFF0F172A),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
    isDarkHeader: false,
    darkBackground: false,
  ),
  AppPalette(
    id: 'royal_indigo',
    name: 'Índigo royal',
    primary: Color(0xFF312E81),
    secondary: Color(0xFF4F46E5),
    accent: Color(0xFFF472B6),
    background: Color(0xFFF5F3FF),
    surface: Color(0xFFFFFFFF),
    titleBackground: Color(0xFF312E81),
    titleText: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1E1B4B),
    textSecondary: Color(0xFF64748B),
    isDarkHeader: true,
    darkBackground: false,
  ),
  AppPalette(
    id: 'teal_light',
    name: 'Turquesa claro',
    primary: Color(0xFFCCFBF1),
    secondary: Color(0xFF0F766E),
    accent: Color(0xFF14B8A6),
    background: Color(0xFFF0FDFA),
    surface: Color(0xFFFFFFFF),
    titleBackground: Color(0xFFCCFBF1),
    titleText: Color(0xFF134E4A),
    textPrimary: Color(0xFF042F2E),
    textSecondary: Color(0xFF64748B),
    isDarkHeader: false,
    darkBackground: false,
  ),
  AppPalette(
    id: 'purple_light',
    name: 'Lila moderno',
    primary: Color(0xFFF3E8FF),
    secondary: Color(0xFF9333EA),
    accent: Color(0xFFC084FC),
    background: Color(0xFFFAF5FF),
    surface: Color(0xFFFFFFFF),
    titleBackground: Color(0xFFF3E8FF),
    titleText: Color(0xFF581C87),
    textPrimary: Color(0xFF2E1065),
    textSecondary: Color(0xFF6B7280),
    isDarkHeader: false,
    darkBackground: false,
  ),
  AppPalette(
    id: 'sunset_light',
    name: 'Atardecer claro',
    primary: Color(0xFFFFEDD5),
    secondary: Color(0xFFF97316),
    accent: Color(0xFFEC4899),
    background: Color(0xFFFFF7ED),
    surface: Color(0xFFFFFFFF),
    titleBackground: Color(0xFFFFEDD5),
    titleText: Color(0xFF7C2D12),
    textPrimary: Color(0xFF431407),
    textSecondary: Color(0xFF78716C),
    isDarkHeader: false,
    darkBackground: false,
  ),
  AppPalette(
    id: 'matrix_dark',
    name: 'Matrix dark',
    primary: Color(0xFF052E16),
    secondary: Color(0xFF22C55E),
    accent: Color(0xFFA3E635),
    background: Color(0xFF020F08),
    surface: Color(0xFF052E16),
    titleBackground: Color(0xFF052E16),
    titleText: Color(0xFFDCFCE7),
    textPrimary: Color(0xFFF0FDF4),
    textSecondary: Color(0xFFBBF7D0),
    isDarkHeader: true,
    darkBackground: true,
  ),
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
