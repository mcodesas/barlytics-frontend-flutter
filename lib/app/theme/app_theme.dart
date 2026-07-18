import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_palette.dart';

/// Tema global de BarLytics.
///
/// Se construye desde la paleta activa para que formularios, tablas, diálogos,
/// botones, menús y páginas CRUD cambien de apariencia en toda la aplicación.
class AppTheme {
  static ThemeData get light => buildFromPalette(
        appPalettes.first.copyWith(
          id: 'bar_tech_light_fallback',
          background: const Color(0xFFF4FBFA),
          surface: Colors.white,
          titleBackground: const Color(0xFF0B3342),
          titleText: Colors.white,
          textPrimary: const Color(0xFF0F2630),
          textSecondary: const Color(0xFF58707A),
          darkBackground: false,
        ),
      );

  static ThemeData get dark => buildFromPalette(appPalettes.first);

  static ThemeData buildFromPalette(AppPalette palette) {
    final isDark = palette.darkBackground;
    final brightness = isDark ? Brightness.dark : Brightness.light;
    final onAction = palette.onAction;
    final outline = palette.cardBorder.withOpacity(isDark ? 0.95 : 0.82);
    final softSurface = Color.lerp(palette.surface, palette.secondary, isDark ? 0.09 : 0.04) ?? palette.surface;

    final scheme = ColorScheme.fromSeed(
      seedColor: palette.primary,
      brightness: brightness,
    ).copyWith(
      primary: palette.primary,
      onPrimary: onAction,
      primaryContainer: palette.primary.withOpacity(isDark ? 0.18 : 0.12),
      onPrimaryContainer: palette.textPrimary,
      secondary: palette.secondary,
      onSecondary: _bestTextColor(palette.secondary),
      secondaryContainer: palette.secondary.withOpacity(isDark ? 0.17 : 0.11),
      onSecondaryContainer: palette.textPrimary,
      tertiary: palette.accent,
      onTertiary: _bestTextColor(palette.accent),
      tertiaryContainer: palette.accent.withOpacity(isDark ? 0.16 : 0.12),
      onTertiaryContainer: palette.textPrimary,
      surface: palette.surface,
      onSurface: palette.textPrimary,
      surfaceContainerHighest: softSurface,
      onSurfaceVariant: palette.textSecondary,
      outline: outline,
      outlineVariant: outline.withOpacity(0.58),
      error: AppColors.danger,
      onError: Colors.white,
    );

    final baseText = ThemeData(brightness: brightness, useMaterial3: true).textTheme;
    final textTheme = baseText.apply(
      bodyColor: palette.textPrimary,
      displayColor: palette.textPrimary,
      decorationColor: palette.primary,
    ).copyWith(
      headlineLarge: baseText.headlineLarge?.copyWith(color: palette.textPrimary, fontWeight: FontWeight.w900),
      headlineMedium: baseText.headlineMedium?.copyWith(color: palette.textPrimary, fontWeight: FontWeight.w900),
      headlineSmall: baseText.headlineSmall?.copyWith(color: palette.textPrimary, fontWeight: FontWeight.w900),
      titleLarge: baseText.titleLarge?.copyWith(color: palette.textPrimary, fontWeight: FontWeight.w900),
      titleMedium: baseText.titleMedium?.copyWith(color: palette.textPrimary, fontWeight: FontWeight.w800),
      titleSmall: baseText.titleSmall?.copyWith(color: palette.textPrimary, fontWeight: FontWeight.w800),
      bodyLarge: baseText.bodyLarge?.copyWith(color: palette.textPrimary),
      bodyMedium: baseText.bodyMedium?.copyWith(color: palette.textPrimary.withOpacity(0.92)),
      bodySmall: baseText.bodySmall?.copyWith(color: palette.textSecondary),
      labelLarge: baseText.labelLarge?.copyWith(color: palette.textPrimary, fontWeight: FontWeight.w900),
      labelMedium: baseText.labelMedium?.copyWith(color: palette.textSecondary, fontWeight: FontWeight.w800),
      labelSmall: baseText.labelSmall?.copyWith(color: palette.textSecondary, fontWeight: FontWeight.w800),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      cardColor: palette.surface,
      dividerColor: outline.withOpacity(0.58),
      fontFamily: 'Roboto',
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      iconTheme: IconThemeData(color: palette.primary),
      primaryIconTheme: IconThemeData(color: palette.primary),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: palette.textPrimary,
        iconTheme: IconThemeData(color: palette.primary),
        actionsIconTheme: IconThemeData(color: palette.primary),
        titleTextStyle: TextStyle(
          color: palette.textPrimary,
          fontWeight: FontWeight.w900,
          fontSize: 21,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: isDark ? 0 : 1,
        margin: EdgeInsets.zero,
        color: palette.surface.withOpacity(isDark ? 0.88 : 0.98),
        surfaceTintColor: Colors.transparent,
        shadowColor: palette.cardShadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: outline),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface.withOpacity(isDark ? 0.98 : 1),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(color: palette.textPrimary, fontSize: 20, fontWeight: FontWeight.w900),
        contentTextStyle: TextStyle(color: palette.textSecondary, fontSize: 14, height: 1.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: BorderSide(color: outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.075) : palette.surface.withOpacity(0.98),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        labelStyle: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700),
        floatingLabelStyle: TextStyle(color: palette.primary, fontWeight: FontWeight.w900),
        helperStyle: TextStyle(color: palette.textSecondary),
        hintStyle: TextStyle(color: palette.textSecondary.withOpacity(0.72)),
        prefixIconColor: palette.primary,
        suffixIconColor: palette.primary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.3),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          backgroundColor: palette.actionColor,
          foregroundColor: onAction,
          disabledBackgroundColor: palette.textSecondary.withOpacity(0.24),
          disabledForegroundColor: palette.textSecondary.withOpacity(0.62),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: palette.actionColor,
          foregroundColor: onAction,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          side: BorderSide(color: outline),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: palette.primary,
        foregroundColor: _bestTextColor(palette.primary),
        extendedTextStyle: const TextStyle(fontWeight: FontWeight.w900),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surface.withOpacity(isDark ? 0.78 : 0.96),
        selectedColor: palette.primary.withOpacity(isDark ? 0.20 : 0.14),
        labelStyle: TextStyle(fontWeight: FontWeight.w800, color: palette.textPrimary),
        secondaryLabelStyle: TextStyle(fontWeight: FontWeight.w900, color: palette.textPrimary),
        side: BorderSide(color: outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(palette.primary.withOpacity(isDark ? 0.12 : 0.08)),
        headingTextStyle: TextStyle(fontWeight: FontWeight.w900, color: palette.textPrimary),
        dataTextStyle: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w600),
        dividerThickness: 0.6,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: palette.surface.withOpacity(isDark ? 0.96 : 0.99),
        selectedItemColor: palette.primary,
        unselectedItemColor: palette.textSecondary,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w900),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
        elevation: 0,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: palette.surface.withOpacity(isDark ? 0.92 : 0.98),
        selectedIconTheme: IconThemeData(color: palette.primary),
        unselectedIconTheme: IconThemeData(color: palette.textSecondary),
        selectedLabelTextStyle: TextStyle(color: palette.primary, fontWeight: FontWeight.w900),
        unselectedLabelTextStyle: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color.lerp(palette.surface, Colors.black, isDark ? 0.14 : 0.38),
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(color: outline.withOpacity(0.58)),
    );
  }

  static Color _bestTextColor(Color color) =>
      ThemeData.estimateBrightnessForColor(color) == Brightness.dark ? Colors.white : const Color(0xFF061723);
}
