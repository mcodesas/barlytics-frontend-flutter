import 'package:flutter/material.dart';

import '../../core/desktop/backend_launcher.dart';

/// Inicializa dependencias globales antes de levantar la aplicación.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DesktopBackendLauncher.startIfNeeded();
}
