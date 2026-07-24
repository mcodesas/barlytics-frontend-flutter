/// Ambientes soportados por el frontend.
enum EnvironmentType { local, androidEmulator, dev, prod }

/// Configuración de ambiente y URL base del backend.
class Environment {
  static const _value = String.fromEnvironment('ENV', defaultValue: 'local');
  static const apiBaseOverride = String.fromEnvironment('API_BASE_URL');

  static EnvironmentType get current => switch (_value) {
        'android' => EnvironmentType.androidEmulator,
        'dev' => EnvironmentType.dev,
        'prod' => EnvironmentType.prod,
        _ => EnvironmentType.local,
      };

  static String get baseUrl {
    if (apiBaseOverride.isNotEmpty) return apiBaseOverride;
    return switch (current) {
      EnvironmentType.androidEmulator => 'http://10.0.2.2:8080',
      EnvironmentType.dev => 'https://dev-api.barlytics.local',
      EnvironmentType.prod => 'https://api.barlytics.local',
      EnvironmentType.local => 'http://localhost:8282',
    };
  }
}
