import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/bootstrap/bootstrap.dart';
import 'app/app.dart';

/// Punto de entrada principal de BarLytics.
Future<void> main() async {
  await bootstrap();

  // Las imágenes de productos llegan como URLs versionadas. Flutter reutiliza
  // el mismo NetworkImage dentro de la sesión y evita volver a descargarlo al
  // cambiar entre Mesas, Productos, Resumen e Historial.
  PaintingBinding.instance.imageCache
    ..maximumSize = 300
    ..maximumSizeBytes = 64 * 1024 * 1024;

  runApp(const ProviderScope(child: BarLyticsApp()));
}
