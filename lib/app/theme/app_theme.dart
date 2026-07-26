import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_control_metrics.dart';
import 'app_palette.dart';

/// Tema global de BarLytics.
///
/// Todo se deriva de [AppPalette]: colores, tipografía, densidad, redondeo,
/// superficies y contraste. De esta forma una modificación desde Apariencia
/// se refleja en menús, tableros, formularios, tablas y vistas operativas.
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
    final outline = palette.cardBorder.withOpacity(isDark ? 0.95 : 0.82);
    final softSurface = Color.lerp(
          palette.surface,
          palette.secondary,
          isDark ? 0.09 : 0.04,
        ) ??
        palette.surface;
    final controlRadius = palette.radius(16);
    final cardRadius = palette.radius(24);
    final dialogRadius = palette.radius(28);
    final compact = palette.density == AppDensityPreset.compact;
    final spacious = palette.density == AppDensityPreset.spacious;
    final controlHeight = compact ? 38.0 : (spacious ? 46.0 : 42.0);
    final horizontalPadding = compact ? 11.0 : (spacious ? 17.0 : 14.0);
    final verticalPadding = compact ? 7.0 : (spacious ? 11.0 : 9.0);

    final scheme = ColorScheme.fromSeed(
      seedColor: palette.primary,
      brightness: brightness,
    ).copyWith(
      primary: palette.primary,
      onPrimary: palette.onPrimary,
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

    final baseText = ThemeData(
      brightness: brightness,
      useMaterial3: true,
      fontFamily: palette.fontFamily,
    ).textTheme;

    final scaledText = baseText.apply(
      fontFamily: palette.fontFamily,
      bodyColor: palette.textPrimary,
      displayColor: palette.textPrimary,
      decorationColor: palette.primary,
    );

    final textTheme = scaledText.copyWith(
      displayLarge: scaledText.displayLarge?.copyWith(fontWeight: FontWeight.w900),
      displayMedium: scaledText.displayMedium?.copyWith(fontWeight: FontWeight.w900),
      displaySmall: scaledText.displaySmall?.copyWith(fontWeight: FontWeight.w900),
      headlineLarge: scaledText.headlineLarge?.copyWith(fontWeight: FontWeight.w900),
      headlineMedium: scaledText.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
      headlineSmall: scaledText.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
      titleLarge: scaledText.titleLarge?.copyWith(fontWeight: FontWeight.w900),
      titleMedium: scaledText.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      titleSmall: scaledText.titleSmall?.copyWith(fontWeight: FontWeight.w800),
      bodyLarge: scaledText.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      bodyMedium: scaledText.bodyMedium?.copyWith(
        color: palette.textPrimary.withOpacity(0.94),
        fontWeight: FontWeight.w600,
      ),
      bodySmall: scaledText.bodySmall?.copyWith(
        color: palette.textSecondary,
        fontWeight: FontWeight.w600,
      ),
      labelLarge: scaledText.labelLarge?.copyWith(fontWeight: FontWeight.w900),
      labelMedium: scaledText.labelMedium?.copyWith(
        color: palette.textSecondary,
        fontWeight: FontWeight.w800,
      ),
      labelSmall: scaledText.labelSmall?.copyWith(
        color: palette.textSecondary,
        fontWeight: FontWeight.w800,
      ),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      visualDensity: palette.visualDensity,
      materialTapTargetSize: palette.tapTargetSize,
      fontFamily: palette.fontFamily,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      cardColor: palette.surface,
      dividerColor: outline.withOpacity(0.58),
      splashFactory: InkRipple.splashFactory,
    );

    return base.copyWith(
      iconTheme: IconThemeData(color: palette.secondary),
      primaryIconTheme: IconThemeData(color: palette.secondary),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: palette.textPrimary,
        iconTheme: IconThemeData(color: palette.secondary),
        actionsIconTheme: IconThemeData(color: palette.secondary),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: palette.textPrimary,
          fontWeight: FontWeight.w900,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: palette.surfaceStyle == AppSurfacePreset.flat ? 0 : (isDark ? 0 : 1),
        margin: EdgeInsets.zero,
        color: palette.surface.withOpacity(
          palette.surfaceStyle == AppSurfacePreset.glass
              ? (isDark ? 0.82 : 0.90)
              : (isDark ? 0.94 : 0.99),
        ),
        surfaceTintColor: Colors.transparent,
        shadowColor: palette.cardShadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: outline),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface.withOpacity(isDark ? 0.985 : 1),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.32),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: palette.textPrimary,
          fontWeight: FontWeight.w900,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: palette.textSecondary,
          height: 1.35,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(dialogRadius),
          side: BorderSide.none,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface.withOpacity(isDark ? 0.99 : 1),
        modalBackgroundColor: palette.surface.withOpacity(isDark ? 0.99 : 1),
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: Colors.black.withOpacity(0.54),
        elevation: 0,
        modalElevation: 0,
        shadowColor: Colors.black.withOpacity(0.30),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(dialogRadius)),
          side: BorderSide.none,
        ),
        showDragHandle: true,
        dragHandleColor: palette.secondary.withOpacity(0.52),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        isDense: true,
        constraints: const BoxConstraints(minHeight: AppControlMetrics.filterHeight),
        prefixIconConstraints: const BoxConstraints(
          minWidth: AppControlMetrics.filterIconExtent,
          minHeight: AppControlMetrics.filterIconExtent,
        ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: AppControlMetrics.filterIconExtent,
          minHeight: AppControlMetrics.filterIconExtent,
        ),
        fillColor: palette.surfaceStyle == AppSurfacePreset.glass
            ? palette.glassSurface
            : (isDark ? Colors.white.withOpacity(0.070) : palette.surface.withOpacity(0.99)),
        contentPadding: AppControlMetrics.filterContentPadding,
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: palette.textSecondary,
          fontWeight: FontWeight.w700,
        ),
        floatingLabelStyle: textTheme.bodyMedium?.copyWith(
          color: palette.secondary,
          fontWeight: FontWeight.w900,
        ),
        helperStyle: textTheme.bodySmall?.copyWith(color: palette.textSecondary),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: palette.textSecondary.withOpacity(0.72),
        ),
        prefixIconColor: palette.secondary,
        suffixIconColor: palette.secondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: palette.secondary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.3),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: Size(0, controlHeight),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          backgroundColor: palette.actionColor,
          foregroundColor: palette.onAction,
          disabledBackgroundColor: palette.textSecondary.withOpacity(0.24),
          disabledForegroundColor: palette.textSecondary.withOpacity(0.62),
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding + 2,
            vertical: verticalPadding,
          ),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: Size(0, controlHeight),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          elevation: palette.surfaceStyle == AppSurfacePreset.flat ? 0 : 1,
          backgroundColor: palette.actionColor,
          foregroundColor: palette.onAction,
          shadowColor: palette.cardShadow,
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding + 2,
            vertical: verticalPadding,
          ),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size(0, controlHeight),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          foregroundColor: palette.textPrimary,
          side: BorderSide(color: outline),
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding - 1,
          ),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.secondary,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(palette.radius(12)),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: palette.secondary,
          minimumSize: const Size(38, 38),
          maximumSize: const Size(42, 42),
          padding: const EdgeInsets.all(8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(palette.radius(13)),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: palette.actionColor,
        foregroundColor: palette.onAction,
        extendedTextStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(palette.radius(18)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surface.withOpacity(isDark ? 0.82 : 0.98),
        selectedColor: palette.secondary.withOpacity(isDark ? 0.20 : 0.14),
        labelStyle: textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: palette.textPrimary,
        ),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w900,
          color: palette.textPrimary,
        ),
        side: BorderSide(color: outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(palette.radius(999)),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 9,
          vertical: compact ? 3 : 4,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: palette.secondary,
        textColor: palette.textPrimary,
        titleTextStyle: textTheme.titleSmall?.copyWith(
          color: palette.textPrimary,
          fontWeight: FontWeight.w900,
        ),
        subtitleTextStyle: textTheme.bodySmall?.copyWith(
          color: palette.textSecondary,
          fontWeight: FontWeight.w700,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: compact ? 1 : 4,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(palette.radius(16)),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(
          palette.secondary.withOpacity(isDark ? 0.12 : 0.08),
        ),
        headingTextStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w900,
          color: palette.textPrimary,
        ),
        dataTextStyle: textTheme.bodyMedium?.copyWith(
          color: palette.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        headingRowHeight: compact ? 44 : (spacious ? 58 : 50),
        dataRowMinHeight: compact ? 42 : (spacious ? 58 : 48),
        dataRowMaxHeight: compact ? 56 : (spacious ? 78 : 66),
        horizontalMargin: compact ? 12 : 18,
        columnSpacing: compact ? 18 : 28,
        dividerThickness: 0.6,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: palette.surface.withOpacity(isDark ? 0.97 : 0.995),
        selectedItemColor: palette.secondary,
        unselectedItemColor: palette.textSecondary,
        selectedLabelStyle: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900),
        unselectedLabelStyle: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface.withOpacity(isDark ? 0.97 : 0.995),
        indicatorColor: palette.secondary.withOpacity(isDark ? 0.22 : 0.14),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? palette.secondary
                : palette.textSecondary,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? palette.secondary
                : palette.textSecondary,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w900
                : FontWeight.w700,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: palette.surface.withOpacity(isDark ? 0.94 : 0.99),
        indicatorColor: palette.secondary.withOpacity(isDark ? 0.22 : 0.14),
        selectedIconTheme: IconThemeData(color: palette.secondary),
        unselectedIconTheme: IconThemeData(color: palette.textSecondary),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: palette.secondary,
          fontWeight: FontWeight.w900,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: palette.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        endShape: const RoundedRectangleBorder(side: BorderSide.none),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 10,
        textStyle: textTheme.bodyMedium?.copyWith(color: palette.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(palette.radius(16)),
          side: BorderSide.none,
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(palette.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(10),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(palette.radius(16)),
              side: BorderSide.none,
            ),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color.lerp(
          palette.surface,
          Colors.black,
          isDark ? 0.14 : 0.38,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(palette.radius(16)),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: Color.lerp(palette.surface, Colors.black, isDark ? 0.18 : 0.48),
          borderRadius: BorderRadius.circular(palette.radius(10)),
          border: Border.all(color: outline),
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? palette.onAction
              : palette.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? palette.actionColor
              : palette.textSecondary.withOpacity(0.25);
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? palette.actionColor
              : Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(palette.onAction),
        side: BorderSide(color: outline, width: 1.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(palette.radius(5)),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? palette.secondary
              : palette.textSecondary;
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.secondary,
        linearTrackColor: palette.secondary.withOpacity(0.14),
        circularTrackColor: palette.secondary.withOpacity(0.14),
      ),
      dividerTheme: DividerThemeData(color: outline.withOpacity(0.58)),
    );
  }

  static Color _bestTextColor(Color color) =>
      ThemeData.estimateBrightnessForColor(color) == Brightness.dark
          ? Colors.white
          : const Color(0xFF061723);
}
