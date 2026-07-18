import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import 'theme/app_palette.dart';
import 'theme/app_theme.dart';

/// Widget raíz de la aplicación.
class BarLyticsApp extends ConsumerWidget {
  const BarLyticsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final palette = ref.watch(selectedAppPaletteProvider);
    final theme = AppTheme.buildFromPalette(palette);

    return MaterialApp.router(
      title: 'BarLytics',
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: theme,
      themeMode: palette.darkBackground ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
