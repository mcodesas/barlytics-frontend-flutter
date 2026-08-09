import 'package:flutter/foundation.dart';

/// Ambientes soportados por el frontend.
enum EnvironmentType { local, androidEmulator, dev, prod }

/// Configuración de ambiente y URL base del backend.
///
/// Reglas importantes:
/// - Windows/IntelliJ local: usa http://127.0.0.1:8282.
/// - Flutter Web local/LAN: si abres http://192.168.1.50:8081,
///   automáticamente intenta consumir http://192.168.1.50:8282.
/// - También puedes forzar la URL con API_BASE_URL, o solo host/puerto con
///   API_HOST y API_PORT.
///
/// Ejemplo LAN:
/// flutter run -d web-server ^
///   --web-hostname 0.0.0.0 ^
///   --web-port 8081 ^
///   --dart-define=ENV=local ^
///   --dart-define=API_HOST=192.168.1.50 ^
///   --dart-define=API_PORT=8282
class Environment {
  static const _value = String.fromEnvironment('ENV', defaultValue: 'local');
  static const _apiBaseOverride = String.fromEnvironment('API_BASE_URL');
  static const _apiHostOverride = String.fromEnvironment('API_HOST');
  static const _apiPortOverride = int.fromEnvironment('API_PORT', defaultValue: 8282);

  static EnvironmentType get current => switch (_value) {
        'android' => EnvironmentType.androidEmulator,
        'dev' => EnvironmentType.dev,
        'prod' => EnvironmentType.prod,
        _ => EnvironmentType.local,
      };

  static String get baseUrl {
    final override = _normalizeBaseUrl(_apiBaseOverride);
    if (override != null) return override;

    if (kIsWeb && current == EnvironmentType.local) {
      return _buildWebLocalBaseUrl();
    }

    return switch (current) {
      EnvironmentType.androidEmulator => 'http://10.0.2.2:8282',
      EnvironmentType.dev => 'https://dev-api.barlytics.local',
      EnvironmentType.prod => 'https://api.barlytics.local',
      EnvironmentType.local => 'http://127.0.0.1:8282',
    };
  }

  static String _buildWebLocalBaseUrl() {
    final configuredHost = _apiHostOverride.trim();
    final browserHost = Uri.base.host.trim();

    // Si el navegador se abrió con http://192.168.x.x:3000, Uri.base.host
    // trae esa IP. Si por alguna razón viene vacío, se usa localhost.
    final host = configuredHost.isNotEmpty
        ? configuredHost
        : browserHost.isNotEmpty
            ? browserHost
            : '127.0.0.1';

    final scheme = Uri.base.scheme == 'https' ? 'https' : 'http';
    return '$scheme://$host:$_apiPortOverride';
  }

  static String? _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.trim().isEmpty) {
      return null;
    }

    return trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
  }
}
