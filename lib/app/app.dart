import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import '../features/intelligence/presentation/intelligence_chat.dart';
import 'theme/app_palette.dart';
import 'theme/app_theme.dart';
import '../core/update/app_update_gate.dart';
import '../core/widgets/barlytics_brand.dart';
import '../features/auth/presentation/providers/auth_provider.dart';

/// Widget raíz de la aplicación.
class BarLyticsApp extends ConsumerWidget {
  const BarLyticsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final palette = ref.watch(selectedAppPaletteProvider);
    final authState = ref.watch(authControllerProvider);
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
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final content = authState.restoringSession
            ? _SessionRestoringView(
                darkBackground: palette.darkBackground,
              )
            : AppUpdateGate(
                child: IntelligenceWindowHost(child: child ?? const SizedBox.shrink()),
              );

        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(palette.fontScale),
          ),
          child: content,
        );
      },
    );
  }
}


class _SessionRestoringView extends StatelessWidget {
  const _SessionRestoringView({
    required this.darkBackground,
  });

  final bool darkBackground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = theme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: background,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              background,
              theme.colorScheme.surface,
              background,
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BarLyticsBrandLockup(
                  width: 260,
                  height: 74,
                  darkBackground: darkBackground,
                  alignment: Alignment.center,
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Iniciando BarLytics...',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface.withOpacity(.72),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
