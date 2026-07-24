import 'dart:async';

/// Implementación vacía para plataformas donde no existe dart:io, como Web.
class DesktopBackendLauncher {
  static Future<void> startIfNeeded() async {}

  static Future<void> stop() async {}
}
