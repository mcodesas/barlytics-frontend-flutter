import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/desktop/backend_launcher.dart';

const _barLyticsSystemBarColor = Color(0xFF061723);

/// Inicializa dependencias globales antes de levantar la aplicación.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Mantiene la zona de hora, señal, batería y navegación integrada con el
  // fondo oscuro de BarLytics, sin depender del modo claro/oscuro del equipo.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: _barLyticsSystemBarColor,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: _barLyticsSystemBarColor,
      systemNavigationBarDividerColor: _barLyticsSystemBarColor,
      systemNavigationBarIconBrightness: Brightness.light,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  await DesktopBackendLauncher.startIfNeeded();
}
