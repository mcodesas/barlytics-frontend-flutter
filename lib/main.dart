import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/bootstrap/bootstrap.dart';
import 'app/app.dart';
import 'core/telemetry/error_telemetry.dart';

/// Punto de entrada principal de BarLytics.
Future<void> main() async {
  await (runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    final previousHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      try {
        if (previousHandler != null) {
          previousHandler(details);
        } else {
          FlutterError.presentError(details);
        }
      } catch (_) {
        // La visualización de un error no debe bloquear su registro.
      }
      try {
        ErrorTelemetry.instance.frameworkError(details);
      } catch (_) {}
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      try {
        ErrorTelemetry.instance.uncaughtError(error, stack,
            module: 'platform');
      } catch (_) {}
      return true;
    };
    await bootstrap();

  // Las imágenes de productos llegan como URLs versionadas. Flutter reutiliza
  // el mismo NetworkImage dentro de la sesión y evita volver a descargarlo al
  // cambiar entre Mesas, Productos, Resumen e Historial.
  PaintingBinding.instance.imageCache
    ..maximumSize = 300
    ..maximumSizeBytes = 64 * 1024 * 1024;

    runApp(const ProviderScope(child: BarLyticsApp()));
  }, (error, stack) {
    try {
      ErrorTelemetry.instance.uncaughtError(error, stack, module: 'zone');
    } catch (_) {}
  }) ?? Future<void>.value());
}
